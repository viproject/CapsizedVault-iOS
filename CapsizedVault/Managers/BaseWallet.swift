//
//  BaseWallet.swift
//  CapsizedVault
//

import Foundation
import Combine

/// The only way views reach coin-specific API — switch on `kind` instead of casting.
///
/// Only `.monero` exists for now; `.zcash(ZECWallet)` is added once `ZECWallet` exists.
enum WalletKind {
    case monero(XMRWallet)
}

/// Flags shared views read instead of checking `wallet.coin == ...`.
struct WalletCapabilities {
    enum AccountCreation {
        /// New accounts are derived from the seed (Monero, and Zcash spending wallets).
        case derive
        /// New accounts can only be added by importing another viewing key (Zcash view-only).
        case importViewingKey
        /// This wallet can't add accounts at all.
        case none
    }

    var supportsSubaddresses: Bool = false
    var hasTransparentPool: Bool = false
    var supportsShielding: Bool = false
    var accountCreation: AccountCreation = .none
    var supportsMemo: Bool = false
    var supportsSendPriority: Bool = false
    var canSend: Bool = true
}

/// Shared base for `XMRWallet` and (once it exists) `ZECWallet`. An `ObservableObject` base
/// class rather than a protocol, so `@ObservedObject`, `WalletManager.activeWallet` and the
/// existing Combine re-broadcast in `WalletManager` keep working unchanged — `any
/// ObservableObject` can't be `@ObservedObject`. `@Observable` isn't an option either: it
/// needs iOS 17, and the app targets 16.6.
///
/// Lightweight until activated: a wallet built from a Realm row holds only cached state.
/// The engine (the Monero `Kit`, or a Zcash synchronizer once that exists) is created in
/// `activate()` and released in `deactivate()`, which `WalletManager.setActiveWallet` calls,
/// so at most one engine is alive at a time.
class BaseWallet: ObservableObject, Identifiable {

    @Published var title: String = ""
    var walletId: String = ""
    let coin: Coin
    @Published private(set) var isWatchOnly: Bool = false
    @Published var pendingSeedBackup: Bool = false
    @Published var walletError: WalletError?
    @Published var activeAccountIndex: UInt32 = 0
    /// `nil` until the wallet has synced at least once.
    @Published var cachedTotalUnlocked: CoinAmount?

    @Published var accounts: [WalletAccountBalance] = []
    @Published var transactions: [WalletTransaction] = []
    @Published var syncStatus: WalletSyncStatus = .idle

    init(coin: Coin) {
        self.coin = coin
    }

    var kind: WalletKind {
        fatalError("\(type(of: self)) must override kind")
    }

    var capabilities: WalletCapabilities {
        fatalError("\(type(of: self)) must override capabilities")
    }

    /// Protected `init(isWatchOnly:)`-style setter for subclasses, since `isWatchOnly` is
    /// `private(set)` to views but each wallet type determines it from its own engine.
    func setWatchOnly(_ value: Bool) {
        isWatchOnly = value
    }

    func activate() {
        assertionFailure("\(type(of: self)) must override activate()")
    }

    func deactivate() {
        assertionFailure("\(type(of: self)) must override deactivate()")
    }

    func restartSync() {
        assertionFailure("\(type(of: self)) must override restartSync()")
    }

    func accountLabel(for index: UInt32) -> String {
        assertionFailure("\(type(of: self)) must override accountLabel(for:)")
        return ""
    }

    func numberOfAccounts() -> Int {
        assertionFailure("\(type(of: self)) must override numberOfAccounts()")
        return 1
    }

    func setActiveAccountIndex(_ accountIndex: Int) {
        assertionFailure("\(type(of: self)) must override setActiveAccountIndex(_:)")
    }

    func addNewAccount(label: String) {
        assertionFailure("\(type(of: self)) must override addNewAccount(label:)")
    }

    func setAccountLabel(accountIndex: UInt32, label: String) {
        assertionFailure("\(type(of: self)) must override setAccountLabel(accountIndex:label:)")
    }

    func estimateFee(to address: String, amount: CoinAmount) async -> Result<CoinAmount, WalletError> {
        assertionFailure("\(type(of: self)) must override estimateFee(to:amount:)")
        return .failure(.unknown("Not implemented"))
    }

    func send(to address: String, amount: CoinAmount, memo: String?) async -> Result<Bool, WalletError> {
        assertionFailure("\(type(of: self)) must override send(to:amount:memo:)")
        return .failure(.unknown("Not implemented"))
    }

    /// Deletes this wallet's on-disk files/keychain entries. Called by
    /// `WalletManager.removeActiveWallet()` instead of reaching into the engine directly.
    func removeFiles() {
        assertionFailure("\(type(of: self)) must override removeFiles()")
    }

    func isValidAddress(_ address: String) -> Bool {
        assertionFailure("\(type(of: self)) must override isValidAddress(_:)")
        return false
    }
}

extension BaseWallet {
    /// `kind`-based extraction for the views that are (and will stay) Monero-specific —
    /// e.g. `SendXMRView`, `ReceiveXMRView`, `NodeSettingsView` — rather than an `as?` cast.
    var moneroWallet: XMRWallet? {
        if case .monero(let wallet) = kind { return wallet }
        return nil
    }
}
