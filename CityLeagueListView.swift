//
//  CityLeagueListView.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/05.
//

import SwiftUI

struct CityLeagueListView: View {
    @StateObject private var fetcher = ResultFetcher()
    @State private var selected: LeagueCategory = .open

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 上部のリーグ切替
                Picker("リーグ", selection: $selected) {
                    ForEach(LeagueCategory.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 日付リンク一覧
                List {
                    ForEach(dateGroupsSorted, id: \.key) { key, links in
                        let title = japaneseDateTitle(from: key) + "入賞デッキ"
                        NavigationLink {
                            DayDetailView(
                                dateKey: key,
                                dateLabel: japaneseDateTitle(from: key),
                                links: links
                            )
                        } label: {
                            Text(title)
                        }
                    }

#if DEBUG
                    if !fetcher.debugSummary.isEmpty {
                        Section("Debug") {
                            Text(fetcher.debugSummary)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
#endif
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("シティリーグ一覧")
            .task {
                await fetcher.fetch(pages: 5)   // 実データ取得
            }
        }
    }

    // 選択リーグで絞って日付キーでグループ化 新しい順に並べ替え
    private var dateGroupsSorted: [(key: String, value: [CityLeagueLink])] {
        let filtered = fetcher.cityLeagueLinks.filter { $0.category == selected }
        let grouped = Dictionary(grouping: filtered, by: { $0.dateKey })
        return grouped.sorted { $0.key > $1.key }
    }

    private func japaneseDateTitle(from yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8,
              let y = Int(yyyymmdd.prefix(4)),
              let m = Int(yyyymmdd.dropFirst(4).prefix(2)),
              let d = Int(yyyymmdd.suffix(2)) else { return yyyymmdd }
        return "\(y)年\(m)月\(d)日"
    }
}
