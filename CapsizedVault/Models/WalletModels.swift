//
//  WalletModels.swift
//  CapsizedVault
//

import Foundation

/// App-side mirror of `CapsizedMoneroKit.TransactionType` — kept coin-neutral so a future
/// Zcash transaction can map into the same shape.
nonisolated enum WalletTransactionDirection: Equatable, Sendable {
    case incoming
    case outgoing
}

nonisolated struct WalletTransaction: Identifiable, Equatable, Sendable {
    var id: String { hash }

    let hash: String
    let type: WalletTransactionDirection
    let amount: CoinAmount
    let fee: CoinAmount
    let timestamp: Int
    let blockHeight: UInt64
    let isPending: Bool
    let isFailed: Bool
    let memo: String?
    let recipient: String?
    /// Mutable so a coin-neutral consumer can stamp in the app-side account index after the
    /// fact — Zcash's engine layer only knows the SDK's own account id at mapping time (see
    /// `ZECWallet.refreshTransactions()`); Monero sets this once and never changes it.
    var account: Int
    /// True for a Zcash shielding transaction (moving a transparent balance into the shielded
    /// pool) — always `false` for Monero, which has no transparent pool. Lets a transaction
    /// list show "Shielding" instead of "Sent" for these self-transfers.
    var isShielding: Bool = false
}

nonisolated struct WalletAccountBalance: Equatable, Sendable {
    let index: Int
    let label: String
    let total: CoinAmount
    let spendable: CoinAmount
    let pending: CoinAmount
    /// Unshielded balance for this account. `nil` for coins with no transparent pool (Monero).
    let transparent: CoinAmount?
    /// Per-pool balances for the "Balance Across Pools" breakdown. `nil` for coins with no
    /// shielded pools (Monero); `sapling + orchard + ironwood + transparent == total` for Zcash.
    /// `var` (not `let`) so the default value still becomes an overridable parameter in the
    /// synthesized memberwise init.
    var sapling: CoinAmount? = nil
    var orchard: CoinAmount? = nil
    var ironwood: CoinAmount? = nil
}

nonisolated enum WalletSyncStatus: Equatable, Sendable {
    case idle
    case connecting
    case syncing(progress: Int, remaining: Int)
    case synced(height: UInt64)
    case error(WalletError)
}
