//
//  CoinPriceManager.swift
//  CapsizedVault
//
//  Created by Dmitrij on 22/05/2026.
//

import Foundation
import Combine
import UIKit
import OSLog
import RealmSwift

class CoinPriceManager: ObservableObject {

    static let shared = CoinPriceManager()
    private static let logger = Logger(subsystem: "io.capsized.vault", category: "CoinPriceManager")

    // [coinId: [fiatCurrency: price]]
    @Published var prices: [String: [String: Double]] = [:]

    private let coins: [CoinId] = CoinId.allCases
    private let fiats: [FiatCurrency] = FiatCurrency.allCases

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadFromRealm()

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.startPolling() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.stopPolling() }
            .store(in: &cancellables)
    }

    func price(for coin: CoinId, in fiat: FiatCurrency) -> Double {
        prices[coin.rawValue]?[fiat.rawValue] ?? 0
    }

    func startPolling() {
        fetchPrices()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchPrices()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchPrices() {
        let coinIds = coins.map(\.rawValue).joined(separator: ",")
        let fiatIds = fiats.map(\.rawValue).joined(separator: ",")

        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(coinIds)&vs_currencies=\(fiatIds)") else {
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            var newPrices: [String: [String: Double]] = [:]

            for coin in self.coins {
                guard let coinData = json[coin.rawValue] as? [String: Any] else { continue }
                var fiatPrices: [String: Double] = [:]
                for fiat in self.fiats {
                    if let value = coinData[fiat.rawValue] as? Double {
                        fiatPrices[fiat.rawValue] = value
                    }
                }
                newPrices[coin.rawValue] = fiatPrices
            }

            DispatchQueue.main.async {
                self.prices = newPrices
                self.saveToRealm(newPrices)
            }
        }.resume()
    }

    private func saveToRealm(_ allPrices: [String: [String: Double]]) {
        guard let realm = RealmManager.shared.getThreadSaveRealm() else { return }

        do {
            try realm.write {
                for (coinId, fiatPrices) in allPrices {
                    let priceData = CoinPriceData()
                    priceData.coinId = coinId
                    priceData.updatedAt = Date()
                    for (fiat, value) in fiatPrices {
                        priceData.prices[fiat] = value
                    }
                    realm.add(priceData, update: .modified)
                }
            }
        } catch {
            Self.logger.error("Failed to save coin prices: \(error)")
        }
    }

    private func loadFromRealm() {
        guard let realm = RealmManager.shared.getThreadSaveRealm() else { return }

        let allPrices = realm.objects(CoinPriceData.self)
        var loaded: [String: [String: Double]] = [:]

        for priceData in allPrices {
            var fiatPrices: [String: Double] = [:]
            for fiat in fiats {
                fiatPrices[fiat.rawValue] = priceData.price(for: fiat)
            }
            loaded[priceData.coinId] = fiatPrices
        }

        prices = loaded
    }

}
