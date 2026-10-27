//
//  ZECWalletTests.swift
//  CapsizedVaultTests
//

import Testing
import Foundation
import HdWalletKit
@testable import CapsizedVault

/// Hand-written fake for `ZcashEngine` — see `ZcashEngine.swift` for why a fake
/// `Synchronizer` itself isn't viable (no public inits on its model types).
private final class FakeZcashEngine: ZcashEngine {
    let updates: AsyncStream<ZcashEngineUpdate>
    private let continuation: AsyncStream<ZcashEngineUpdate>.Continuation

    private(set) var prepareCount = 0
    private(set) var prepareViewOnlyCount = 0
    private(set) var lastPendingUFVK: String?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var prepareDelayNanoseconds: UInt64 = 0
    var stopDelayNanoseconds: UInt64 = 0
    var prepareViewOnlyError: Error?
    var balance: WalletAccountBalance?
    var pages: [[WalletTransaction]] = []

    var fakeUnifiedAddress = "u1fakeunifiedaddress"
    var fakeTransparentAddress = "t1faketransparentaddress"
    private(set) var shieldFundsCount = 0
    private(set) var lastShieldSeed: [UInt8]?
    private(set) var lastShieldMemo: String?
    var shieldFundsResult: Result<Bool, Error> = .success(true)

    init() {
        var continuation: AsyncStream<ZcashEngineUpdate>.Continuation!
        self.updates = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func prepare(seed: [UInt8], birthday: Int?) async throws {
        if prepareDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: prepareDelayNanoseconds)
        }
        prepareCount += 1
    }

    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws {
        prepareViewOnlyCount += 1
        lastPendingUFVK = pendingUFVK
        if let prepareViewOnlyError {
            throw prepareViewOnlyError
        }
    }

    func start() async throws {
        startCount += 1
    }

    func stop() async {
        if stopDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: stopDelayNanoseconds)
        }
        stopCount += 1
    }

    func accountBalance() async throws -> WalletAccountBalance? {
        balance
    }

    func transactions(page: Int) async throws -> [WalletTransaction] {
        pages.indices.contains(page) ? pages[page] : []
    }

    func unifiedAddress() async throws -> String {
        fakeUnifiedAddress
    }

    func transparentAddress() async throws -> String {
        fakeTransparentAddress
    }

    func shieldFunds(seed: [UInt8], memo: String?) async throws -> Bool {
        shieldFundsCount += 1
        lastShieldSeed = seed
        lastShieldMemo = memo
        switch shieldFundsResult {
        case .success(let shielded):
            return shielded
        case .failure(let error):
            throw error
        }
    }

    func sendStatus(_ status: WalletSyncStatus) {
        continuation.yield(.status(status))
    }

    func sendTransactionsChanged() {
        continuation.yield(.transactionsChanged)
    }
}

private struct TestTimeoutError: Error {}

