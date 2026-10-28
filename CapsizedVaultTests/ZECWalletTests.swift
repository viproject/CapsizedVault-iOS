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

    static let primaryAccountID = ZcashAccountID(raw: Data([0]))

    /// Populated by `prepare`/`prepareViewOnly` the same way the real SDK only knows its
    /// accounts once prepared — tests that never touch multi-account APIs don't need to set
    /// this themselves.
    var fakeAccounts: [ZcashEngineAccount] = []
    private(set) var listAccountsCount = 0

    var balancesByAccount: [ZcashAccountID: ZcashEngineBalance] = [:]
    /// Convenience for single-account tests.
    var balance: ZcashEngineBalance? {
        get { balancesByAccount[FakeZcashEngine.primaryAccountID] }
        set { balancesByAccount[FakeZcashEngine.primaryAccountID] = newValue }
    }

    var pagesByAccount: [[(ZcashAccountID, WalletTransaction)]] = []
    /// Convenience for single-account tests: every page is tagged with the primary account.
    var pages: [[WalletTransaction]] {
        get { pagesByAccount.map { $0.map { $0.1 } } }
        set { pagesByAccount = newValue.map { page in page.map { (FakeZcashEngine.primaryAccountID, $0) } } }
    }

    var fakeUnifiedAddress = "u1fakeunifiedaddress"
    var fakeTransparentAddress = "t1faketransparentaddress"
    private(set) var shieldFundsCount = 0
    private(set) var lastShieldSeed: [UInt8]?
    private(set) var lastShieldMemo: String?
    private(set) var lastShieldAccount: ZcashAccountID?
    var shieldFundsResult: Result<Bool, Error> = .success(true)

    var fakeAddressKind: ZcashAddressKind = .shielded
    private(set) var estimateFeeCount = 0
    private(set) var lastEstimateFeeAddress: String?
    private(set) var lastEstimateFeeAccount: ZcashAccountID?
    var estimateFeeResult: Result<Int64, Error> = .success(1_000)
    private(set) var sendCount = 0
    private(set) var lastSendAddress: String?
    private(set) var lastSendAmount: Int64?
    private(set) var lastSendMemo: String?
    private(set) var lastSendSeed: [UInt8]?
    private(set) var lastSendAccount: ZcashAccountID?
    var sendResult: Result<Void, Error> = .success(())
    private(set) var ensureSaplingParamsDownloadedCount = 0
    var ensureSaplingParamsDownloadedError: Error?

    private(set) var deriveAccountCount = 0
    private(set) var lastDeriveSeed: [UInt8]?
    private(set) var lastDeriveHDIndex: UInt32?
    private(set) var lastDeriveBirthday: Int?
    var deriveAccountError: Error?
    private(set) var importViewingKeyCount = 0
    private(set) var lastImportedUFVK: String?
    private(set) var lastImportBirthday: Int?
    var importViewingKeyError: Error?
    private(set) var deleteAccountCount = 0
    private(set) var lastDeletedAccount: ZcashAccountID?
    var deleteAccountError: Error?
    /// Monotonically-increasing id handed out by `deriveAccount`/`importViewingKey`, distinct
    /// from `primaryAccountID`.
    private var nextSyntheticAccountByte: UInt8 = 1

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
        if fakeAccounts.isEmpty {
            fakeAccounts = [ZcashEngineAccount(id: FakeZcashEngine.primaryAccountID, hdIndex: 0, ufvk: nil)]
        }
    }

    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws {
        prepareViewOnlyCount += 1
        lastPendingUFVK = pendingUFVK
        if let prepareViewOnlyError {
            throw prepareViewOnlyError
        }
        if fakeAccounts.isEmpty {
            fakeAccounts = [ZcashEngineAccount(id: FakeZcashEngine.primaryAccountID, hdIndex: nil, ufvk: pendingUFVK)]
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

    func listAccounts() async throws -> [ZcashEngineAccount] {
        listAccountsCount += 1
        return fakeAccounts
    }

    func deriveAccount(seed: [UInt8], hdIndex: UInt32, birthday: Int?) async throws -> ZcashAccountID {
        deriveAccountCount += 1
        lastDeriveSeed = seed
        lastDeriveHDIndex = hdIndex
        lastDeriveBirthday = birthday
        if let deriveAccountError {
            throw deriveAccountError
        }
        let id = ZcashAccountID(raw: Data([nextSyntheticAccountByte]))
        nextSyntheticAccountByte += 1
        fakeAccounts.append(ZcashEngineAccount(id: id, hdIndex: hdIndex, ufvk: nil))
        return id
    }

    func importViewingKey(_ ufvk: String, birthday: Int?) async throws -> ZcashAccountID {
        importViewingKeyCount += 1
        lastImportedUFVK = ufvk
        lastImportBirthday = birthday
        if let importViewingKeyError {
            throw importViewingKeyError
        }
        let id = ZcashAccountID(raw: Data([nextSyntheticAccountByte]))
        nextSyntheticAccountByte += 1
        fakeAccounts.append(ZcashEngineAccount(id: id, hdIndex: nil, ufvk: ufvk))
        return id
    }

    func deleteAccount(_ account: ZcashAccountID) async throws {
        deleteAccountCount += 1
        lastDeletedAccount = account
        if let deleteAccountError {
            throw deleteAccountError
        }
        fakeAccounts.removeAll { $0.id == account }
        balancesByAccount[account] = nil
    }

    func accountBalances() async throws -> [ZcashAccountID: ZcashEngineBalance] {
        balancesByAccount
    }

    func transactions(page: Int) async throws -> [(account: ZcashAccountID, transaction: WalletTransaction)] {
        pagesByAccount.indices.contains(page) ? pagesByAccount[page] : []
    }

    func unifiedAddress(account: ZcashAccountID) async throws -> String {
        fakeUnifiedAddress
    }

    func transparentAddress(account: ZcashAccountID) async throws -> String {
        fakeTransparentAddress
    }

    func shieldFunds(account: ZcashAccountID, seed: [UInt8], memo: String?) async throws -> Bool {
        shieldFundsCount += 1
        lastShieldSeed = seed
        lastShieldMemo = memo
        lastShieldAccount = account
        switch shieldFundsResult {
        case .success(let shielded):
            return shielded
        case .failure(let error):
            throw error
        }
    }

    func classifyAddress(_ address: String) -> ZcashAddressKind {
        fakeAddressKind
    }

    func estimateFee(account: ZcashAccountID, to address: String, amount: Int64, memo: String?) async throws -> Int64 {
        estimateFeeCount += 1
        lastEstimateFeeAddress = address
        lastEstimateFeeAccount = account
        switch estimateFeeResult {
        case .success(let fee): return fee
        case .failure(let error): throw error
        }
    }

    func send(account: ZcashAccountID, to address: String, amount: Int64, memo: String?, seed: [UInt8]) async throws {
        sendCount += 1
        lastSendAddress = address
        lastSendAmount = amount
        lastSendMemo = memo
        lastSendSeed = seed
        lastSendAccount = account
        if case .failure(let error) = sendResult {
            throw error
        }
    }

    func ensureSaplingParamsDownloaded() async throws {
        ensureSaplingParamsDownloadedCount += 1
        if let ensureSaplingParamsDownloadedError {
            throw ensureSaplingParamsDownloadedError
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
        let expectedBalance = WalletAccountBalance(
            index: 0,
            label: "Account 1",
            total: CoinAmount(atomic: 100_000_000, coin: .zcash),
            spendable: CoinAmount(atomic: 90_000_000, coin: .zcash),
            pending: CoinAmount(atomic: 10_000_000, coin: .zcash),
            transparent: CoinAmount(atomic: 0, coin: .zcash)
        )
        engine.balance = ZcashEngineBalance(total: 100_000_000, spendable: 90_000_000, pending: 10_000_000, transparent: 0)
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
        #expect(wallet.cachedTotalUnlocked == expectedBalance.total)
        #expect(wallet.accounts == [expectedBalance])
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

    // MARK: - Address validation

    @Test func isValidAddressReflectsEngineClassification() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        engine.fakeAddressKind = .shielded
        #expect(wallet.isValidAddress("u1whatever") == true)
        #expect(wallet.addressKind("u1whatever") == .shielded)

        engine.fakeAddressKind = .invalid
        #expect(wallet.isValidAddress("garbage") == false)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func isValidAddressFalseBeforeActivation() throws {
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in FakeZcashEngine() })
        #expect(wallet.isValidAddress("u1whatever") == false)
    }

    // MARK: - Send

    @Test func estimateFeeReturnsFeeAsCoinAmount() async throws {
        let engine = FakeZcashEngine()
        engine.estimateFeeResult = .success(2_000)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.estimateFee(to: "u1recipient", amount: CoinAmount(atomic: 50_000_000, coin: .zcash))

        #expect(engine.estimateFeeCount == 1)
        #expect(engine.lastEstimateFeeAddress == "u1recipient")
        if case .success(let fee) = result {
            #expect(fee == CoinAmount(atomic: 2_000, coin: .zcash))
        } else {
            Issue.record("Expected success")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func sendPassesSeedAmountAndMemoThenRefreshesBalance() async throws {
        let engine = FakeZcashEngine()
        let expectedBalance = WalletAccountBalance(
            index: 0, label: "Account 1",
            total: CoinAmount(atomic: 40_000_000, coin: .zcash),
            spendable: CoinAmount(atomic: 40_000_000, coin: .zcash),
            pending: CoinAmount(atomic: 0, coin: .zcash),
            transparent: CoinAmount(atomic: 0, coin: .zcash)
        )
        engine.balance = ZcashEngineBalance(total: 40_000_000, spendable: 40_000_000, pending: 0, transparent: 0)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.send(to: "u1recipient", amount: CoinAmount(atomic: 10_000_000, coin: .zcash), memo: "hi")

        #expect(engine.sendCount == 1)
        #expect(engine.lastSendAddress == "u1recipient")
        #expect(engine.lastSendAmount == 10_000_000)
        #expect(engine.lastSendMemo == "hi")
        #expect(engine.lastSendSeed?.isEmpty == false)
        if case .success(let sent) = result {
            #expect(sent == true)
        } else {
            Issue.record("Expected success")
        }
        #expect(wallet.cachedTotalUnlocked == expectedBalance.total)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func sendPropagatesWalletErrorFromEngineUnchanged() async throws {
        let engine = FakeZcashEngine()
        let expected = WalletError.insufficientFunds(available: CoinAmount(atomic: 1_000, coin: .zcash))
        engine.sendResult = .failure(expected)
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.send(to: "u1recipient", amount: CoinAmount(atomic: 10_000_000, coin: .zcash), memo: nil)

        if case .failure(let error) = result {
            #expect(error == expected)
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func sendOnViewOnlyWalletFailsWithoutCallingEngine() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1sendtest", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.send(to: "u1recipient", amount: CoinAmount(atomic: 10_000_000, coin: .zcash), memo: nil)

        #expect(engine.sendCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func ensureSaplingParamsDownloadedReportsSuccessAndFailure() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let ok = await wallet.ensureSaplingParamsDownloaded()
        #expect(ok == true)
        #expect(engine.ensureSaplingParamsDownloadedCount == 1)

        engine.ensureSaplingParamsDownloadedError = ZcashEngineError.noAccount
        let failed = await wallet.ensureSaplingParamsDownloaded()
        #expect(failed == false)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    // MARK: - Multi-account (phase 8)

    @Test func reconcileCreatesAccountRowForFreshSeedWallet() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        #expect(wallet.numberOfAccounts() == 1)
        #expect(wallet.accountLabel(for: 0) == "Account 1")

        let rows = RealmManager.shared.zcashAccounts(walletId: wallet.walletId)
        #expect(rows.count == 1)
        #expect(rows.first?.accountUUID == FakeZcashEngine.primaryAccountID.raw)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func reconcileAdoptsLegacyRowMissingUUIDWithoutDuplicating() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        // Simulates a wallet created before phase 8: a row already exists with no uuid yet.
        RealmManager.shared.saveZcashAccount(walletId: walletId, accountIndex: 0, label: "Account 1", isImportedViewingKey: true, accountUUID: nil)

        let wallet = ZECWallet(viewingKey: "uview1legacykey", birthday: nil, title: "Legacy", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        #expect(wallet.numberOfAccounts() == 1)
        let rows = RealmManager.shared.zcashAccounts(walletId: walletId)
        #expect(rows.count == 1)
        #expect(rows.first?.accountUUID == FakeZcashEngine.primaryAccountID.raw)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func deriveAccountAddsAccountAndSwitchesToIt() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: 500_000, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.deriveAccount(label: "Savings")

        if case .failure = result {
            Issue.record("Expected success")
        }
        #expect(engine.deriveAccountCount == 1)
        #expect(engine.lastDeriveHDIndex == 1)
        #expect(engine.lastDeriveBirthday == 500_000)
        #expect(wallet.numberOfAccounts() == 2)
        #expect(wallet.activeAccountIndex == 1)
        #expect(wallet.accountLabel(for: 1) == "Savings")

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func deriveAccountFallsBackToCreatedAtWhenNoBirthdayStored() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        _ = await wallet.deriveAccount(label: "Savings")

        // No stored birthday falls back to the wallet's (just-now) creation date, not the
        // Sapling-activation floor — i.e. a recent height, not 419_200.
        #expect(engine.lastDeriveBirthday != nil)
        #expect(engine.lastDeriveBirthday! > 419_200)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func deriveAccountFailsOnViewOnlyWalletWithoutCallingEngine() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1derivetest", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.deriveAccount(label: "Nope")

        #expect(engine.deriveAccountCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func addViewingKeyRejectsDuplicateUFVK() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1existingkey", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.addViewingKey("uview1existingkey", label: "Duplicate")

        #expect(engine.importViewingKeyCount == 0)
        if case .failure(let error) = result {
            #expect(error == .duplicateViewingKey)
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func addViewingKeySucceedsAndIsMarkedAsAddedKey() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1originalkey", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.addViewingKey("uview1differentkey", label: "Second key")

        if case .failure = result {
            Issue.record("Expected success")
        }
        #expect(engine.importViewingKeyCount == 1)
        #expect(engine.lastImportedUFVK == "uview1differentkey")
        #expect(wallet.numberOfAccounts() == 2)
        #expect(wallet.activeAccountIndex == 1)

        let rows = RealmManager.shared.zcashAccounts(walletId: walletId)
        #expect(rows.first(where: { $0.accountIndex == 1 })?.isImportedViewingKey == true)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func addViewingKeyFailsOnSeedWallet() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.addViewingKey("uview1whatever", label: "Nope")

        #expect(engine.importViewingKeyCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func removeViewingKeyRefusesLastAccount() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1onlykey", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.removeViewingKey(accountIndex: 0)

        #expect(engine.deleteAccountCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }
        #expect(wallet.numberOfAccounts() == 1)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func removeViewingKeyRefusesOnSeedWallet() async throws {
        let engine = FakeZcashEngine()
        let wallet = ZECWallet(mnemonic: try testMnemonic(), birthday: nil, title: "Test", engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let result = await wallet.removeViewingKey(accountIndex: 0)

        #expect(engine.deleteAccountCount == 0)
        if case .failure = result {
            // expected
        } else {
            Issue.record("Expected failure")
        }

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
    }

    @Test func removeViewingKeyDeletesAndFallsBackActiveAccount() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1firstkey", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        _ = await wallet.addViewingKey("uview1secondkey", label: "Second")
        #expect(wallet.activeAccountIndex == 1)

        let result = await wallet.removeViewingKey(accountIndex: 1)

        if case .failure = result {
            Issue.record("Expected success")
        }
        #expect(engine.deleteAccountCount == 1)
        #expect(wallet.numberOfAccounts() == 1)
        #expect(wallet.activeAccountIndex == 0)

        let rows = RealmManager.shared.zcashAccounts(walletId: walletId)
        #expect(rows.count == 1)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }

    @Test func multiAccountBalancesSumIntoCachedTotalAndTransactionsStampedWithAccountIndex() async throws {
        let engine = FakeZcashEngine()
        let walletId = UUID().uuidString
        let wallet = ZECWallet(viewingKey: "uview1multiaccount", birthday: nil, title: "Test VO", newWalletId: walletId, engineFactory: { _ in engine })
        wallet.activate()
        try await waitUntil { engine.startCount == 1 }

        let addResult = await wallet.addViewingKey("uview1secondaccount", label: "Second")
        guard case .success = addResult else {
            Issue.record("Expected addViewingKey to succeed")
            return
        }
        let secondAccountID = engine.fakeAccounts.last!.id

        engine.balancesByAccount = [
            FakeZcashEngine.primaryAccountID: ZcashEngineBalance(total: 10_000_000, spendable: 10_000_000, pending: 0, transparent: 0),
            secondAccountID: ZcashEngineBalance(total: 5_000_000, spendable: 5_000_000, pending: 0, transparent: 0)
        ]
        let txPrimary = WalletTransaction(
            hash: "tx-primary", type: .incoming, amount: CoinAmount(atomic: 10_000_000, coin: .zcash),
            fee: CoinAmount(atomic: 0, coin: .zcash), timestamp: 0, blockHeight: 1,
            isPending: false, isFailed: false, memo: nil, recipient: nil, account: 0
        )
        let txSecond = WalletTransaction(
            hash: "tx-second", type: .incoming, amount: CoinAmount(atomic: 5_000_000, coin: .zcash),
            fee: CoinAmount(atomic: 0, coin: .zcash), timestamp: 0, blockHeight: 1,
            isPending: false, isFailed: false, memo: nil, recipient: nil, account: 0
        )
        engine.pagesByAccount = [[(FakeZcashEngine.primaryAccountID, txPrimary), (secondAccountID, txSecond)]]

        engine.sendTransactionsChanged()
        try await waitUntil { wallet.transactions.count == 2 }

        #expect(wallet.accounts.count == 2)
        #expect(wallet.cachedTotalUnlocked == CoinAmount(atomic: 15_000_000, coin: .zcash))
        #expect(wallet.transactions.first(where: { $0.hash == "tx-primary" })?.account == 0)
        #expect(wallet.transactions.first(where: { $0.hash == "tx-second" })?.account == 1)

        wallet.deactivate()
        try await waitUntil { engine.stopCount == 1 }
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
    }
}
