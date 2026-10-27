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

protocol ZcashEngine: AnyObject {
    var updates: AsyncStream<ZcashEngineUpdate> { get }

    /// `birthday` is `nil` for a brand-new wallet (the SDK picks a reorg-safe recent height)
    /// or a restore height for a restored wallet. Ignored by the SDK once an account exists.
    func prepare(seed: [UInt8], birthday: Int?) async throws
    /// For a wallet with no seed. `pendingUFVK` is the viewing key to import on first
    /// activation; subsequent activations pass `nil` since the SDK already has the account
    /// on disk. Throws `ZcashEngineError.viewingKeyMissing` if no account exists yet and
    /// `pendingUFVK` is `nil`.
    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws
    func start() async throws
    /// Returns only once the SDK itself reports it has stopped.
    func stop() async
    func accountBalance() async throws -> WalletAccountBalance?
    func transactions(page: Int) async throws -> [WalletTransaction]
}

enum ZcashEngineError: LocalizedError {
    case viewingKeyMissing

    var errorDescription: String? {
        switch self {
        case .viewingKeyMissing:
            return "No viewing key available to import."
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
    private var accountUUID: AccountUUID?
    private var cancellables: Set<AnyCancellable> = []
    private let updatesContinuation: AsyncStream<ZcashEngineUpdate>.Continuation

    init(walletId: String) {
        let dir = SDKZcashEngine.walletDirectory(for: walletId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let network = ZcashNetworkBuilder.network(for: .mainnet)
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
            spendParamsURL: dir.appendingPathComponent(ZcashSDK.spendParamFilename),
            outputParamsURL: dir.appendingPathComponent(ZcashSDK.outputParamFilename),
            saplingParamsSourceURL: .default,
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
        accountUUID = try await synchronizer.listAccounts().first?.id
    }

    func prepareViewOnly(pendingUFVK: String?, birthday: Int?) async throws {
        _ = try await synchronizer.prepare(with: nil, walletBirthday: birthday, name: "Account 1", keySource: nil)
        if let existing = try await synchronizer.listAccounts().first {
            accountUUID = existing.id
            return
        }
        guard let pendingUFVK else {
            throw ZcashEngineError.viewingKeyMissing
        }
        accountUUID = try await synchronizer.importAccount(
            ufvk: pendingUFVK,
            seedFingerprint: nil,
            zip32AccountIndex: nil,
            purpose: .viewOnly,
            name: "Account 1",
            keySource: nil,
            birthday: birthday
        )
    }

    func start() async throws {
        try await synchronizer.start(retry: true)
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

    func accountBalance() async throws -> WalletAccountBalance? {
        guard let accountUUID, let balance = try await synchronizer.getAccountsBalances()[accountUUID] else { return nil }
        let shielded = balance.shieldedTotal().amount
        let transparent = balance.unshielded.amount
        let spendable = balance.shieldedSpendableValue.amount
        return WalletAccountBalance(
            index: 0,
            label: "Account 1",
            total: CoinAmount(atomic: shielded + transparent, coin: .zcash),
            spendable: CoinAmount(atomic: spendable, coin: .zcash),
            pending: CoinAmount(atomic: shielded - spendable, coin: .zcash),
            transparent: CoinAmount(atomic: transparent, coin: .zcash)
        )
    }

    func transactions(page: Int) async throws -> [WalletTransaction] {
        let repository = synchronizer.paginatedTransactions(of: .all)
        guard let overviews = try await repository.page(page) else { return [] }
        return overviews.map(Self.mapTransaction)
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
