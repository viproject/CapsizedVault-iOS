//
//  MoneroWallet.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/02/2026.
//

import Foundation
import Combine
import Security
import CapsizedMoneroKit
import HsToolKit

class XMRWallet: BaseWallet, CapsizedMoneroKitDelegate, Equatable {

    nonisolated enum XMRSendPriority: Int, CaseIterable, Sendable {
        case `default`, low, medium, high

        var sendPriority: CapsizedMoneroKit.SendPriority {
            switch self {
            case .default:
                return .default
            case .low:
                return .low
            case .medium:
                return .medium
            case .high:
                return .high
            }
        }

        var description: String {
            switch self {
            case .default:
                return "default"
            case .low:
                return "low"
            case .medium:
                return "medium"
            case .high:
                return "high"
            }
        }
    }

    /// Monero-native transaction list, straight from the Kit. Read by the views that stay
    /// Monero-specific (`WalletMainView`'s transaction section, `TransactionDetailsView`).
    /// Distinct from the inherited, coin-neutral `transactions`, which this class also keeps
    /// populated for future shared-view use (see `transactionsUpdated(inserted:updated:)`).
    @Published var moneroTransactions: [TransactionInfo] = []
    @Published var walletState: WalletState = .notSynced(error: .notStarted)
    @Published var isConnected: Bool = false
    /// Monero-native per-account balances, straight from the Kit. Read by the views that stay
    /// Monero-specific (`AccountSwitchSheet`). Distinct from the inherited `accounts`.
    @Published var moneroAccountBalances: [BalanceInfo] = []
    @Published var activeNodeURL: String = ""
    @Published var nodeSwitchError: String?
    /// URL of the node a switch is currently in flight for, so the UI can show a
    /// pending/spinner state instead of appearing frozen during the reconnect.
    @Published var pendingNodeURL: String?

    var isSynchronized: Bool {
        if case .synced = walletState {
            return true
        }
        return false
    }

    var state: String {
        return stateDescription(walletState)
    }
    var walletHeight: UInt64 {
        return moneroKit?.lastBlockInfo ?? 0
    }
    var walletRestoreHeight: UInt64 {
        return moneroKit?.walletRestoreHeight ?? 0
    }

