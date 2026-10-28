//
//  ZcashEngine.swift
//  CapsizedVault
//
//  The seam ZECWallet talks to the Zcash SDK through — an app-owned protocol instead of
//  ZcashLightClientKit's `Synchronizer` directly.
//

import Foundation
import Combine
import ZcashLightClientKit

/// Update pushed from a `ZcashEngine` to its owning `ZECWallet`.
enum ZcashEngineUpdate {
    case status(WalletSyncStatus)
    case transactionsChanged
}

/// What kind of recipient a pasted/scanned address is, without leaking SDK `Recipient`
/// types past this file — `ZECWallet`/views only ever see this enum.
enum ZcashAddressKind {
    case invalid
    case shielded
    /// Transparent or TEX — the SDK refuses a memo for either, so views treat them the same.
    case transparent
}

/// App-side stand-in for the SDK's `AccountUUID` — a random identifier, not key material, so
/// it's safe to persist (`ZcashAccountData.accountUUID`) and compare across launches. Never
/// carries enough information to reconstruct an SDK `AccountUUID` on its own; `SDKZcashEngine`
/// keeps the live object behind this id internally.
nonisolated struct ZcashAccountID: Hashable, Sendable {
    let raw: Data
}

/// One account as reported by `listAccounts()`. `hdIndex` is `nil` for an imported viewing
/// key (no ZIP-32 derivation path); `ufvk` lets callers detect a key that's already imported
/// without ever persisting it.
struct ZcashEngineAccount {
    let id: ZcashAccountID
    let hdIndex: UInt32?
    let ufvk: String?
}

/// Atomic-unit balance for a single account, mirroring the fields `WalletAccountBalance`
/// needs — `ZECWallet` adds the app-side index/label this engine has no concept of.
struct ZcashEngineBalance {
    let total: Int64
    let spendable: Int64
    let pending: Int64
    let transparent: Int64
}

protocol ZcashEngine: AnyObject {
    var updates: AsyncStream<ZcashEngineUpdate> { get }

    /// `birthday` is `nil` for a brand-new wallet (the SDK picks a reorg-safe recent height)
    /// or a restore height for a restored wallet. Ignored by the SDK once an account exists.
    func prepare(seed: [UInt8], birthday: Int?) async throws
    /// For a wallet with no seed. `pendingUFVK` is the viewing key to import on first
    /// activation; subsequent activations pass `nil` since the SDK already has the account(s)
    /// on disk. Throws `ZcashEngineError.viewingKeyMissing` if no account exists yet and
    /// `pendingUFVK` is `nil`.
    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws
    func start() async throws
    /// Returns only once the SDK itself reports it has stopped.
    func stop() async

    /// Every account currently known to the SDK for this wallet. `ZECWallet` calls this right
    /// after `prepare`/`prepareViewOnly` to reconcile against its persisted account rows.
    func listAccounts() async throws -> [ZcashEngineAccount]
    /// Derives and imports ZIP-32 account `hdIndex` from `seed` as a spending account.
    func deriveAccount(seed: [UInt8], hdIndex: UInt32, birthday: Int?) async throws -> ZcashAccountID
    /// Imports `ufvk` as a view-only account — the "Add viewing key" action on an already
    /// view-only wallet. Distinct from `prepareViewOnly`'s first-activation import.
    func importViewingKey(_ ufvk: String, birthday: Int?) async throws -> ZcashAccountID
    /// Deletes an account and its transactions from the wallet database.
    func deleteAccount(_ account: ZcashAccountID) async throws

    func accountBalances() async throws -> [ZcashAccountID: ZcashEngineBalance]
    func transactions(page: Int) async throws -> [(account: ZcashAccountID, transaction: WalletTransaction)]

    func unifiedAddress(account: ZcashAccountID) async throws -> String
    func transparentAddress(account: ZcashAccountID) async throws -> String
    /// Creates and submits a proposal shielding this account's transparent balance into the
    /// shielded pool. `seed` derives the spending key needed to sign — never called for
    /// watch-only wallets (gated by `ZECWallet.capabilities.supportsShielding`). Returns
    /// `false` if there was no transparent balance to shield.
    func shieldFunds(account: ZcashAccountID, seed: [UInt8], memo: String?) async throws -> Bool

