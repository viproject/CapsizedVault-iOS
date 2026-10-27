//
//  ZECWallet.swift
//  CapsizedVault
//
//  Zcash counterpart to XMRWallet. Wraps one ZcashEngine (normally SDKZcashEngine) at a time,
//  built in activate() and released in deactivate(), per BaseWallet's "lightweight until
//  activated" contract.
//

import Foundation
import HdWalletKit

class ZECWallet: BaseWallet {

    /// In-flight teardown of a previous engine for this walletId, keyed so a fast wallet
    /// switch (e.g. A -> B -> A) can't open a second engine on the same wallet's files before
    /// the first one finishes stopping. ZcashLightClientKit 4.0.0's alias-in-use protection is
    /// dead code (never wired up after a refactor upstream), so this has to be enforced here.
    private static var pendingTeardowns: [String: Task<Void, Never>] = [:]

    /// Set once at creation; `nil` for a brand-new wallet (the SDK then picks a reorg-safe
    /// recent height), a concrete height for a restored one. Ignored by the SDK once an
    /// account already exists, so it stays whatever was first persisted even after that.
    var birthdayHeight: Int?

    private let engineFactory: (String) -> ZcashEngine
    private var engine: ZcashEngine?
    private var activationTask: Task<Void, Never>?
    private var loadedPage: Int = 0

    init(fromRealm realmObj: WalletsData, engineFactory: @escaping (String) -> ZcashEngine = { SDKZcashEngine(walletId: $0) }) {
        self.engineFactory = engineFactory
        super.init(coin: .zcash)
        self.title = realmObj.title
        self.walletId = realmObj.walletId
        self.activeAccountIndex = UInt32(realmObj.lastUsedAccount)
        self.pendingSeedBackup = realmObj.pendingSeedBackup
        let zatoshi = realmObj.cachedTotalUnlockedPiconero
        self.cachedTotalUnlocked = zatoshi >= 0 ? CoinAmount(atomic: zatoshi, coin: .zcash) : nil
        self.birthdayHeight = realmObj.birthdayHeight
        setWatchOnly(RealmManager.shared.isImportedViewingKeyWallet(walletId: realmObj.walletId))
    }

    /// `mnemonic` is saved to the Keychain here and never kept in memory afterwards —
    /// `activate()` always re-reads it, the same way `XMRWallet.resolveWalletPassword()` is
    /// always Keychain-sourced.
    init(mnemonic: [String], birthday: Int?, title: String, pendingSeedBackup: Bool = true, newWalletId: String = UUID().uuidString, engineFactory: @escaping (String) -> ZcashEngine = { SDKZcashEngine(walletId: $0) }) {
        self.engineFactory = engineFactory
        super.init(coin: .zcash)
        self.title = title
        self.walletId = newWalletId
        self.pendingSeedBackup = pendingSeedBackup
        self.birthdayHeight = birthday

        if !KeychainHelper.saveZcashSeed(Data(mnemonic.joined(separator: " ").utf8), for: walletId) {
            walletError = .unknown("Failed to save wallet seed")
        }
    }

    /// View-only wallet built from an imported UFVK. The key is held in the Keychain only
    /// until `activate()` successfully imports it into the SDK, then deleted — see
    /// `prepareViewOnly` below.
    init(viewingKey: String, birthday: Int?, title: String, newWalletId: String = UUID().uuidString, engineFactory: @escaping (String) -> ZcashEngine = { SDKZcashEngine(walletId: $0) }) {
        self.engineFactory = engineFactory
        super.init(coin: .zcash)
        self.title = title
        self.walletId = newWalletId
        self.pendingSeedBackup = false
        self.birthdayHeight = birthday
        setWatchOnly(true)

        if !KeychainHelper.savePendingZcashViewingKey(viewingKey, for: walletId) {
            walletError = .unknown("Failed to save viewing key")
        }
    }

    override var kind: WalletKind { .zcash(self) }

    override var capabilities: WalletCapabilities {
        WalletCapabilities(
            supportsSubaddresses: false,
            hasTransparentPool: true,
            supportsShielding: true,
            accountCreation: isWatchOnly ? .importViewingKey : .derive,
            supportsMemo: true,
            supportsSendPriority: false,
            canSend: false // Send lands in phase 7.
        )
    }

