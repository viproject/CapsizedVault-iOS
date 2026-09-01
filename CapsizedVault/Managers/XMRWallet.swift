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

class XMRWallet: ObservableObject, CapsizedMoneroKitDelegate, Equatable, Identifiable {
    
    enum XMRSendPriority: Int, CaseIterable {
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
        
    @Published var transactions: [TransactionInfo] = []
    @Published var walletState: WalletState = .notSynced(error: .notStarted)
    @Published var isConnected: Bool = false
    @Published var activeAccountIndex: UInt32 = 0
    @Published var accountBalances: [BalanceInfo] = []
    /// Last persisted total unlocked balance in piconero (sum across all accounts).
    /// -1 until the wallet has synced at least once.
    @Published var cachedTotalUnlocked: Int64 = -1
    @Published var pendingSeedBackup: Bool = false
    @Published var walletError: String?
    @Published var activeNodeURL: String = ""

    @Published var title: String = ""
    var walletId: String = ""
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
        guard accountBalances.indices.contains(Int(activeAccountIndex)) else { return BalanceInfo(all: 0, unlocked: 0) }
        return accountBalances[Int(activeAccountIndex)]
    }
    
    var activeSubaddresses: [(String, Int, Int, String)] {
        let subaddresses = moneroKit?.getSubaddresses(forAccount: activeAccountIndex).sorted { $0.1 > $1.1 } ?? []
        return subaddresses.map { (address, index, txCount) in
            let label = moneroKit?.subaddressLabel(accountIndex: activeAccountIndex, addressIndex: UInt32(index)) ?? ""
            return (address, index, txCount, label)
        }
    }
    
    var nodePool: NodePool? {
        moneroKit?.nodePool
    }

    func probeAllNodes() {
        moneroKit?.nodePool.probeAllNodes()
    }

    private var moneroKit: Kit?
    private var lastWallet: MoneroWallet?
    private var lastRestoreHeight: UInt64?
    private var lastIsNewWallet: Bool = false
    
    init(fromRealm realmObj: WalletsData) {
        self.title = realmObj.title
        self.walletId = realmObj.walletId
        self.activeAccountIndex = UInt32(realmObj.lastUsedAccount)
        self.pendingSeedBackup = realmObj.pendingSeedBackup
        self.cachedTotalUnlocked = realmObj.cachedTotalUnlockedPiconero

        //on app launch
        let wallet: MoneroWallet = .polyseed(seed: [], passphrase: "")
        connectToWallet(wallet)
    }
    
    init(fromNewMoneroWallet newWallet: MoneroWallet, title: String, pendingSeedBackup: Bool = true, restoreHeight: UInt64? = nil) {
        self.title = title
        self.walletId = UUID().uuidString
        self.activeAccountIndex = 0
        self.pendingSeedBackup = pendingSeedBackup

        connectToWallet(newWallet, restoreHeight: restoreHeight, isNewWallet: true)
    }
    
    func update(fromRealm realmObj: WalletsData) {
        self.title = realmObj.title
        self.walletId = realmObj.walletId
        self.activeAccountIndex = UInt32(realmObj.lastUsedAccount)
    }
    
    
    func startSync() {
        moneroKit?.start()
    }
    
    func stopSync() {
        moneroKit?.stop()
    }

    func restartSync() {
        if walletError != nil {
            walletError = nil
            if let wallet = lastWallet {
                connectToWallet(wallet, restoreHeight: lastRestoreHeight, isNewWallet: lastIsNewWallet)
                startSync()
            }
        } else {
            moneroKit?.restart()
        }
    }

    func accountLabel(for index: UInt32) -> String {
        // Try the live C++ wallet first (available once sync has started)
        let liveLabel = moneroKit?.accountLabel(for: index)
        if let liveLabel, !liveLabel.isEmpty { return liveLabel }
        // Fall back to the label persisted in the last balance update (available
        // immediately via preloadCachedData, even during connecting state)
        if accountBalances.indices.contains(Int(index)) {
            let cached = accountBalances[Int(index)].label
            if !cached.isEmpty { return cached }
        }
        return index == 0 ? "Primary account" : "Account \(index)"
    }
    
    func numberOfAccounts() -> Int {
        return moneroKit?.numberOfAccounts() ?? 1
    }
    
    func setActiveAccountIndex(_ accountIndex: Int) {
        activeAccountIndex = UInt32(accountIndex)
        _ = RealmManager.shared.setActiveAccount(walletId: walletId, accountIndex: accountIndex)
    }
    
    func setAccountLabel(accountIndex: UInt32, label: String) {
        moneroKit?.setAccountLabel(accountIndex: accountIndex, label: label)
        objectWillChange.send()
    }

    func addNewAccount(label: String) {
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
    
    func estimateFeeDouble(address: String, amount: Double, priority: XMRSendPriority) -> Double {
        do {
            let picoAmount = amount * 1_000_000_000_000
            guard picoAmount > 0, picoAmount < Double(Int.max) else { return 0 }
            let fee = try moneroKit?.estimateFee(address: address, amount: .value(Int(picoAmount)), priority: priority.sendPriority) ?? 0
            let value = Double(fee) / 1_000_000_000_000
            return value
        }
        catch {
            return 0
        }
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

        let nodes = WalletManager.allNodes()

        guard !nodes.isEmpty else { return }

        let height = restoreHeight ?? UInt64(RestoreHeight.getHeight(date: Date()))
        let walletPassword = resolveWalletPassword()
        #if DEBUG
        let coreLogLevel: Int32? = 4
        #else
        let coreLogLevel: Int32? = nil
        #endif

        do {
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
                moneroCoreLogLevel: coreLogLevel
            )

            kit.delegate = self
            kit.preloadCachedData()
            moneroKit = kit
            isConnected = true
            activeNodeURL = kit.activeNodeDescription
        } catch MoneroCoreError.walletFilesMissing {
            walletError = "Wallet files are missing or corrupted. Please restore the wallet from seed or keys."
        } catch MoneroCoreError.walletRecoveryFailed(let message) {
            walletError = "Wallet recovery failed: \(message)"
        } catch {
            walletError = "Failed to initialize wallet: \(error.localizedDescription)"
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
    
    //MARK: - CapsizedMoneroKitDelegate
    
    func balancesDidChange(balanceInfos: [CapsizedMoneroKit.BalanceInfo]) {
        let total = balanceInfos.reduce(Int64(0)) { $0 + $1.unlocked }
        DispatchQueue.main.async {
            self.accountBalances = balanceInfos
            self.cachedTotalUnlocked = total
            _ = RealmManager.shared.updateCachedBalance(walletId: self.walletId, totalUnlocked: total)
        }
    }
    
    func subAddressesUpdated(subaddresses: [CapsizedMoneroKit.SubAddress]) {}

    func transactionsUpdated(inserted: [CapsizedMoneroKit.TransactionInfo], updated: [CapsizedMoneroKit.TransactionInfo]) {
        DispatchQueue.main.async {
            self.transactions = inserted + updated
        }
    }
    
    func walletStateDidChange(state: CapsizedMoneroKit.WalletState) {
        DispatchQueue.main.async {
            self.walletState = state
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
