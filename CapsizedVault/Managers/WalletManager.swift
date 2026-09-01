//
//  WalletManager.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/02/2026.
//

import Foundation
import Combine
import RealmSwift
import Realm
import SwiftUI
import CapsizedMoneroKit

class WalletManager: ObservableObject {
    
    static let shared = WalletManager()
    
    private init() {
        
        guard let realm = RealmManager.shared.getThreadSaveRealm() else {
            return
        }
        
        let results = realm.objects(WalletsData.self).sorted(byKeyPath: "createdAt", ascending: false)
        wallets = results.map({XMRWallet(fromRealm: $0)})
        
        if let foundActiveWallet = findActiveWallet() {
            setActiveWallet(foundActiveWallet)
        }
        
        
    }
    
    @Published var wallets: [XMRWallet] = []

    @Published var activeWallet: XMRWallet? {
        didSet {
            // Cancel previous observation
            activeWalletCancellable?.cancel()
            
            // Observe new active wallet
            activeWalletCancellable = activeWallet?.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }
    
    private var activeWalletCancellable: AnyCancellable?
    
    static let defaultNodes: [Node] = [
        Node(url: URL(string: "https://xmr-node.cakewallet.com:18081")!, isTrusted: false),
        Node(url: URL(string: "https://node.monerodevs.org:18089")!, isTrusted: false),
        Node(url: URL(string: "https://nodes.hashvault.pro:18081")!, isTrusted: false),
        Node(url: URL(string: "https://monero.stackwallet.com:18081")!, isTrusted: false),
        Node(url: URL(string: "https://node.xmr.rocks:18089")!, isTrusted: false),
        Node(url: URL(string: "https://xmr-de.boldsuck.org:18081")!, isTrusted: false),
    ]

    static func allNodes() -> [Node] {
        let customNodes = RealmManager.shared.getCustomNodes().compactMap { nodeData -> Node? in
            guard let url = URL(string: nodeData.urlString) else { return nil }
            return Node(
                url: url,
                isTrusted: nodeData.isTrusted,
                login: nodeData.login.isEmpty ? nil : nodeData.login,
                password: nodeData.password.isEmpty ? nil : nodeData.password
            )
        }
        let defaultURLs = Set(defaultNodes.map(\.url))
        let uniqueCustom = customNodes.filter { !defaultURLs.contains($0.url) }
        return defaultNodes + uniqueCustom
    }
    
    func setActiveWallet(_ wallet: XMRWallet) {
        guard wallets.contains(wallet) else {
            return
        }
        
        if let activeWallet = activeWallet {
            activeWallet.stopSync()
        }
        
        activeWallet = wallet
        activeWallet?.startSync()
        
        _ = RealmManager.shared.setActiveWallet(walletId: wallet.walletId)
    }
    
    func updateActiveWalletTitle(_ newTitle: String) {
        guard let activeWallet else {
            return
        }
        
        activeWallet.title = newTitle
        
        _ = RealmManager.shared.updateWalletTitle(walletId: activeWallet.walletId, newTitle: newTitle)
    }
    
    func addNewMoneroWallet(title: String, moneroWallet: MoneroWallet, pendingSeedBackup: Bool = true, restoreHeight: UInt64? = nil) {
        let newWallet = XMRWallet(fromNewMoneroWallet: moneroWallet, title: title, pendingSeedBackup: pendingSeedBackup, restoreHeight: restoreHeight)
        wallets.insert(newWallet, at: 0)

        _ = RealmManager.shared.saveNewWallet(title: title, walletId: newWallet.walletId, pendingSeedBackup: pendingSeedBackup)

        setActiveWallet(newWallet)
    }
    
    func clearPendingSeedBackup(for wallet: XMRWallet) {
        wallet.pendingSeedBackup = false
        _ = RealmManager.shared.clearPendingSeedBackup(walletId: wallet.walletId)
    }

    func removeActiveWallet() {
        guard let activeWallet else {
            return
        }
        
        let walletPath = activeWallet.walletPath
        let walletId = activeWallet.walletId
        activeWallet.stopSync()
        self.activeWallet = nil
        
        if let walletPath {
            Kit.removeWallet(path: walletPath)
        }

        KeychainHelper.deleteWalletPassword(for: walletId)
        _ = RealmManager.shared.removeWallet(walletId: walletId)
        wallets.removeAll { $0.walletId == walletId }
        
        if let foundActiveWallet = findActiveWallet() {
            setActiveWallet(foundActiveWallet)
        }
        
    }
    
    private func findActiveWallet() -> XMRWallet? {
        guard let realm = RealmManager.shared.getThreadSaveRealm() else {
            return nil
        }
        
        if let activeRealmObject = realm.objects(WalletsData.self).sorted(byKeyPath: "lastActive", ascending: false).first {
            for item in wallets {
                if item.walletId == activeRealmObject.walletId {
                    return item
                }
            }
        }
        return nil
    }
    
}