    override func activate() {
        let walletId = self.walletId
        let birthdayHeight = self.birthdayHeight
        let isWatchOnly = self.isWatchOnly

        activationTask = Task { [weak self] in
            await ZECWallet.pendingTeardowns[walletId]?.value
            guard let self, !Task.isCancelled else { return }

            let engine = self.engineFactory(walletId)
            self.engine = engine

            // Checked between every await below: once cancelled, `deactivate()` has already
            // taken `engine` and started stopping it, so this Task must not touch it again
            // (in particular, must not call `start()` on an engine mid-stop).
            do {
                if isWatchOnly {
                    let pendingUFVK = KeychainHelper.pendingZcashViewingKey(for: walletId)
                    try await engine.prepareViewOnly(pendingUFVK: pendingUFVK, birthday: birthdayHeight)
                    if pendingUFVK != nil {
                        KeychainHelper.deletePendingZcashViewingKey(for: walletId)
                    }
                } else {
                    guard let seedData = KeychainHelper.zcashSeed(for: walletId),
                          let seedWords = String(data: seedData, encoding: .utf8)?.components(separatedBy: " "),
                          let seedBytes = Mnemonic.seed(mnemonic: seedWords) else {
                        self.walletError = .walletFilesMissing
                        self.engine = nil
                        return
                    }
                    try await engine.prepare(seed: [UInt8](seedBytes), birthday: birthdayHeight)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.walletError = .unknown("Failed to initialize wallet: \(error.localizedDescription)")
                self.engine = nil
                return
            }
            guard !Task.isCancelled else { return }

            do {
                try await engine.start()
            } catch {
                guard !Task.isCancelled else { return }
                self.walletError = .unknown("Failed to initialize wallet: \(error.localizedDescription)")
                self.engine = nil
                return
            }
            guard !Task.isCancelled else { return }

            for await update in engine.updates {
                if Task.isCancelled { break }
                await self.apply(update)
            }
        }
    }

    override func deactivate() {
        activationTask?.cancel()
        activationTask = nil
        guard let engine else { return }
        self.engine = nil
        stopEngine(engine)
    }

    override func restartSync() {
        walletError = nil
        deactivate()
        activate()
    }

    override func accountLabel(for index: UInt32) -> String {
        "Account 1"
    }

    override func numberOfAccounts() -> Int {
        1
    }

    override func setActiveAccountIndex(_ accountIndex: Int) {
        activeAccountIndex = UInt32(accountIndex)
        _ = RealmManager.shared.setActiveAccount(walletId: walletId, accountIndex: accountIndex)
    }

    override func addNewAccount(label: String) {
        // Phase 8: derive a new ZIP-32 account.
    }

    override func setAccountLabel(accountIndex: UInt32, label: String) {
        // Phase 8.
    }

    override func estimateFee(to address: String, amount: CoinAmount) async -> Result<CoinAmount, WalletError> {
        .failure(.unknown("Sending isn't supported yet"))
    }

    override func send(to address: String, amount: CoinAmount, memo: String?) async -> Result<Bool, WalletError> {
        .failure(.unknown("Sending isn't supported yet"))
    }

    override func isValidAddress(_ address: String) -> Bool {
        false // Phase 7.
    }

    /// Called by `WalletManager.removeActiveWallet()` *before* `deactivate()` — unlike
    /// Monero, the file path here doesn't depend on a live engine, so this stops the engine
    /// itself (instead of waiting for the `deactivate()` call right after it, which finds
    /// `engine` already nil and does nothing) and deletes the wallet's directory once that
    /// stop completes.
    override func removeFiles() {
        let walletId = self.walletId
        KeychainHelper.deleteZcashSeed(for: walletId)
        KeychainHelper.deletePendingZcashViewingKey(for: walletId)

        activationTask?.cancel()
        activationTask = nil
        let engineToStop = engine
        engine = nil

        let previous = ZECWallet.pendingTeardowns[walletId]
        ZECWallet.pendingTeardowns[walletId] = Task {
            await previous?.value
            await engineToStop?.stop()
            try? FileManager.default.removeItem(at: SDKZcashEngine.walletDirectory(for: walletId))
            if ZECWallet.pendingTeardowns[walletId] != nil {
                ZECWallet.pendingTeardowns[walletId] = nil
            }
        }
    }

    func loadNextTransactionPage() {
        loadedPage += 1
        Task { await refreshTransactions() }
    }

    private func stopEngine(_ engine: ZcashEngine) {
        let walletId = self.walletId
        let previous = ZECWallet.pendingTeardowns[walletId]
        ZECWallet.pendingTeardowns[walletId] = Task {
            await previous?.value
            await engine.stop()
        }
    }

    private func apply(_ update: ZcashEngineUpdate) async {
        switch update {
        case .status(let status):
            syncStatus = status
            guard case .synced = status else { return }
        case .transactionsChanged:
            break
        }
        await refreshBalance()
        await refreshTransactions()
    }

    private func refreshBalance() async {
        guard let engine, let balance = try? await engine.accountBalance() else { return }
        accounts = [balance]
        cachedTotalUnlocked = balance.total
        _ = RealmManager.shared.updateCachedBalance(walletId: walletId, totalUnlocked: balance.total.atomic)
    }

    private func refreshTransactions() async {
        guard let engine else { return }
        var all: [WalletTransaction] = []
        for page in 0...loadedPage {
            if let pageTransactions = try? await engine.transactions(page: page) {
                all.append(contentsOf: pageTransactions)
            }
        }
        transactions = all
    }
}
