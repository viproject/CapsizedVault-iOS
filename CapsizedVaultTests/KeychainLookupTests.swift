//
//  KeychainLookupTests.swift
//  CapsizedVaultTests
//

import Testing
import Foundation
@testable import CapsizedVault

/// `walletPasswordLookup(for:)` is what `XMRWallet.resolveWalletPassword()` switched to so a
/// locked-device Keychain read (`.unavailable`) can no longer be mistaken for "no password was
/// ever saved" (`.notFound`) — see the phase-10 background-sync plan. The `.unavailable` case
/// itself isn't exercised here: there's no way to simulate a locked Keychain read from a unit
/// test, only `.found`/`.notFound`, which are.
struct KeychainLookupTests {

    @Test func walletPasswordLookupIsNotFoundForAnUnknownWalletId() {
        let walletId = "keychain-lookup-test-\(UUID().uuidString)"
        switch KeychainHelper.walletPasswordLookup(for: walletId) {
        case .notFound:
            break
        case .found, .unavailable:
            Issue.record("Expected .notFound for a wallet id that was never saved")
        }
    }

    @Test func walletPasswordLookupIsFoundAfterSaving() {
        let walletId = "keychain-lookup-test-\(UUID().uuidString)"
        defer { KeychainHelper.deleteWalletPassword(for: walletId) }

        KeychainHelper.saveWalletPassword("test-password", for: walletId)

        switch KeychainHelper.walletPasswordLookup(for: walletId) {
        case .found(let password):
            #expect(password == "test-password")
        case .notFound, .unavailable:
            Issue.record("Expected .found after saveWalletPassword")
        }
    }
}
