//
//  DetailFetcher+Parsing.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import Foundation
import SwiftSoup
import WebKit

extension DetailFetcher {
    
    // MARK: - 主催者抽出
    
    func extractOrganizer(doc: Document) throws -> String {
        // テーブル形式
        if let th = try doc.select("table th:matchesOwn(主催者)").first(),
           let td = try th.nextElementSibling() {
            return try td.text()
        }
        // dl-dt形式
        if let dt = try doc.select("dl dt:matchesOwn(主催者)").first(),
           let dd = try dt.nextElementSibling() {
            return try dd.text()
        }
        // 単一ラベル形式
        let all = try doc.body()?.text() ?? ""
        if let r = all.range(of: "主催者[:：]\\s*(.+?)\\s(開催日|日時|会場|場所|$)", options: .regularExpression) {
            let s = String(all[r]).replacingOccurrences(of: "^主催者[:：]\\s*", with: "", options: .regularExpression)
            return s
        }
        return ""
    }
    
    func cleanDateNoise(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "\\d{4}年\\s*\\d{1,2}月\\s*\\d{1,2}日", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\d{1,2}/\\d{1,2}", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\d{1,2}:\\d{2}", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func keepShopName(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // 郵便番号以降を削除
        if let r = t.range(of: "〒\\s*\\d{3}-?\\d{4}.*", options: .regularExpression) {
            t = String(t[..<r.lowerBound])
        }
        // 都道府県以降を削除
        let pref = "(北海道|青森県|岩手県|宮城県|秋田県|山形県|福島県|茨城県|栃木県|群馬県|埼玉県|千葉県|東京都|神奈川県|新潟県|富山県|石川県|福井県|山梨県|長野県|岐阜県|静岡県|愛知県|三重県|滋賀県|京都府|大阪府|兵庫県|奈良県|和歌山県|鳥取県|島根県|岡山県|広島県|山口県|徳島県|香川県|愛媛県|高知県|福岡県|佐賀県|長崎県|熊本県|大分県|宮崎県|鹿児島県|沖縄県)"
        if let r = t.range(of: "\\s" + pref, options: .regularExpression) {
            t = String(t[..<r.lowerBound])
        }
        // 改行を削除
        if let first = t.components(separatedBy: .newlines).first {
            t = first
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - デッキ取得（1ページ分）
    
    func parseDecksOnPage(doc: Document, base: URL, remain: Int) throws -> [AwardedDeck] {
        func cleaned(_ s: String) -> String {
            s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
             .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func absoluteURL(_ href: String) -> String? {
            href.hasPrefix("http") ? href : URL(string: href, relativeTo: base)?.absoluteString
        }

        var out: [AwardedDeck] = []

        // テーブル形式（順位列＋デッキ列）
        tableLoop: for table in try doc.select("table").array() {
            let headers = try table.select("th").array().map { try $0.text() }
            guard let iRank = headers.firstIndex(where: { $0.contains("順位") }),
                  let iDeck = headers.firstIndex(where: { $0.contains("デッキ") || $0.contains("レシピ") }) else { continue }

            for tr in try table.select("tbody tr").array() {
                let tds = try tr.select("td")
                if tds.size() == 0 || iRank >= tds.size() || iDeck >= tds.size() { continue }

                let rankText = cleaned((try? tds.get(iRank).text()) ?? "")
                if let a = try? tds.get(iDeck).select("a[href]").first() {
                    let href = try a.attr("href")
                    if let full = absoluteURL(href) {
                        out.append(AwardedDeck(rank: rankText, url: full))
                        if out.count >= remain { break tableLoop }
                    }
                }
            }
        }

        // カード型レイアウト（順位とリンクが分かれている場合）
        if out.isEmpty {
            for row in try doc.select("li, div").array() {
                let text = try cleaned(row.text())
                guard let r = text.range(of: "(\\d+)位", options: .regularExpression) else { continue }
                let rank = String(text[r]).trimmingCharacters(in: .whitespaces)
                if let a = try? row.select("a[href*=/deck],a[href*=/recipe]").first() {
                    let href = try a.attr("href")
                    if let full = absoluteURL(href) {
                        out.append(AwardedDeck(rank: rank, url: full))
                        if out.count >= remain { break }
                    }
                }
            }
        }

        return out
    }
    
    // MARK: - 次ページのURL検出
    
    func nextPageURL(doc: Document, base: URL) throws -> URL? {
        let sels = [
            "a[rel=next]",
            "a:matches(次のページ|次へ|次ページ|次へ進む)",
            ".pagination a.next",
            ".c-pagination__next a",
            ".p-pagination__next a",
            ".bl_pager .next a"
        ]
        for sel in sels {
            if let a = try doc.select(sel).first() {
                let href = try a.attr("href")
                if let u = URL(string: href, relativeTo: base) { return u }
            }
        }
        return nil
    }
    
    // MARK: - 全ページのデッキを取得（最大16件まで）
    
    func parseAllDecks(startURL: URL, max: Int = 16) async throws -> [AwardedDeck] {
        var decks: [AwardedDeck] = []
        var url: URL? = startURL
        var visited = Set<String>()

        while let current = url, decks.count < max {
            let html = try await WebViewHTMLLoader().loadHTML(from: current, timeout: 50)
            let doc = try SwiftSoup.parse(html, current.absoluteString)

            let remain = max - decks.count
            decks.append(contentsOf: try parseDecksOnPage(doc: doc, base: current, remain: remain))

            if decks.count < max, let next = try nextPageURL(doc: doc, base: current) {
                if visited.contains(next.absoluteString) { break }
                visited.insert(next.absoluteString)
                url = next
                continue
            }
            break
        }

        var seen = Set<String>()
        return decks.filter { seen.insert($0.url).inserted }
    }
    
    // MARK: - デバッグ出力
    
    func debugDump(doc: Document, base: URL) {
        let tables = (try? doc.select("table").size()) ?? 0
        let hasOrganizerTh = ((try? doc.select("th:matchesOwn(主催者)").size()) ?? 0) > 0
        let hasOrganizerDt = ((try? doc.select("dt:matchesOwn(主催者)").size()) ?? 0) > 0
        let deckLinks = (try? doc.select("a[href*=/deck],a[href*=/recipe]").size()) ?? 0
        print("tables:\(tables) th主催:\(hasOrganizerTh) dt主催:\(hasOrganizerDt) deckLinks:\(deckLinks)")
    }
}