private func waitUntil(timeout: TimeInterval = 2, _ condition: @MainActor () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while await !condition() {
        if Date() > deadline { throw TestTimeoutError() }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
struct ZECWalletTests {

    private func testMnemonic() throws -> [String] {
        try Mnemonic.generate(wordCount: .twentyFour)
    }

    // MARK: - Teardown ordering

    @Test func deactivateWaitsForEngineStopBeforeNextActivatePrepares() async throws {
        let engine1 = FakeZcashEngine()
        engine1.stopDelayNanoseconds = 150_000_000 // 150ms
        let engine2 = FakeZcashEngine()
        var handedOut = 0

        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in
            handedOut += 1
            return handedOut == 1 ? engine1 : engine2
        })

        wallet.activate()
        try await waitUntil { engine1.startCount == 1 }

        wallet.deactivate()
        wallet.activate()

        try await waitUntil { engine2.prepareCount == 1 }

        // engine2 only prepares once engine1's stop() — which takes 150ms — has returned.
        #expect(engine1.stopCount == 1)
    }

    @Test func deactivateDuringInFlightPrepareStopsEngineAndSkipsStart() async throws {
        let engine = FakeZcashEngine()
        engine.prepareDelayNanoseconds = 150_000_000 // 150ms — long enough to deactivate() mid-prepare.

        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })

        wallet.activate()
        // Give the activation Task a chance to start and enter the (still in-flight) `prepare()` call.
        try await Task.sleep(nanoseconds: 20_000_000)
        wallet.deactivate()

        try await waitUntil { engine.stopCount == 1 }
        // A small additional wait past prepare()'s 150ms delay to make sure a delayed
        // `start()` isn't still coming once prepare() finally resolves.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(engine.startCount == 0)
    }

    // MARK: - State mapping

    @Test func engineUpdatesPopulateWalletState() async throws {
        let engine = FakeZcashEngine()
        let balance = WalletAccountBalance(
            index: 0,
            label: "Account 1",
            total: CoinAmount(atomic: 100_000_000, coin: .zcash),
            spendable: CoinAmount(atomic: 90_000_000, coin: .zcash),
            pending: CoinAmount(atomic: 10_000_000, coin: .zcash),
            transparent: CoinAmount(atomic: 0, coin: .zcash)
        )
        engine.balance = balance
        let tx = WalletTransaction(
            hash: "abc123", type: .incoming, amount: CoinAmount(atomic: 100_000_000, coin: .zcash),
            fee: CoinAmount(atomic: 0, coin: .zcash), timestamp: 0, blockHeight: 10,
            isPending: false, isFailed: false, memo: nil, recipient: nil, account: 0
        )
        engine.pages = [[tx]]

        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        engine.sendStatus(.synced(height: 10))
        try await waitUntil { wallet.cachedTotalUnlocked != nil }

        #expect(wallet.syncStatus == .synced(height: 10))
        #expect(wallet.cachedTotalUnlocked == balance.total)
        #expect(wallet.accounts == [balance])
        #expect(wallet.transactions == [tx])

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func syncingProgressUpdatesStatusWithoutRefetchingBalance() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        engine.sendStatus(.syncing(progress: 40, remaining: 100))
        try await waitUntil { wallet.syncStatus == .syncing(progress: 40, remaining: 100) }

        #expect(wallet.cachedTotalUnlocked == nil)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    // MARK: - WalletFactory

    @Test func walletFactoryBranchesOnPersistedCoin() throws {
        let zecRow = WalletsData()
        zecRow.walletId = "zec-1"
        zecRow.coin = Coin.zcash.rawValue

        let xmrRow = WalletsData()
        xmrRow.walletId = "xmr-1"
        xmrRow.coin = Coin.monero.rawValue

        #expect(WalletFactory.make(from: zecRow) is ZECWallet)
        #expect(WalletFactory.make(from: xmrRow) is XMRWallet)
    }

    @Test func zcashRestoreNilBirthdayFallsBackToSaplingActivation() throws {
        let wallet = WalletFactory.make(from: .zcashRestore(mnemonic: try testMnemonic(), birthday: nil), title: "Test") as? ZECWallet
        #expect(wallet?.birthdayHeight == 419_200)
    }

    @Test func zcashViewOnlyNilBirthdayFallsBackToSaplingActivation() throws {
        let wallet = WalletFactory.make(from: .zcashViewOnly(ufvk: "uview1test", birthday: nil), title: "Test") as? ZECWallet
        #expect(wallet?.birthdayHeight == 419_200)
        if let walletId = wallet?.walletId {
            KeychainHelper.deletePendingZcashViewingKey(for: walletId)
        }
    }

    // MARK: - View-only wallets

    @Test func viewOnlyWalletCallsPrepareViewOnlyNotPrepare() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1testkey", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })

        #expect(wallet.isWatchOnly == true)
        #expect(wallet.capabilities.canSend == false)
        #expect(wallet.capabilities.accountCreation == .importViewingKey)

        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        #expect(engine.prepareViewOnlyCount == 1)
        #expect(engine.prepareCount == 0)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func viewOnlySuccessfulImportDeletesPendingKeychainItem() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1anotherkey", birthday: nil, title: "Test", newWalletId: walletId, engineFactory: { _ in engine })

        #expect(KeychainHelper.pendingZcashViewingKey(for: walletId) == "uview1anotherkey")

        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        #expect(engine.lastPendingUFVK == "uview1anotherkey")
        #expect(KeychainHelper.pendingZcashViewingKey(for: walletId) == nil)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func viewOnlyFailedImportKeepsPendingKeychainItemAndSetsError() async throws {
        let engine = FakeZcashEngine()
        engine.prepareViewOnlyError = ZcashEngineError.viewingKeyMissing
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1failingkey", birthday: nil, title: "Test", newWalletId: walletId, engineFactory: { _ in engine })

        wallet.activate()
        try await waitUntil { wallet.walletError != nil }

        #expect(KeychainHelper.pendingZcashViewingKey(for: walletId) == "uview1failingkey")
        #expect(engine.startCount == 0)

        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    // MARK: - Receive addresses

    @Test func activateLoadsUnifiedAndTransparentAddresses() async throws {
        let engine = FakeZcashEngine()
        engine.fakeUnifiedAddress = "u1testaddress"
        engine.fakeTransparentAddress = "t1testaddress"

        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()

        try await waitUntil { wallet.unifiedAddress != nil }
        #expect(wallet.unifiedAddress == "u1testaddress")
        #expect(wallet.transparentAddress == "t1testaddress")

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    // MARK: - Shield funds

    @Test func shieldFundsPassesSeedAndReportsSuccess() async throws {
        let engine = FakeZcashEngine()
        engine.shieldFundsResult = .success(true)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.shieldFunds()

        #expect(engine.shieldFundsCount == 1)
        #expect(engine.lastShieldSeed?.isEmpty == false)
        if case .success(let shielded) = result {
            #expect(shielded == true)
        } else {
            Issue.record("Expected success")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func shieldFundsReturnsFalseWhenNothingToShield() async throws {
        let engine = FakeZcashEngine()
        engine.shieldFundsResult = .success(false)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.shieldFunds()

        if case .success(let shielded) = result {
            #expect(shielded == false)
        } else {
            Issue.record("Expected success")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func shieldFundsPropagatesEngineErrorAsWalletError() async throws {
        let engine = FakeZcashEngine()
        engine.shieldFundsResult = .failure(ZcashEngineError.noAccount)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.shieldFunds()

        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func shieldFundsOnViewOnlyWalletFailsWithoutCallingEngine() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1shieldtest", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.shieldFunds()

        #expect(engine.shieldFundsCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }
}