    /// Classifies a pasted/scanned address without building a spendable proposal — used for
    /// live address-field validation and for deciding whether to show the memo field (the SDK
    /// refuses a memo for a transparent/TEX recipient).
    func classifyAddress(_ address: String) -> ZcashAddressKind
    /// Builds a transfer proposal and returns its ZIP-317 fee in zatoshi, without creating or
    /// submitting anything. Safe to call repeatedly (e.g. debounced on every keystroke).
    func estimateFee(account: ZcashAccountID, to address: String, amount: Int64, memo: String?) async throws -> Int64
    /// Builds a fresh transfer proposal and creates + submits it. `seed` derives the spending
    /// key, the same way `shieldFunds(account:seed:memo:)` already does.
    func send(account: ZcashAccountID, to address: String, amount: Int64, memo: String?, seed: [UInt8]) async throws
    /// Proactively downloads the ~50MB Sapling parameter files this account needs for any
    /// shielded spend, if they aren't already present. `send`/`shieldFunds` already trigger
    /// this download automatically the first time it's actually needed, so this call is only
    /// a head start for the UI to show progress on — not a correctness requirement.
    func ensureSaplingParamsDownloaded() async throws
}

enum ZcashEngineError: LocalizedError {
    case viewingKeyMissing
    case noAccount
    case transactionSubmissionFailed(String)

    var errorDescription: String? {
        switch self {
        case .viewingKeyMissing:
            return "No viewing key available to import."
        case .noAccount:
            return "No account available yet."
        case .transactionSubmissionFailed(let description):
            return description
        }
    }
}

/// Whether Zcash traffic (tx submit/lookup/server-eval) goes over the SDK's built-in Tor
/// client. Read-only until phase 9 adds the `ZcashServerSettingsView` toggle. Never covers
/// Monero traffic.
enum ZcashSettings {
    private static let torEnabledKey = "zcashTorEnabled"

    static var isTorEnabled: Bool {
        UserDefaults.standard.object(forKey: torEnabledKey) as? Bool ?? true
    }
}

/// Adapts a `SDKSynchronizer` to `ZcashEngine`. One instance per `ZECWallet`; each wallet's
/// files live under their own directory (`walletDirectory(for:)`) and alias
/// (`ZcashSynchronizerAlias.custom(walletId)`), so two wallets' on-disk state can never collide.
final class SDKZcashEngine: ZcashEngine {

    static func walletDirectory(for walletId: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Zcash", isDirectory: true).appendingPathComponent(walletId, isDirectory: true)
    }

    let updates: AsyncStream<ZcashEngineUpdate>

    private let synchronizer: SDKSynchronizer
    private let network: NetworkType
    /// Live SDK objects behind each app-facing `ZcashAccountID` — `AccountUUID.init(id:)` is
    /// internal to the SDK module, so this engine can only ever hand back `AccountUUID`s the
    /// SDK itself produced (via `listAccounts`/`importAccount`/`getAccountsBalances`), never
    /// reconstruct one from `ZcashAccountID.raw` bytes alone.
    private var accounts: [ZcashAccountID: AccountUUID] = [:]
    private var hdIndices: [ZcashAccountID: Zip32AccountIndex] = [:]
    /// Captured from whichever account has ZIP-32 index 0 the last time `listAccounts()` ran
    /// — `importAccount`'s `seedFingerprint` param ties a newly-derived account to the same
    /// seed as account 0 without this engine ever holding the seed itself.
    private var primarySeedFingerprint: [UInt8]?
    private var cancellables: Set<AnyCancellable> = []
    private let updatesContinuation: AsyncStream<ZcashEngineUpdate>.Continuation

    // Kept alongside the `Initializer` (which doesn't expose these publicly) so
    // `ensureSaplingParamsDownloaded()` can reuse the exact same locations/source.
    private let spendParamsURL: URL
    private let outputParamsURL: URL
    private let saplingParamsSourceURL: SaplingParamsSourceURL = .default
    private let paramsLogger = OSLogger(logLevel: .error)

