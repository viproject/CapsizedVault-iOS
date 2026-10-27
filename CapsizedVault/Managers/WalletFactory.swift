//
//  WalletFactory.swift
//  CapsizedVault
//
//  The one place real engines (the Monero Kit, and later the Zcash synchronizer) are
//  injected into a wallet — tests can swap in fakes here instead.
//

import Foundation
import CapsizedMoneroKit

/// A request to create or restore a wallet, passed to `WalletManager.addWallet(_:title:)`.
enum NewWalletRequest {
    case monero(MoneroWallet, restoreHeight: UInt64?)
    case zcashNew(mnemonic: [String])
    case zcashRestore(mnemonic: [String], birthday: Int?)
    // UFVK (view-only) import lands in phase 5.
}

enum WalletFactory {

    /// Zcash mainnet's Sapling activation height — the fallback restore birthday when the
    /// user doesn't supply one. A new wallet never needs this: it always passes `nil`, which
    /// lets the SDK pick a reorg-safe recent height instead of scanning from here.
    private static let zcashSaplingActivationHeight = 419_200

    /// Builds a wallet from a saved Realm row, branching on its persisted coin.
    static func make(from realmObj: WalletsData) -> BaseWallet {
        switch Coin(rawValue: realmObj.coin) {
        case .zcash:
            return ZECWallet(fromRealm: realmObj)
        case .monero, .none:
            return XMRWallet(fromRealm: realmObj)
        }
    }

    static func make(from request: NewWalletRequest, title: String, pendingSeedBackup: Bool = true) -> BaseWallet {
        switch request {
        case .monero(let wallet, let restoreHeight):
            return XMRWallet(fromNewMoneroWallet: wallet, title: title, pendingSeedBackup: pendingSeedBackup, restoreHeight: restoreHeight)
        case .zcashNew(let mnemonic):
            return ZECWallet(mnemonic: mnemonic, birthday: nil, title: title, pendingSeedBackup: pendingSeedBackup)
        case .zcashRestore(let mnemonic, let birthday):
            return ZECWallet(mnemonic: mnemonic, birthday: birthday ?? zcashSaplingActivationHeight, title: title, pendingSeedBackup: pendingSeedBackup)
        }
    }
}
