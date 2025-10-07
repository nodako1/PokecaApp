//
//  DayDetailView.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import SwiftUI

struct DayDetailView: View {
    let dateKey: String
    let dateLabel: String
    let links: [CityLeagueLink]

    var body: some View {
        List {
            // デバッグ: まず links が来ているかを可視化
            Section("Debug") {
                Text("links count: \(links.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let first = links.first {
                    Text("first url: \(first.url)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if links.isEmpty {
                Text("この日付の大会リンクが見つかりませんでした")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(links) { link in
                    EventRow(link: link)
                }
            }
        }
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(links) { link in
                    EventRow(link: link)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("\(dateLabel)入賞デッキ")
    }
}

// 行ビュー（このファイル内で完結）
private struct EventRow: View {
    let link: CityLeagueLink
    @StateObject private var fetcher = DetailFetcher()

    var body: some View {
        Section {
            // 取得状況
            if fetcher.isLoading {
                HStack { ProgressView(); Text("読み込み中") }
            } else if let err = fetcher.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("取得に失敗しました").bold()
                    Text(err).font(.caption).foregroundStyle(.secondary)
                }
            } else if let d = fetcher.detail {
                if !d.organizer.isEmpty {
                    Text("主催者  \(d.organizer)")
                        .font(.headline)
                        .padding(.bottom, 4)
                }
                if d.awardedDecks.isEmpty {
                    Text("入賞デッキは見つかりませんでした")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(d.awardedDecks) { deck in
                        if let url = URL(string: deck.url) {
                            HStack {
                                Text(deck.rank.isEmpty ? "順位不明" : deck.rank)
                                Spacer()
                                Link("デッキレシピ", destination: url)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            } else {
                // 何も表示が無い時の保険（URLだけ見せる）
                Text("fetch pending: \(link.url)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        // .task が動かないケースの保険で onAppear も併用
        .task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await fetcher.fetch(detailURL: link.url)
        }
        .onAppear {
            if fetcher.detail == nil && !fetcher.isLoading {
                Task { await fetcher.fetch(detailURL: link.url) }
            }
        }
    }
}