    init(walletId: String) {
        let dir = SDKZcashEngine.walletDirectory(for: walletId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let network = ZcashNetworkBuilder.network(for: .mainnet)
        self.network = network.networkType
        self.spendParamsURL = dir.appendingPathComponent(ZcashSDK.spendParamFilename)
        self.outputParamsURL = dir.appendingPathComponent(ZcashSDK.outputParamFilename)
        // Hard-coded until phase 9's ZcashServerSettingsView. Always TLS — no UI path to
        // disable it, per the security-review decision.
        let endpoint = LightWalletEndpoint(address: "zec.rocks", port: 443, secure: true)
        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: dir.appendingPathComponent(ZcashSDK.defaultFsCacheName, isDirectory: true),
            generalStorageURL: dir.appendingPathComponent("general_storage", isDirectory: true),
            dataDbURL: dir.appendingPathComponent(ZcashSDK.defaultDataDbName),
            torDirURL: dir.appendingPathComponent(ZcashSDK.defaultTorDirName, isDirectory: true),
            endpoint: endpoint,
            network: network,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: saplingParamsSourceURL,
            alias: .custom(walletId),
            // The default logging policy writes unredacted Rust text to os_log at .debug.
            loggingPolicy: .default(.error),
            isTorEnabled: ZcashSettings.isTorEnabled,
            isExchangeRateEnabled: false
        )
        self.synchronizer = SDKSynchronizer(initializer: initializer)

        var continuation: AsyncStream<ZcashEngineUpdate>.Continuation!
        self.updates = AsyncStream { continuation = $0 }
        self.updatesContinuation = continuation

        let synchronizer = self.synchronizer
        synchronizer.stateStream.sink { [weak self] state in
            DispatchQueue.main.async {
                let status = Self.mapStatus(state.syncStatus, latest: state.latestBlockHeight, scanned: state.fullyScannedHeight)
                self?.updatesContinuation.yield(.status(status))
            }
        }.store(in: &cancellables)

        synchronizer.eventStream.sink { [weak self] event in
            switch event {
            case .minedTransaction, .foundTransactions:
                DispatchQueue.main.async {
                    self?.updatesContinuation.yield(.transactionsChanged)
                }
            default:
                break
            }
        }.store(in: &cancellables)
    }

    func prepare(seed: [UInt8], birthday: Int?) async throws {
        _ = try await synchronizer.prepare(with: seed, walletBirthday: birthday, name: "Account 1", keySource: nil)
    }

    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws {
        _ = try await synchronizer.prepare(with: nil, walletBirthday: birthday, name: "Account 1", keySource: nil)
        let existing = try await synchronizer.listAccounts()
        guard existing.isEmpty else {
            for account in existing { remember(account.id) }
            return
        }
        guard let pendingUFVK else {
            throw ZcashEngineError.viewingKeyMissing
        }
        let uuid = try await synchronizer.importAccount(
            ufvk: pendingUFVK,
            seedFingerprint: nil,
            zip32AccountIndex: nil,
            purpose: .viewOnly,
            name: "Account 1",
            keySource: nil,
            birthday: birthday
        )
        remember(uuid)
    }

    func start() async throws {
        try await synchronizer.start(retry: true)
    }

    func listAccounts() async throws -> [ZcashEngineAccount] {
        let sdkAccounts = try await synchronizer.listAccounts()
        return sdkAccounts.map { account in
            let id = remember(account.id)
            if account.hdAccountIndex?.index == 0 {
                primarySeedFingerprint = account.seedFingerprint
            }
            if let hdIndex = account.hdAccountIndex {
                hdIndices[id] = hdIndex
            }
            return ZcashEngineAccount(id: id, hdIndex: account.hdAccountIndex?.index, ufvk: account.ufvk?.stringEncoded)
        }
    }

    func deriveAccount(seed: [UInt8], hdIndex: UInt32, birthday: Int?) async throws -> ZcashAccountID {
        let zip32Index = Zip32AccountIndex(hdIndex)
        let tool = DerivationTool(networkType: network)
        let usk = try tool.deriveUnifiedSpendingKey(seed: seed, accountIndex: zip32Index)
        let ufvk = try tool.deriveUnifiedFullViewingKey(from: usk)
        let uuid = try await synchronizer.importAccount(
            ufvk: ufvk.stringEncoded,
            seedFingerprint: primarySeedFingerprint,
            zip32AccountIndex: zip32Index,
            purpose: .spending,
            name: "Account \(hdIndex + 1)",
            keySource: nil,
            birthday: birthday
        )
        let id = remember(uuid)
        hdIndices[id] = zip32Index
        return id
    }

    func importViewingKey(_ ufvk: String, birthday: Int?) async throws -> ZcashAccountID {
        let uuid = try await synchronizer.importAccount(
            ufvk: ufvk,
            seedFingerprint: nil,
            zip32AccountIndex: nil,
            purpose: .viewOnly,
            name: "Imported viewing key",
            keySource: nil,
            birthday: birthday
        )
        return remember(uuid)
    }

