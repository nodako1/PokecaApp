//
//  PokecaAPIModels.swift
//  PokecaApp2
//
//  Created by Koichi Noda on 2025/10/07.
//

import Foundation

struct PokecaEventItem: Decodable {
    let id: Int
    let eventHoldingId: Int
    let eventDateParams: String
    let eventDate: String
    let eventTitle: String
    let prefectureName: String
    let shopName: String?
    let leagueName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventHoldingId = "event_holding_id"
        case eventDateParams = "event_date_params"
        case eventDate = "event_date"
        case eventTitle = "event_title"
        case prefectureName = "prefecture_name"
        case shopName = "shop_name"
        case leagueName
    }
}

struct PokecaEventListResponse: Decodable {
    let event: [PokecaEventItem]
}

struct PokecaDataWrappedResponse: Decodable {
    let data: PokecaEventListResponse
}
