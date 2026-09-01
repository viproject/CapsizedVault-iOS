//
//  CoinPriceData.swift
//  CapsizedVault
//
//  Created by Dmitrij on 22/05/2026.
//

import Foundation
import RealmSwift

enum CoinId: String, CaseIterable {
    case monero = "monero"
}

enum FiatCurrency: String, CaseIterable {
    case usd, eur, gbp
}

class CoinPriceData: Object {

    @Persisted(primaryKey: true) var coinId: String = ""
    @Persisted var prices: Map<String, Double>
    @Persisted var updatedAt: Date = Date()

    func price(for fiat: FiatCurrency) -> Double {
        prices[fiat.rawValue] ?? 0
    }

}
