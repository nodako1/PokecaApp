//
//  DetailFetcher.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import Foundation
import Combine
import SwiftSoup
import WebKit

// MARK: - Fetcher本体
@MainActor
class DetailFetcher: ObservableObject {
    static var cache: [String: EventDetail] = [:]

    @Published var detail: EventDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetch(detailURL: String) async {
        if let cached = Self.cache[detailURL] {
            self.detail = cached
            return
        }

        do {
            guard let url = URL(string: detailURL) else {
                self.errorMessage = "URLの形式が不正です"
                return
            }

            let html = try await WebViewHTMLLoader().loadHTML(from: url, timeout: 50)
            let parsed = try parseEventDetail(html: html, url: detailURL)

            Self.cache[detailURL] = parsed
            self.detail = parsed

        } catch {
            self.errorMessage = "詳細の取得に失敗しました: \(error)"
        }
    }

    private func parseEventDetail(html: String, url: String) throws -> EventDetail {
        // HTMLから主催者やデッキ情報を抽出する想定（ここは仮）
        return EventDetail(
            organizer: "解析中主催者",
            awardedDecks: []
        )
    }
}