    func deleteAccount(_ account: ZcashAccountID) async throws {
        guard let uuid = accounts[account] else { throw ZcashEngineError.noAccount }
        try await synchronizer.deleteAccount(uuid)
        accounts[account] = nil
        hdIndices[account] = nil
    }

    func stop() async {
        synchronizer.stop()
        if isStopped(synchronizer.latestState.syncStatus) { return }

        let stopped = Task {
            for await state in synchronizer.stateStream.values {
                if isStopped(state.syncStatus) { return }
            }
        }
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            stopped.cancel()
        }
        await stopped.value
        timeout.cancel()
    }

    func accountBalances() async throws -> [ZcashAccountID: ZcashEngineBalance] {
        let sdkBalances = try await synchronizer.getAccountsBalances()
        var result: [ZcashAccountID: ZcashEngineBalance] = [:]
        for (uuid, balance) in sdkBalances {
            let id = remember(uuid)
            let shielded = balance.shieldedTotal().amount
            let transparent = balance.unshielded.amount
            let spendable = balance.shieldedSpendableValue.amount
            result[id] = ZcashEngineBalance(
                total: shielded + transparent,
                spendable: spendable,
                pending: shielded - spendable,
                transparent: transparent
            )
        }
        return result
    }

    func transactions(page: Int) async throws -> [(account: ZcashAccountID, transaction: WalletTransaction)] {
        let repository = synchronizer.paginatedTransactions(of: .all)
        guard let overviews = try await repository.page(page) else { return [] }
        return overviews.map { (remember($0.accountUUID), Self.mapTransaction($0)) }
    }

    func unifiedAddress(account: ZcashAccountID) async throws -> String {
        guard let uuid = accounts[account] else { throw ZcashEngineError.noAccount }
        return try await synchronizer.getUnifiedAddress(accountUUID: uuid).stringEncoded
    }

    func transparentAddress(account: ZcashAccountID) async throws -> String {
        guard let uuid = accounts[account] else { throw ZcashEngineError.noAccount }
        return try await synchronizer.getTransparentAddress(accountUUID: uuid).stringEncoded
    }

    func shieldFunds(account: ZcashAccountID, seed: [UInt8], memo: String?) async throws -> Bool {
        guard let uuid = accounts[account], let hdIndex = hdIndices[account] else { throw ZcashEngineError.noAccount }
        let memoValue = try memo.map { try Memo(string: $0) } ?? Memo.empty
        // User-initiated, not an automatic sweep, so shield whatever is there rather than
        // withholding below some dust threshold.
        guard let proposal = try await synchronizer.proposeShielding(
            accountUUID: uuid,
            shieldingThreshold: .zero,
            memo: memoValue,
            transparentReceiver: nil
        ) else {
            return false
        }

        let usk = try DerivationTool(networkType: network).deriveUnifiedSpendingKey(seed: seed, accountIndex: hdIndex)
        return try await submitProposal(proposal, spendingKey: usk)
    }

    func classifyAddress(_ address: String) -> ZcashAddressKind {
        guard let recipient = try? Recipient(address, network: network) else { return .invalid }
        switch recipient {
        case .transparent, .tex:
            return .transparent
        case .sapling, .unified:
            return .shielded
        }
    }

    func estimateFee(account: ZcashAccountID, to address: String, amount: Int64, memo: String?) async throws -> Int64 {
        guard let uuid = accounts[account] else { throw ZcashEngineError.noAccount }
        do {
            let proposal = try await buildTransferProposal(accountUUID: uuid, address: address, amount: amount, memo: memo)
            return proposal.totalFeeRequired().amount
        } catch {
            throw Self.mapToWalletError(error)
        }
    }

    func send(account: ZcashAccountID, to address: String, amount: Int64, memo: String?, seed: [UInt8]) async throws {
        guard let uuid = accounts[account], let hdIndex = hdIndices[account] else { throw ZcashEngineError.noAccount }
        do {
            let proposal = try await buildTransferProposal(accountUUID: uuid, address: address, amount: amount, memo: memo)
            let usk = try DerivationTool(networkType: network).deriveUnifiedSpendingKey(seed: seed, accountIndex: hdIndex)
            _ = try await submitProposal(proposal, spendingKey: usk)
        } catch {
            throw Self.mapToWalletError(error)
        }
    }

    /// Records an `AccountUUID` the SDK just handed back (from `listAccounts`,
    /// `importAccount`, or `getAccountsBalances`) under its app-facing id.
    @discardableResult
    private func remember(_ uuid: AccountUUID) -> ZcashAccountID {
        let id = ZcashAccountID(raw: Data(uuid.id))
        accounts[id] = uuid
        return id
    }

    func ensureSaplingParamsDownloaded() async throws {
        try await SaplingParameterDownloader.downloadParamsIfnotPresent(
            spendURL: spendParamsURL,
            spendSourceURL: saplingParamsSourceURL.spendParamFileURL,
            outputURL: outputParamsURL,
            outputSourceURL: saplingParamsSourceURL.outputParamFileURL,
            logger: paramsLogger
        )
    }

    private func buildTransferProposal(accountUUID: AccountUUID, address: String, amount: Int64, memo: String?) async throws -> Proposal {
        let recipient = try Recipient(address, network: network)
        let memoValue = try memo.map { try Memo(string: $0) }
        return try await synchronizer.proposeTransfer(accountUUID: accountUUID, recipient: recipient, amount: Zatoshi(amount), memo: memoValue)
    }

    /// Shared by `shieldFunds` and `send` — both just differ in how they build the `Proposal`.
    /// Downloads Sapling parameters automatically on first use (`SDKBroadcaster`), same as any
    /// other `createProposedTransactions` call.
    private func submitProposal(_ proposal: Proposal, spendingKey: UnifiedSpendingKey) async throws -> Bool {
        let stream = try await synchronizer.createProposedTransactions(proposal: proposal, spendingKey: spendingKey)
        for try await result in stream {
            switch result {
            case .success, .notAttempted:
                continue
            case .grpcFailure(_, let error):
                throw error
            case .submitFailure(_, _, let description):
                throw ZcashEngineError.transactionSubmissionFailed(description)
            }
        }
        return true
    }

    /// Translates SDK-specific errors into `WalletError` here, inside the one file that's
    /// allowed to know about `ZcashLightClientKit` — `ZECWallet` only ever sees `WalletError`
    /// or an opaque `Error` it falls back to `.localizedDescription` for.
    private static func mapToWalletError(_ error: Error) -> Error {
        guard let zcashError = error as? ZcashError else { return error }
        switch zcashError {
        case .rustProposalInsufficientFunds(let available, _):
            return WalletError.insufficientFunds(available: CoinAmount(atomic: available.amount, coin: .zcash))
        case .recipientInvalidInput:
            return WalletError.invalidAddress
        case .saplingParamsDownload, .saplingParamsCantMoveDownloadedFile,
             .saplingParamsInvalidSpendParams, .saplingParamsInvalidOutputParams,
             .walletTransEncoderCreateTransactionMissingSaplingParams:
            return WalletError.paramsDownloadFailed
        default:
            return error
        }
    }

    private func isStopped(_ status: SyncStatus) -> Bool {
        switch status {
        case .stopped, .unprepared:
            return true
        default:
            return false
        }
    }

    private static func mapStatus(_ status: SyncStatus, latest: BlockHeight, scanned: BlockHeight) -> WalletSyncStatus {
        switch status {
        case .unprepared, .stopped:
            return .idle
        case .syncing(let progress, _):
            return .syncing(progress: Int(progress * 100), remaining: max(0, latest - scanned))
        case .upToDate:
            return .synced(height: UInt64(max(0, latest)))
        case .error(let error):
            return .error(.unknown(error.localizedDescription))
        }
    }

    /// `account` is left at 0 here — `ZECWallet.refreshTransactions()` is the one place that
    /// knows the app-side index for the `ZcashAccountID` this transaction came back paired
    /// with, and stamps it in before publishing.
    private static func mapTransaction(_ overview: ZcashTransaction.Overview) -> WalletTransaction {
        let hash = overview.rawID.reversed().map { String(format: "%02x", $0) }.joined()
        let isFailed: Bool
        if case .expired = overview.state { isFailed = true } else { isFailed = false }
        return WalletTransaction(
            hash: hash,
            type: overview.isSentTransaction ? .outgoing : .incoming,
            amount: CoinAmount(atomic: abs(overview.value.amount), coin: .zcash),
            fee: CoinAmount(atomic: overview.fee?.amount ?? 0, coin: .zcash),
            timestamp: Int(overview.blockTime ?? Date().timeIntervalSince1970),
            blockHeight: UInt64(overview.minedHeight ?? 0),
            isPending: overview.minedHeight == nil,
            isFailed: isFailed,
            memo: nil,
            recipient: nil,
            account: 0
        )
    }
}
