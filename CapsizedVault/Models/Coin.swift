//
//  Coin.swift
//  CapsizedVault
//

import Foundation

/// The coins supported by the app. Every amount, ticker and decimal-place assumption
/// that used to be hardcoded to Monero should route through this type and `CoinAmount`
/// instead of a bare `Int64`/`Double`.
nonisolated enum Coin: String, CaseIterable, Sendable {
    case monero
    case zcash

    var ticker: String {
        switch self {
        case .monero: return "XMR"
        case .zcash: return "ZEC"
        }
    }

    var displayName: String {
        switch self {
        case .monero: return "Monero"
        case .zcash: return "Zcash"
        }
    }

    /// Number of decimal places the coin's atomic unit represents (piconero / zatoshi).
    var decimals: Int {
        switch self {
        case .monero: return 12
        case .zcash: return 8
        }
    }

    var atomicUnitsPerCoin: Int64 {
        switch self {
        case .monero: return 1_000_000_000_000
        case .zcash: return 100_000_000
        }
    }

    var coinId: CoinId {
        switch self {
        case .monero: return .monero
        case .zcash: return .zcash
        }
    }
}

/// An amount of a specific coin, stored as atomic units (piconero for Monero, zatoshi for
/// Zcash) so the two coins' very different decimal precision can never be mixed up by
/// accident the way a bare `Int64`/`Double` could.
nonisolated struct CoinAmount: Equatable, Comparable, Sendable {
    enum FormatStyle {
        /// Up to the coin's full decimal precision — detail fields (fee, tx amount in
        /// details view, etc.). Mirrors the old `xmrFormatted`.
        case full
        /// Capped at 8 decimal places — balance card and transaction list amounts.
        /// Mirrors the old `xmrFormattedBalance`.
        case balance
    }

    let atomic: Int64
    let coin: Coin

    init(atomic: Int64, coin: Coin) {
        self.atomic = atomic
        self.coin = coin
    }

    static func zero(_ coin: Coin) -> CoinAmount {
        CoinAmount(atomic: 0, coin: coin)
    }

    var isZero: Bool { atomic == 0 }

    /// Parses user-entered text (digits and a single decimal separator) into an amount,
    /// rejecting more fractional digits than the coin's atomic unit can represent.
    /// Uses `Decimal`, never `Double`, so input like "0.1" can't pick up binary-float error.
    init?(parsing string: String, coin: Coin) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let decimal = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
              decimal >= 0 else { return nil }

        // Decimal's `exponent` is the power-of-ten scale of its internal representation —
        // e.g. "0.123" has exponent -3. More negative than the coin's decimals means more
        // fractional digits than its atomic unit can hold.
        guard decimal.exponent >= -coin.decimals else { return nil }

        let scaled = decimal * Decimal(coin.atomicUnitsPerCoin)
        guard scaled <= Decimal(Int64.max), scaled >= Decimal(Int64.min) else { return nil }
        let rounded = NSDecimalNumber(decimal: scaled)

        self.atomic = rounded.int64Value
        self.coin = coin
    }

    func formatted(style: FormatStyle = .full) -> String {
        let places = style == .full ? coin.decimals : min(coin.decimals, 8)
        let value = Double(atomic) / Double(coin.atomicUnitsPerCoin)
        return String(format: "%.\(places)f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: ".00", options: .regularExpression)
    }

    /// `price` is the fiat price of one whole coin.
    func fiat(price: Double) -> Double {
        (Double(atomic) / Double(coin.atomicUnitsPerCoin)) * price
    }

    static func + (lhs: CoinAmount, rhs: CoinAmount) -> CoinAmount {
        assert(lhs.coin == rhs.coin, "Adding amounts of different coins")
        return CoinAmount(atomic: lhs.atomic + rhs.atomic, coin: lhs.coin)
    }

    static func - (lhs: CoinAmount, rhs: CoinAmount) -> CoinAmount {
        assert(lhs.coin == rhs.coin, "Subtracting amounts of different coins")
        return CoinAmount(atomic: lhs.atomic - rhs.atomic, coin: lhs.coin)
    }

    static func < (lhs: CoinAmount, rhs: CoinAmount) -> Bool {
        assert(lhs.coin == rhs.coin, "Comparing amounts of different coins")
        return lhs.atomic < rhs.atomic
    }
}
