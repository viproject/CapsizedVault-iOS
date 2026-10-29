//
//  ZECWallet.swift
//  CapsizedVault
//
//  Zcash counterpart to XMRWallet. Wraps one ZcashEngine (normally SDKZcashEngine) at a time,
//  built in activate() and released in deactivate(), per BaseWallet's "lightweight until
//  activated" contract.
//

import Foundation
import Combine
import HdWalletKit

/// One account as the UI sees it — `ZECWallet.accountList`'s element. App-side `index` is
/// stable and never reused (removing a viewing key leaves a gap), so views iterate this array
/// rather than `0..<numberOfAccounts()`.
nonisolated struct ZcashAccountInfo: Identifiable, Equatable, Sendable {
    let index: Int
    var label: String
    /// True for a viewing key imported into an already-existing view-only wallet via "Add
    /// viewing key" — never true for index 0, which is always the key the wallet was created
    /// from. Drives the "Added key" badge so a pasted third-party UFVK can't be mistaken for
    /// the wallet's own account.
    let isAddedViewingKey: Bool
    var id: Int { index }
}

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
    /// Used as the scan-from fallback when deriving a new account on a wallet with no
    /// `birthdayHeight` (every wallet created in-app, rather than restored) — see
    /// `deriveAccount(label:)`.
    private let createdAt: Date

    private let engineFactory: (String) -> ZcashEngine
    private var engine: ZcashEngine?
    private var activationTask: Task<Void, Never>?
    private var loadedPage: Int = 0

    @Published private(set) var unifiedAddress: String?
    @Published private(set) var transparentAddress: String?
    @Published private(set) var isShielding: Bool = false
    @Published private(set) var accountList: [ZcashAccountInfo] = []
    private var accountIDs: [Int: ZcashAccountID] = [:]
    private var hdIndices: [Int: UInt32] = [:]
    private var syncPassContinuations: [CheckedContinuation<Bool, Never>] = []

    init(fromRealm realmObj: WalletsData, engineFactory: @escaping (String) -> ZcashEngine = { SDKZcashEngine(walletId: $0) }) {
        self.engineFactory = engineFactory
        self.createdAt = realmObj.createdAt
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
        self.createdAt = Date()
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
        self.createdAt = Date()
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
            supportsShielding: !isWatchOnly, // needs the spending key — no seed for view-only wallets.
            accountCreation: isWatchOnly ? .importViewingKey : .derive,
            supportsMemo: true,
            supportsSendPriority: false,
            canSend: !isWatchOnly
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
                    guard let seedBytes = ZECWallet.resolveSeedBytes(for: walletId) else {
                        self.walletError = .walletFilesMissing
                        self.engine = nil
                        return
                    }
                    try await engine.prepare(seed: seedBytes, birthday: birthdayHeight)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.walletError = .unknown("Failed to initialize wallet: \(error.localizedDescription)")
                self.engine = nil
                return
            }
            guard !Task.isCancelled else { return }

            await self.reconcile(engine: engine)
            // Re-derive from Realm now that reconcile() may have just backfilled a missing
            // account-0 row (e.g. a wallet whose row predates this bookkeeping existing at
            // all) — otherwise a wallet like that keeps showing as a regular seed wallet
            // (Send enabled, "Create new account" instead of "Add viewing key") for this
            // entire session, only self-correcting on the next full relaunch once
            // `init(fromRealm:)` re-reads the now-repaired row.
            self.setWatchOnly(RealmManager.shared.isImportedViewingKeyWallet(walletId: walletId))
            self.ensureActiveAccountIndexIsValid()
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

            await self.loadAddresses(engine: engine)
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
        resumeSyncPassWaiters(with: false)
        guard let engine else { return }
        self.engine = nil
        stopEngine(engine)
    }

    /// Awaits the next sync pass to finish, used by `BackgroundSyncCoordinator` to know when
    /// it's safe to end a background task. A `.synced` status already in place before this is
    /// called doesn't count — only a transition that arrives afterward, via `apply(_:)`, does.
    func waitForSyncPass() async -> Bool {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                syncPassContinuations.append(continuation)
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.resumeSyncPassWaiters(with: false)
            }
        }
    }

    private func resumeSyncPassWaiters(with result: Bool) {
        let continuations = syncPassContinuations
        syncPassContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }

    override func restartSync() {
        walletError = nil
        deactivate()
        activate()
    }

    override func accountLabel(for index: UInt32) -> String {
        accountList.first(where: { $0.index == Int(index) })?.label ?? "Account \(index + 1)"
    }

    override func numberOfAccounts() -> Int {
        accountList.count
    }

    override func setActiveAccountIndex(_ accountIndex: Int) {
        activeAccountIndex = UInt32(accountIndex)
        _ = RealmManager.shared.setActiveAccount(walletId: walletId, accountIndex: accountIndex)
        guard let engine else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.loadAddresses(engine: engine)
        }
    }

    override func addNewAccount(label: String) {
        Task { [weak self] in
            _ = await self?.deriveAccount(label: label)
        }
    }

    override func setAccountLabel(accountIndex: UInt32, label: String) {
        RealmManager.shared.updateZcashAccountLabel(walletId: walletId, accountIndex: Int(accountIndex), label: label)
        if let idx = accountList.firstIndex(where: { $0.index == Int(accountIndex) }) {
            accountList[idx].label = label
        }
    }

    /// Derives and switches to the next ZIP-32 account. Scanned from the wallet's own
    /// birthday — or, when none was ever stored (true for every wallet created in-app rather
    /// than restored), its creation date — rather than the chain tip, so funds this seed's
    /// account already has elsewhere (e.g. another multi-account wallet) aren't missed.
    func deriveAccount(label: String) async -> Result<Void, WalletError> {
        guard !isWatchOnly else { return .failure(.unknown("View-only wallets can't derive new accounts.")) }
        guard let engine else { return .failure(.walletFilesMissing) }
        guard let seedBytes = ZECWallet.resolveSeedBytes(for: walletId) else { return .failure(.walletFilesMissing) }

        let nextHdIndex = hdIndices.values.max().map { $0 + 1 } ?? 0
        let birthday = birthdayHeight ?? ZcashBirthday.height(for: createdAt)

        do {
            let id = try await engine.deriveAccount(seed: seedBytes, hdIndex: nextHdIndex, birthday: birthday)
            let newIndex = (accountList.map(\.index).max() ?? -1) + 1
            RealmManager.shared.saveZcashAccount(walletId: walletId, accountIndex: newIndex, label: label, isImportedViewingKey: false, accountUUID: id.raw)
            await reconcile(engine: engine)
            setActiveAccountIndex(newIndex)
            await refreshBalance()
            return .success(())
        } catch {
            return .failure(ZECWallet.mapSendError(error))
        }
    }

    /// Imports another UFVK into an already view-only wallet ("Add viewing key"). Rejects a
    /// key already in this wallet rather than silently importing a duplicate account.
    /// `birthday` falls back to Sapling activation, same as the initial view-only import.
    func addViewingKey(_ ufvk: String, label: String, birthday: Int? = nil) async -> Result<Void, WalletError> {
        guard isWatchOnly else { return .failure(.unknown("Only view-only wallets can import a viewing key.")) }
        guard let engine else { return .failure(.walletFilesMissing) }

        if let existing = try? await engine.listAccounts(), existing.contains(where: { $0.ufvk == ufvk }) {
            return .failure(.duplicateViewingKey)
        }

        do {
            let id = try await engine.importViewingKey(ufvk, birthday: birthday ?? 419_200)
            let newIndex = (accountList.map(\.index).max() ?? -1) + 1
            RealmManager.shared.saveZcashAccount(walletId: walletId, accountIndex: newIndex, label: label, isImportedViewingKey: true, accountUUID: id.raw)
            await reconcile(engine: engine)
            setActiveAccountIndex(newIndex)
            await refreshBalance()
            return .success(())
        } catch {
            return .failure(ZECWallet.mapSendError(error))
        }
    }

    /// Removes an imported viewing key's account — never the last account in the wallet, and
    /// never on a seed wallet (there's no "remove" for a derived account, same as Monero).
    func removeViewingKey(accountIndex: Int) async -> Result<Void, WalletError> {
        guard isWatchOnly else { return .failure(.unknown("Only view-only wallets can remove a viewing key.")) }
        guard accountList.count > 1 else { return .failure(.unknown("Can't remove the last account in a wallet.")) }
        guard let engine, let id = accountIDs[accountIndex] else { return .failure(.walletFilesMissing) }

        do {
            try await engine.deleteAccount(id)
        } catch {
            return .failure(ZECWallet.mapSendError(error))
        }

        RealmManager.shared.removeZcashAccount(walletId: walletId, accountIndex: accountIndex)
        await reconcile(engine: engine)
        ensureActiveAccountIndexIsValid()
        await refreshBalance()
        return .success(())
    }

    /// Every account's label and UFVK, for the Backup screen's "Viewing keys" list on a
    /// view-only wallet. Never persisted — always re-read from the live engine, same as
    /// `addViewingKey`'s duplicate-check.
    func viewingKeys() async -> [(label: String, ufvk: String, isAddedViewingKey: Bool)] {
        guard let engine, let sdkAccounts = try? await engine.listAccounts() else { return [] }
        var ufvkByID: [ZcashAccountID: String] = [:]
        for account in sdkAccounts {
            if let ufvk = account.ufvk { ufvkByID[account.id] = ufvk }
        }
        return accountList.compactMap { info in
            guard let id = accountIDs[info.index], let ufvk = ufvkByID[id] else { return nil }
            return (label: info.label, ufvk: ufvk, isAddedViewingKey: info.isAddedViewingKey)
        }
    }

    override func estimateFee(to address: String, amount: CoinAmount) async -> Result<CoinAmount, WalletError> {
        guard let engine, let accountID = accountIDs[Int(activeAccountIndex)] else { return .failure(.walletFilesMissing) }
        do {
            let fee = try await engine.estimateFee(account: accountID, to: address, amount: amount.atomic, memo: nil)
            return .success(CoinAmount(atomic: fee, coin: .zcash))
        } catch {
            return .failure(ZECWallet.mapSendError(error))
        }
    }

    override func send(to address: String, amount: CoinAmount, memo: String?) async -> Result<Bool, WalletError> {
        guard !isWatchOnly else { return .failure(.unknown("View-only wallets can't send.")) }
        guard let engine, let accountID = accountIDs[Int(activeAccountIndex)] else { return .failure(.walletFilesMissing) }
        guard let seedBytes = ZECWallet.resolveSeedBytes(for: walletId) else { return .failure(.walletFilesMissing) }

        do {
            try await engine.send(account: accountID, to: address, amount: amount.atomic, memo: memo, seed: seedBytes)
            await refreshBalance()
            return .success(true)
        } catch {
            return .failure(ZECWallet.mapSendError(error))
        }
    }

    override func isValidAddress(_ address: String) -> Bool {
        addressKind(address) != .invalid
    }

    /// Used by `SendZECView` to decide whether to show the memo field — the SDK refuses a
    /// memo for a transparent/TEX recipient (`synchronizerSendMemoToTransparentAddress`).
    func addressKind(_ address: String) -> ZcashAddressKind {
        engine?.classifyAddress(address) ?? .invalid
    }

    /// Proactive head start on the one-time ~50MB Sapling parameter download, so a user who
    /// fills out the Send form slowly doesn't also wait for it at submit time. `send()`
    /// already downloads these automatically if still missing — this is UI-progress-only,
    /// not a correctness requirement. Returns `true` once the files are confirmed present.
    func ensureSaplingParamsDownloaded() async -> Bool {
        guard let engine else { return false }
        do {
            try await engine.ensureSaplingParamsDownloaded()
            return true
        } catch {
            return false
        }
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

    /// Moves the active account's transparent balance into the shielded pool. Only valid when
    /// `capabilities.supportsShielding` is true (never for watch-only wallets — there's no
    /// seed to derive a spending key from). Returns `.success(false)` if there was no
    /// transparent balance to shield.
    func shieldFunds(memo: String? = nil) async -> Result<Bool, WalletError> {
        guard !isWatchOnly else { return .failure(.unknown("View-only wallets can't shield funds.")) }
        guard let engine, let accountID = accountIDs[Int(activeAccountIndex)] else { return .failure(.walletFilesMissing) }
        guard let seedBytes = ZECWallet.resolveSeedBytes(for: walletId) else { return .failure(.walletFilesMissing) }

        isShielding = true
        defer { isShielding = false }
        do {
            let shielded = try await engine.shieldFunds(account: accountID, seed: seedBytes, memo: memo)
            if shielded {
                await refreshBalance()
            }
            return .success(shielded)
        } catch {
            return .failure(.unknown("Failed to shield funds: \(error.localizedDescription)"))
        }
    }

    /// `SDKZcashEngine` already translates SDK-specific errors into `WalletError` before
    /// they leave the engine layer (see `ZcashEngine.swift`'s `mapToWalletError`) — anything
    /// else (e.g. `ZcashEngineError.noAccount`) just falls back to its description.
    private static func mapSendError(_ error: Error) -> WalletError {
        (error as? WalletError) ?? .unknown(error.localizedDescription)
    }

    /// Matches the SDK's live accounts against this wallet's persisted `ZcashAccountData`
    /// rows, rebuilding `accountList`/the id and hd-index lookup tables. Covers every state
    /// this wallet's rows can be in:
    ///  - steady state: every SDK account already has a row with a matching `accountUUID`.
    ///  - a legacy row from before phase 8 (`accountUUID == nil`): adopted by the first
    ///    unmatched SDK account, backfilling its uuid.
    ///  - no row at all (every pre-phase-8 seed wallet, which never wrote one): a new row is
    ///    created.
    ///  - a row whose account the SDK no longer has (e.g. a crash between `deleteAccount` and
    ///    the matching Realm delete in `removeViewingKey`): pruned.
    /// Called after every `prepare`/`prepareViewOnly` in `activate()`, and again after any
    /// account-mutating call, so the UI never has to reconcile anything itself.
    private func reconcile(engine: ZcashEngine) async {
        guard let sdkAccounts = try? await engine.listAccounts() else { return }
        let rows = RealmManager.shared.zcashAccounts(walletId: walletId)
        let indexedRows = Array(rows.enumerated())

        var usedRows: Set<Int> = []
        var infos: [ZcashAccountInfo] = []
        var ids: [Int: ZcashAccountID] = [:]
        var hdIndicesByApp: [Int: UInt32] = [:]

        func adopt(_ account: ZcashEngineAccount, appIndex: Int, label: String) {
            ids[appIndex] = account.id
            if let hdIndex = account.hdIndex { hdIndicesByApp[appIndex] = hdIndex }
            infos.append(ZcashAccountInfo(index: appIndex, label: label, isAddedViewingKey: isWatchOnly && appIndex != 0))
        }

        var unmatched: [ZcashEngineAccount] = []
        for account in sdkAccounts {
            if let match = indexedRows.first(where: { !usedRows.contains($0.offset) && $0.element.accountUUID == account.id.raw }) {
                usedRows.insert(match.offset)
                adopt(account, appIndex: match.element.accountIndex, label: match.element.label)
            } else {
                unmatched.append(account)
            }
        }

        var stillUnmatched: [ZcashEngineAccount] = []
        for account in unmatched {
            if let match = indexedRows.first(where: { !usedRows.contains($0.offset) && $0.element.accountUUID == nil }) {
                usedRows.insert(match.offset)
                RealmManager.shared.setZcashAccountUUID(walletId: walletId, accountIndex: match.element.accountIndex, accountUUID: account.id.raw)
                adopt(account, appIndex: match.element.accountIndex, label: match.element.label)
            } else {
                stillUnmatched.append(account)
            }
        }

        var nextIndex = (rows.map(\.accountIndex).max() ?? -1) + 1
        for account in stillUnmatched {
            let isImportedViewingKey = account.hdIndex == nil
            let label = isImportedViewingKey ? "Imported viewing key" : "Account \(nextIndex + 1)"
            RealmManager.shared.saveZcashAccount(walletId: walletId, accountIndex: nextIndex, label: label, isImportedViewingKey: isImportedViewingKey, accountUUID: account.id.raw)
            adopt(account, appIndex: nextIndex, label: label)
            nextIndex += 1
        }

        for (offset, row) in indexedRows where !usedRows.contains(offset) && row.accountUUID != nil {
            RealmManager.shared.removeZcashAccount(walletId: walletId, accountIndex: row.accountIndex)
        }

        accountList = infos.sorted { $0.index < $1.index }
        accountIDs = ids
        hdIndices = hdIndicesByApp
    }

    /// If the currently-active account index no longer exists (e.g. it was just removed),
    /// falls back to the lowest remaining index — through `setActiveAccountIndex` so the
    /// fallback is persisted and its addresses get loaded, not just corrected in memory.
    private func ensureActiveAccountIndexIsValid() {
        guard !accountIDs.keys.contains(Int(activeAccountIndex)), let fallback = accountList.first?.index else { return }
        setActiveAccountIndex(fallback)
    }

    private func loadAddresses(engine: ZcashEngine) async {
        guard let id = accountIDs[Int(activeAccountIndex)] else { return }
        unifiedAddress = try? await engine.unifiedAddress(account: id)
        transparentAddress = try? await engine.transparentAddress(account: id)
    }

    private static func resolveSeedBytes(for walletId: String) -> [UInt8]? {
        guard let seedData = KeychainHelper.zcashSeed(for: walletId),
              let seedWords = String(data: seedData, encoding: .utf8)?.components(separatedBy: " "),
              let seedBytes = Mnemonic.seed(mnemonic: seedWords) else {
            return nil
        }
        return [UInt8](seedBytes)
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
            switch status {
            case .synced:
                resumeSyncPassWaiters(with: true)
            case .error:
                resumeSyncPassWaiters(with: false)
            default:
                break
            }
            guard case .synced = status else { return }
        case .transactionsChanged:
            break
        }
        await refreshBalance()
        await refreshTransactions()
    }

    private func refreshBalance() async {
        guard let engine, let balances = try? await engine.accountBalances() else { return }
        var total: Int64 = 0
        accounts = accountList.compactMap { info -> WalletAccountBalance? in
            guard let id = accountIDs[info.index], let balance = balances[id] else { return nil }
            total += balance.total
            return WalletAccountBalance(
                index: info.index,
                label: info.label,
                total: CoinAmount(atomic: balance.total, coin: .zcash),
                spendable: CoinAmount(atomic: balance.spendable, coin: .zcash),
                pending: CoinAmount(atomic: balance.pending, coin: .zcash),
                transparent: CoinAmount(atomic: balance.transparent, coin: .zcash)
            )
        }
        cachedTotalUnlocked = CoinAmount(atomic: total, coin: .zcash)
        _ = RealmManager.shared.updateCachedBalance(walletId: walletId, totalUnlocked: total)
    }

    private func refreshTransactions() async {
        guard let engine else { return }
        var all: [WalletTransaction] = []
        for page in 0...loadedPage {
            guard let pageTransactions = try? await engine.transactions(page: page) else { continue }
            for (accountID, transaction) in pageTransactions {
                var stamped = transaction
                if let appIndex = accountIDs.first(where: { $0.value == accountID })?.key {
                    stamped.account = appIndex
                }
                all.append(stamped)
            }
        }
        transactions = all
    }
}
