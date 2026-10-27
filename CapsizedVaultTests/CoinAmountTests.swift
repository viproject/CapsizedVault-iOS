//
//  CoinAmountTests.swift
//  CapsizedVaultTests
//

import Testing
@testable import CapsizedVault

struct CoinAmountTests {

    // MARK: - coinId

    @Test func coinIdMapsToMatchingCoinPriceId() {
        #expect(Coin.monero.coinId == .monero)
        #expect(Coin.zcash.coinId == .zcash)
    }

    // MARK: - formatted

    @Test func formattedFullUsesCoinDecimals() {
        let xmr = CoinAmount(atomic: 1_500_000_000_000, coin: .monero) // 1.5 XMR
        #expect(xmr.formatted(style: .full) == "1.5")

        let zec = CoinAmount(atomic: 150_000_000, coin: .zcash) // 1.5 ZEC
        #expect(zec.formatted(style: .full) == "1.5")
    }

    @Test func formattedBalanceCapsAtEightDecimals() {
        // 12 decimals of precision, but .balance caps display at 8.
        let dust = CoinAmount(atomic: 1, coin: .monero) // 0.000000000001 XMR
        #expect(dust.formatted(style: .balance) == "0.00")
    }

    @Test func formattedTrimsTrailingZeros() {
        let amount = CoinAmount(atomic: 100_000_000, coin: .zcash) // 1.0 ZEC
        #expect(amount.formatted() == "1.00")
    }

    // MARK: - fiat

    @Test func fiatMultipliesByWholeCoinPrice() {
        let amount = CoinAmount(atomic: 50_000_000, coin: .zcash) // 0.5 ZEC
        #expect(amount.fiat(price: 40) == 20)
    }

    // MARK: - parsing

    @Test func parsingAcceptsExactDecimalPlaces() {
        let amount = CoinAmount(parsing: "0.00000001", coin: .zcash) // 8 decimals, exactly zatoshi precision
        #expect(amount?.atomic == 1)
    }

    @Test func parsingRejectsTooManyDecimalPlaces() {
        // Zcash's atomic unit is 8 decimals; a 9th fractional digit can't be represented.
        let amount = CoinAmount(parsing: "0.000000001", coin: .zcash)
        #expect(amount == nil)
    }

    @Test func parsingRejectsNegativeAmounts() {
        #expect(CoinAmount(parsing: "-1", coin: .monero) == nil)
    }

    @Test func parsingRejectsGarbageInput() {
        #expect(CoinAmount(parsing: "not a number", coin: .monero) == nil)
        #expect(CoinAmount(parsing: "", coin: .monero) == nil)
    }

    @Test func parsingRoundTripsThroughFormatted() {
        let original = CoinAmount(parsing: "12.34", coin: .monero)
        #expect(original?.formatted() == "12.34")
    }

    // MARK: - arithmetic

    @Test func additionAndSubtractionStaySameCoin() {
        let a = CoinAmount(atomic: 300, coin: .zcash)
        let b = CoinAmount(atomic: 100, coin: .zcash)
        #expect((a + b).atomic == 400)
        #expect((a - b).atomic == 200)
    }

    @Test func comparisonOrdersByAtomicValue() {
        let small = CoinAmount(atomic: 1, coin: .monero)
        let large = CoinAmount(atomic: 2, coin: .monero)
        #expect(small < large)
    }
}
