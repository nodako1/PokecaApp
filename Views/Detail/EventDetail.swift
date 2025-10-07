//
//  EventDetail.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import Foundation

struct EventDetail: Identifiable {
    var id = UUID()
    let organizer: String
    let awardedDecks: [AwardedDeck]
}

struct AwardedDeck: Identifiable {
    var id = UUID()
    let rank: String
    let url: String
}
