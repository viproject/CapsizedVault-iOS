//
//  ZcashServerSettingsTests.swift
//  CapsizedVaultTests
//

import Testing
import Foundation
import CapsizedMoneroKit
import ZcashLightClientKit
@testable import CapsizedVault

/// Serialized: the `endpoint`-parsing tests below mutate the shared `ZcashSettings`
/// UserDefaults key, and Swift Testing otherwise runs a suite's `@Test` funcs concurrently —
/// without this they race on that key (same reason `ZECWalletTests` pins itself to the main
/// actor for its own shared mutable state).
@Suite(.serialized)
struct ZcashServerSettingsTests {

    // MARK: - NodeStore defaults

    @Test func zcashDefaultsIsNotEmpty() {
        #expect(!NodeStore.defaults(for: .zcash).isEmpty)
    }

    @Test func zcashDefaultsAreAllTLS() {
        for server in NodeStore.defaults(for: .zcash) {
            #expect(server.url.scheme == "https")
        }
    }

    // MARK: - ZcashSettings.endpoint

    @Test func endpointParsesHostAndPortFromSelectedServerURL() {
        let previous = ZcashSettings.selectedServerURLString
        defer { ZcashSettings.selectedServerURLString = previous }

        ZcashSettings.selectedServerURLString = "https://na.zec.rocks:443"
        let endpoint = ZcashSettings.endpoint
        #expect(endpoint.host == "na.zec.rocks")
        #expect(endpoint.port == 443)
    }

    @Test func endpointFallsBackToDefaultServerOnMalformedStoredValue() {
        let previous = ZcashSettings.selectedServerURLString
        defer { ZcashSettings.selectedServerURLString = previous }

        ZcashSettings.selectedServerURLString = "not a url"
        let endpoint = ZcashSettings.endpoint
        #expect(endpoint.host == "zec.rocks")
        #expect(endpoint.port == 443)
    }

    @Test func endpointDefaultsToPort443WhenMissingFromURL() {
        let previous = ZcashSettings.selectedServerURLString
        defer { ZcashSettings.selectedServerURLString = previous }

        ZcashSettings.selectedServerURLString = "https://lightwalletd.example.com"
        let endpoint = ZcashSettings.endpoint
        #expect(endpoint.host == "lightwalletd.example.com")
        #expect(endpoint.port == 443)
    }
}
