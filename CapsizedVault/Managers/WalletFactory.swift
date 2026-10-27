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
    // Zcash cases land in phase 3, once `ZECWallet` exists:
    // case zcashNew(mnemonic: [String])
    // case zcashSeed(mnemonic: [String], birthday: UInt64?)
    // case zcashUFVK(String, birthday: UInt64?)
}

enum WalletFactory {

    /// Builds a wallet from a saved Realm row. Every row is Monero for now — `WalletsData`
    /// has no `coin` field yet (added alongside Realm schema 9).
    static func make(from realmObj: WalletsData) -> BaseWallet {
        XMRWallet(fromRealm: realmObj)
    }

    static func make(from request: NewWalletRequest, title: String, pendingSeedBackup: Bool = true) -> BaseWallet {
        switch request {
        case .monero(let wallet, let restoreHeight):
            return XMRWallet(fromNewMoneroWallet: wallet, title: title, pendingSeedBackup: pendingSeedBackup, restoreHeight: restoreHeight)
        }
    }
}
