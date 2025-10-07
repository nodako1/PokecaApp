//
//  ResultFetcher.swift
//  PokecaApp2
//
//  Created by Koichi on 2025/10/07.
//

import Foundation
import Combine

@MainActor
final class ResultFetcher: ObservableObject {

    @Published var cityLeagueLinks: [CityLeagueLink] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugSummary = ""

    // MARK: ページURLを安全に生成
    private func pageURL(offset: Int) -> URL {
        var c = URLComponents(string: "https://players.pokemon-card.com/event_search")!
        c.queryItems = [
            .init(name: "offset", value: String(offset)),  // 20件刻み
            .init(name: "order", value: "4"),              // 新しい順
            .init(name: "result_resist", value: "1"),      // 結果公開あり
            .init(name: "event_type[]", value: "3:1"),     // オープン
            .init(name: "event_type[]", value: "3:2"),     // シニア
            .init(name: "event_type[]", value: "3:7")      // ジュニア
        ]
        return c.url!
    }

    // MARK: 直近100件を取得してビュー用リンクに変換
    func fetch(pages: Int = 5) async {
        isLoading = true
        errorMessage = nil
        debugSummary = ""
        cityLeagueLinks = []

        do {
            var allItems: [PokecaEventItem] = []
            var logs: [String] = []

            try await withThrowingTaskGroup(of: (items: [PokecaEventItem], log: String).self) { group in
                for p in 0..<pages {
                    let url = pageURL(offset: p * 20)
                    group.addTask {
                        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                        req.httpMethod = "GET"
                        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
                        req.setValue("https://players.pokemon-card.com/event/result/list", forHTTPHeaderField: "Referer")
                        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

                        let (data, resp) = try await URLSession.shared.data(for: req)
                        let http = resp as? HTTPURLResponse
                        let status = http?.statusCode ?? -1
                        let ct = http?.value(forHTTPHeaderField: "Content-Type") ?? ""
                        let dec = JSONDecoder()

                        if let r1 = try? dec.decode(PokecaEventListResponse.self, from: data) {
                            return (r1.event, "p\(p) list status:\(status) ct:\(ct) count:\(r1.event.count)")
                        }
                        if let r2 = try? dec.decode(PokecaDataWrappedResponse.self, from: data) {
                            return (r2.data.event, "p\(p) wrapped status:\(status) ct:\(ct) count:\(r2.data.event.count)")
                        }
                        if let r3 = try? dec.decode([PokecaEventItem].self, from: data) {
                            return (r3, "p\(p) array status:\(status) ct:\(ct) count:\(r3.count)")
                        }

                        let head = String(data: data.prefix(200), encoding: .utf8) ?? "n/a"
                        return ([], "p\(p) decode fail status:\(status) ct:\(ct) head:\(head)")
                    }
                }

                for try await r in group {
                    allItems.append(contentsOf: r.items)
                    logs.append(r.log)
                }
            }

            // シティリーグのみ抽出してビュー用モデルに変換
            var links = mapToLinks(from: allItems)

            // 重複排除と日付降順
            var seen = Set<String>()
            links = links.filter { seen.insert($0.url).inserted }
            links.sort { $0.dateKey > $1.dateKey }

            cityLeagueLinks = links
            debugSummary = (["pages \(pages) items \(allItems.count) links \(links.count)"] + logs).joined(separator: "\n")
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: リーグ分類
    private func leagueCategory(from name: String?) -> LeagueCategory? {
        let s = name ?? ""
        if s.contains("オープン") { return .open }
        if s.contains("シニア")  { return .senior }
        if s.contains("ジュニア") { return .junior }
        return nil
    }

    // MARK: ビュー用リンクへの変換
    private func mapToLinks(from items: [PokecaEventItem]) -> [CityLeagueLink] {
        let cityOnly = items.filter { item in
            item.eventTitle.contains("シティ") || (item.leagueName ?? "").contains("シティ")
        }

        var out: [CityLeagueLink] = []
        out.reserveCapacity(cityOnly.count)

        for it in cityOnly {
            guard let cat = leagueCategory(from: it.leagueName) else { continue }

            let url = "https://players.pokemon-card.com/event/detail/\(it.eventHoldingId)/result"
            let title = "シティリーグ \(it.prefectureName) \(it.eventDate) \(it.shopName ?? "") \(it.eventTitle)"

            out.append(
                CityLeagueLink(
                    title: title,
                    url: url,
                    category: cat,
                    dateKey: it.eventDateParams,
                    dateLabel: it.eventDate
                )
            )
        }
        return out
    }

    // MARK: 一時モック
    func populateMock() {
        let samples: [CityLeagueLink] = [
            CityLeagueLink(
                title: "シティリーグ 東京都 10/06 ショップA シティリーグ 2026 シーズン1 オープンリーグ",
                url: "https://players.pokemon-card.com/event/detail/795202/result",
                category: .open,
                dateKey: "20251006",
                dateLabel: "10/06"
            ),
            CityLeagueLink(
                title: "シティリーグ 大阪府 10/06 ショップB シティリーグ 2026 シーズン1 ジュニアリーグ",
                url: "https://players.pokemon-card.com/event/detail/795203/result",
                category: .junior,
                dateKey: "20251006",
                dateLabel: "10/06"
            ),
            CityLeagueLink(
                title: "シティリーグ 神奈川県 10/04 ショップC シティリーグ 2026 シーズン1 シニアリーグ",
                url: "https://players.pokemon-card.com/event/detail/795150)/result",
                category: .senior,
                dateKey: "20251004",
                dateLabel: "10/04"
            )
        ]

        cityLeagueLinks = samples
        isLoading = false
        errorMessage = nil
        debugSummary = "mock items \(samples.count)"
    }
}