    var currentPolyseed: String? {
        return moneroKit?.currentWalletPolyseed
    }
    var currentPolyseedArray: [String] {
        guard let polyseed = currentPolyseed, !polyseed.isEmpty else {
            return []
        }
        return polyseed.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }
    }
    var currentLegacySeed: String? {
        return moneroKit?.currentWalletSeed
    }
    var currentLegacySeedArray: [String] {
        guard let seed = currentLegacySeed, !seed.isEmpty else {
            return []
        }
        return seed.components(separatedBy: " ")
    }
    var primaryAddress: String? {
        return moneroKit?.primaryAddress
    }
    var spendKeyPublic: String? {
        return moneroKit?.publicSpendKey
    }
    var spendKeyPrivate: String? {
        return moneroKit?.secretSpendKey
    }
    var viewKeyPublic: String? {
        return moneroKit?.publicViewKey
    }
    var viewKeyPrivate: String? {
        return moneroKit?.secretViewKey
    }
    var walletPath: String? {
        return moneroKit?.walletPath
    }

    var activeBalance: BalanceInfo {
        guard moneroAccountBalances.indices.contains(Int(activeAccountIndex)) else { return BalanceInfo(all: 0, unlocked: 0) }
        return moneroAccountBalances[Int(activeAccountIndex)]
    }

    var activeSubaddresses: [(String, Int, Int, String)] {
        let subaddresses = moneroKit?.getSubaddresses(forAccount: activeAccountIndex).sorted { $0.1 > $1.1 } ?? []
        return subaddresses.map { (address, index, txCount) in
            let label = moneroKit?.subaddressLabel(accountIndex: activeAccountIndex, addressIndex: UInt32(index)) ?? ""
            return (address, index, txCount, label)
        }
    }

    /// Runs a manual node-latency test and reports each result as it arrives. Results are
    /// isolated from the periodic background probe and the sync heartbeat (see
    /// `NodePool.onManualProbeResult`). Returns the current node list so the caller can seed
    /// its display state before results start coming in.
    @discardableResult
    func testAllNodes(onResult: @escaping (Node, NodeMetrics) -> Void) -> [Node] {
        guard let pool = moneroKit?.nodePool else { return [] }
        pool.onManualProbeResult = onResult
        pool.probeAllNodesSequentially()
        return pool.nodes
    }

    func selectNode(urlString: String) {
        guard let url = URL(string: urlString),
              let pool = moneroKit?.nodePool,
              let node = pool.nodes.first(where: { $0.url == url }) else { return }
        nodeSwitchError = nil
        pendingNodeURL = urlString
        moneroKit?.switchToNode(node) { [weak self] result in
            self?.pendingNodeURL = nil
            if case .failure = result {
                self?.nodeSwitchError = "Could not connect to \(urlString)"
            }
        }
    }

    /// Re-reads the persisted node list (defaults + custom) into the live node pool.
    /// Call after any custom node is added, edited, or removed so the change takes
    /// effect immediately instead of only on the next wallet reconnect.
    func syncNodePool() {
        moneroKit?.nodePool.autoSelectableURLs = Set(NodeStore.defaults(for: .monero).map(\.url))
        moneroKit?.nodePool.updateNodes(NodeStore.all(for: .monero))
    }

    /// Best-scoring node currently eligible for automatic selection (i.e. a default node) —
    /// used to pick a node when the user re-enables auto-select while pinned to a custom one.
    func bestAutoSelectableNodeURL() -> String? {
        moneroKit?.nodePool.bestNode().url.absoluteString
    }

    func probeAllNodes() {
        moneroKit?.nodePool.probeAllNodes()
    }

    /// Called when the user toggles "Choose node automatically" so auto-failover
    /// immediately stops (or resumes) moving the wallet off its current node.
    func setAutoNodeSelectionEnabled(_ enabled: Bool) {
        moneroKit?.isAutoNodeSelectionEnabled = enabled
    }

    private var moneroKit: Kit?
    private var lastWallet: MoneroWallet?
    private var lastRestoreHeight: UInt64?
    private var lastIsNewWallet: Bool = false

    init(fromRealm realmObj: WalletsData) {
        super.init(coin: .monero)
        self.title = realmObj.title
        self.walletId = realmObj.walletId
        self.activeAccountIndex = UInt32(realmObj.lastUsedAccount)
        self.pendingSeedBackup = realmObj.pendingSeedBackup
        let piconero = realmObj.cachedTotalUnlockedPiconero
        self.cachedTotalUnlocked = piconero >= 0 ? CoinAmount(atomic: piconero, coin: .monero) : nil

        // Engine connection is deferred to activate() — see BaseWallet's "lightweight until
        // activated" design. Stash what connectToWallet needs for when that happens.
        lastWallet = .polyseed(seed: [], passphrase: "")
        lastRestoreHeight = nil
        lastIsNewWallet = false
    }

    init(fromNewMoneroWallet newWallet: MoneroWallet, title: String, pendingSeedBackup: Bool = true, restoreHeight: UInt64? = nil) {
        super.init(coin: .monero)
        self.title = title
        self.walletId = UUID().uuidString
        self.activeAccountIndex = 0
        self.pendingSeedBackup = pendingSeedBackup

        lastWallet = newWallet
        lastRestoreHeight = restoreHeight
        lastIsNewWallet = true
    }

    func update(fromRealm realmObj: WalletsData) {
        self.title = realmObj.title
        self.walletId = realmObj.walletId
        self.activeAccountIndex = UInt32(realmObj.lastUsedAccount)
    }

    override var kind: WalletKind { .monero(self) }

    override var capabilities: WalletCapabilities {
        WalletCapabilities(
            supportsSubaddresses: true,
            hasTransparentPool: false,
            supportsShielding: false,
            accountCreation: .derive,
            supportsMemo: true,
            supportsSendPriority: true,
            canSend: !isWatchOnly
        )
    }

    override func activate() {
        if moneroKit != nil {
            moneroKit?.start()
            return
        }
        guard let wallet = lastWallet else { return }
        connectToWallet(wallet, restoreHeight: lastRestoreHeight, isNewWallet: lastIsNewWallet)
        moneroKit?.start()
    }

    override func deactivate() {
        moneroKit?.stop()
        moneroKit = nil
        isConnected = false
    }

    override func restartSync() {
        if walletError != nil {
            walletError = nil
            activate()
        } else {
            moneroKit?.restart()
        }
    }

    override func accountLabel(for index: UInt32) -> String {
        // Try the live C++ wallet first (available once sync has started)
        let liveLabel = moneroKit?.accountLabel(for: index)
        if let liveLabel, !liveLabel.isEmpty { return liveLabel }
        // Fall back to the label persisted in the last balance update (available
        // immediately via preloadCachedData, even during connecting state)
        if moneroAccountBalances.indices.contains(Int(index)) {
            let cached = moneroAccountBalances[Int(index)].label
            if !cached.isEmpty { return cached }
        }
        return index == 0 ? "Primary account" : "Account \(index)"
    }

    override func numberOfAccounts() -> Int {
        return moneroKit?.numberOfAccounts() ?? 1
    }

    override func setActiveAccountIndex(_ accountIndex: Int) {
        activeAccountIndex = UInt32(accountIndex)
        _ = RealmManager.shared.setActiveAccount(walletId: walletId, accountIndex: accountIndex)
    }

    override func setAccountLabel(accountIndex: UInt32, label: String) {
        moneroKit?.setAccountLabel(accountIndex: accountIndex, label: label)
        objectWillChange.send()
    }

    override func addNewAccount(label: String) {
        moneroKit?.addNewAccount(label: label)
        setActiveAccountIndex(numberOfAccounts() - 1)
    }

    @discardableResult
    func addNewSubaddress(label: String = "") -> String? {
        moneroKit?.addNewSubaddress(accountIndex: activeAccountIndex, label: label)
    }

    func setSubaddressLabel(addressIndex: Int, label: String) {
        moneroKit?.setSubaddressLabel(accountIndex: activeAccountIndex, addressIndex: UInt32(addressIndex), label: label)
        objectWillChange.send()
    }

    /// Estimates the fee for a Monero-priority-aware send. Runs the Kit call off the main
    /// actor so `SendXMRView` can call it from a debounced `.task(id:)` instead of blocking
    /// the UI thread on every render.
    func estimateFeeDouble(address: String, amount: Double, priority: XMRSendPriority) async -> Double {
        let kit = moneroKit
        return await Task.detached(priority: .userInitiated) {
            do {
                let picoAmount = amount * 1_000_000_000_000
                guard picoAmount > 0, picoAmount < Double(Int.max) else { return 0 }
                let fee = try kit?.estimateFee(address: address, amount: .value(Int(picoAmount)), priority: priority.sendPriority) ?? 0
                return Double(fee) / 1_000_000_000_000
            }
            catch {
                return 0
            }
        }.value
    }

    override func estimateFee(to address: String, amount: CoinAmount) async -> Result<CoinAmount, WalletError> {
        let kit = moneroKit
        return await Task.detached(priority: .userInitiated) {
            do {
                guard amount.atomic > 0, amount.atomic < Int64(Int.max) else { return .success(.zero(.monero)) }
                let fee = try kit?.estimateFee(address: address, amount: .value(Int(amount.atomic)), priority: .default) ?? 0
                return .success(CoinAmount(atomic: Int64(fee), coin: .monero))
            } catch {
                return .failure(.unknown(error.localizedDescription))
            }
        }.value
    }

    private func resolveWalletPassword() -> String {
        if let stored = KeychainHelper.walletPassword(for: walletId) {
            return stored
        }
        // Generate a cryptographically random 32-byte password and persist it
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let password = bytes.map { String(format: "%02x", $0) }.joined()
        KeychainHelper.saveWalletPassword(password, for: walletId)
        return password
    }

    private func connectToWallet(_ moneroWallet: MoneroWallet, restoreHeight: UInt64? = nil, isNewWallet: Bool = false) {
        lastWallet = moneroWallet
        lastRestoreHeight = restoreHeight
        lastIsNewWallet = isNewWallet

        var nodes = NodeStore.all(for: .monero)
        guard !nodes.isEmpty else { return }

        // NodePool.init always makes nodes[0] the active node, so putting the user's
        // pinned node first is what makes the pin actually take effect on (re)connect.
        let autoSelect = UserDefaults.standard.object(forKey: "nodeAutoSelect") as? Bool ?? true
        if !autoSelect {
            let pinnedURLString = UserDefaults.standard.string(forKey: "nodePinnedURL") ?? ""
            if let index = nodes.firstIndex(where: { $0.url.absoluteString == pinnedURLString }) {
                nodes.insert(nodes.remove(at: index), at: 0)
            }
        }

        let height = restoreHeight ?? UInt64(RestoreHeight.getHeight(date: Date()))
        let walletPassword = resolveWalletPassword()
        #if DEBUG
        let coreLogLevel: Int32? = 4
        #else
        let coreLogLevel: Int32? = nil
        #endif

        do {
//            let kit = try Kit(
//                wallet: moneroWallet,
//                restoreHeight: height,
//                walletId: walletId,
//                walletPassword: walletPassword,
//                nodes: nodes,
//                networkType: .mainnet,
//                isNewWallet: isNewWallet,
//                reachabilityManager: ReachabilityManager(),
//                logger: nil,
//                moneroCoreLogLevel: coreLogLevel
//            )

            let kit = try Kit(
                wallet: moneroWallet,
                restoreHeight: height,
                walletId: walletId,
                walletPassword: walletPassword,
                nodes: nodes,
                networkType: .mainnet,
                isNewWallet: isNewWallet,
                reachabilityManager: ReachabilityManager(),
                logger: nil,
                moneroCoreLogLevel: coreLogLevel,
                nodeRotationMode: .adaptive)


            kit.delegate = self
            kit.isAutoNodeSelectionEnabled = autoSelect
            kit.nodePool.autoSelectableURLs = Set(NodeStore.defaults(for: .monero).map(\.url))
            kit.preloadCachedData()
            moneroKit = kit
            isConnected = true
            setWatchOnly(kit.isWatchOnly)
            activeNodeURL = kit.activeNodeDescription
        } catch MoneroCoreError.walletFilesMissing {
            walletError = .walletFilesMissing
        } catch MoneroCoreError.walletRecoveryFailed(let message) {
            walletError = .recoveryFailed(message)
        } catch {
            walletError = .unknown("Failed to initialize wallet: \(error.localizedDescription)")
        }
    }

    private func stateDescription(_ state: WalletState) -> String {
        switch state {
        case .connecting (let waiting): return "Connecting\(waiting ? "" : "...")"
            case .syncing(let progress, let remainingBlocksCount): return "Syncing (\(progress)%, \(remainingBlocksCount) blocks remaining)"
            case .synced: return "Synced"
            case .idle(let daemonReachable): return "Idle \(daemonReachable ? "🔹" : "❌")"
            case .notSynced(let error): return "Not Synced: \(error)"
        }
    }

    func send(to address: String, amount: Double, sendAll: Bool = false, priority: SendPriority = .default, memo: String?) async -> Result<Bool, Error> {
        let kit = moneroKit
        let account = activeAccountIndex
        return await Task.detached(priority: .userInitiated) {
            do {
                let picoAmount = amount * 1_000_000_000_000
                guard sendAll || (picoAmount > 0 && picoAmount < Double(Int.max)) else {
                    return .failure(MoneroCoreError.transactionSendFailed("Invalid amount"))
                }
                let sendAmount: SendAmount = sendAll ? .all : .value(Int(picoAmount))
                try kit?.send(to: address, amount: sendAmount, account: account, priority: priority, memo: memo)
                return .success(true)
            } catch {
                return .failure(error)
            }
        }.value
    }

    override func send(to address: String, amount: CoinAmount, memo: String?) async -> Result<Bool, WalletError> {
        let result = await send(to: address, amount: Double(amount.atomic) / 1_000_000_000_000, memo: memo)
        switch result {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(.unknown(error.localizedDescription))
        }
    }

    override func removeFiles() {
        if let walletPath {
            Kit.removeWallet(path: walletPath)
        }
        KeychainHelper.deleteWalletPassword(for: walletId)
    }

    override func isValidAddress(_ address: String) -> Bool {
        Kit.isValid(address: address, networkType: .mainnet)
    }

    //MARK: - CapsizedMoneroKitDelegate

    func balancesDidChange(balanceInfos: [CapsizedMoneroKit.BalanceInfo]) {
        let total = balanceInfos.reduce(Int64(0)) { $0 + $1.unlocked }
        DispatchQueue.main.async {
            self.moneroAccountBalances = balanceInfos
            self.accounts = balanceInfos.enumerated().map { index, info in
                WalletAccountBalance(
                    index: index,
                    label: info.label,
                    total: CoinAmount(atomic: info.all, coin: .monero),
                    spendable: CoinAmount(atomic: info.unlocked, coin: .monero),
                    pending: CoinAmount(atomic: info.all - info.unlocked, coin: .monero),
                    transparent: nil
                )
            }
            self.cachedTotalUnlocked = CoinAmount(atomic: total, coin: .monero)
            _ = RealmManager.shared.updateCachedBalance(walletId: self.walletId, totalUnlocked: total)
        }
    }

    func subAddressesUpdated(subaddresses: [CapsizedMoneroKit.SubAddress]) {}

    func transactionsUpdated(inserted: [CapsizedMoneroKit.TransactionInfo], updated: [CapsizedMoneroKit.TransactionInfo]) {
        DispatchQueue.main.async {
            let all = inserted + updated
            self.moneroTransactions = all
            self.transactions = all.map { tx in
                WalletTransaction(
                    hash: tx.hash,
                    type: tx.type == .incoming ? .incoming : .outgoing,
                    amount: CoinAmount(atomic: tx.amount, coin: .monero),
                    fee: CoinAmount(atomic: Int64(tx.fee), coin: .monero),
                    timestamp: tx.timestamp,
                    blockHeight: tx.blockHeight,
                    isPending: tx.isPending,
                    isFailed: tx.isFailed,
                    memo: tx.memo,
                    recipient: tx.recipientAddress,
                    account: tx.account
                )
            }
        }
    }

    func walletStateDidChange(state: CapsizedMoneroKit.WalletState) {
        DispatchQueue.main.async {
            self.walletState = state
            switch state {
            case .connecting:
                self.syncStatus = .connecting
            case .syncing(let progress, let remaining):
                self.syncStatus = .syncing(progress: progress, remaining: remaining)
            case .synced(let height):
                self.syncStatus = .synced(height: height)
            case .notSynced(let error):
                self.syncStatus = .error(.unknown(error.description))
            case .idle:
                self.syncStatus = .idle
            }
        }
    }

    func activeNodeDidChange(node: CapsizedMoneroKit.Node) {
        DispatchQueue.main.async {
            self.activeNodeURL = node.url.absoluteString
        }
    }

    //MARK: - Equatable

    static func == (lhs: XMRWallet, rhs: XMRWallet) -> Bool {
        return lhs.walletId == rhs.walletId
    }


}
