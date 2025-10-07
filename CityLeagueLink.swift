//
//  CityLeagueLink.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/05.
//

import Foundation

enum LeagueCategory: String, CaseIterable, Identifiable, Codable {
    case open = "オープンリーグ"
    case senior = "シニアリーグ"
    case junior = "ジュニアリーグ"
    var id: Self { self }
}

struct CityLeagueLink: Identifiable, Codable {
    var id: String { url }        // 計算プロパティ
    let title: String
    let url: String
    let category: LeagueCategory
    let dateKey: String           // 例 20251006
    let dateLabel: String         // 例 10/06
}
