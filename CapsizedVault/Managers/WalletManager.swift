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

/// Owns the wallet list and which wallet is active. Node/server lists live on `NodeStore`,
/// and building wallet instances lives on `WalletFactory` — this class no longer knows how
/// to construct an engine itself.
class WalletManager: ObservableObject {

    static let shared = WalletManager()

    private init() {

        guard let realm = RealmManager.shared.getThreadSaveRealm() else {
            return
        }

        let results = realm.objects(WalletsData.self).sorted(byKeyPath: "createdAt", ascending: false)
        wallets = results.map { WalletFactory.make(from: $0) }

        if let foundActiveWallet = findActiveWallet() {
            setActiveWallet(foundActiveWallet)
        }


    }

    @Published var wallets: [BaseWallet] = []

    @Published var activeWallet: BaseWallet? {
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

    func setActiveWallet(_ wallet: BaseWallet) {
        guard wallets.contains(where: { $0.walletId == wallet.walletId }) else {
            return
        }

        if let activeWallet = activeWallet {
            activeWallet.deactivate()
        }

        activeWallet = wallet
        activeWallet?.activate()

        _ = RealmManager.shared.setActiveWallet(walletId: wallet.walletId)
    }

    func updateActiveWalletTitle(_ newTitle: String) {
        guard let activeWallet else {
            return
        }

        activeWallet.title = newTitle

        _ = RealmManager.shared.updateWalletTitle(walletId: activeWallet.walletId, newTitle: newTitle)
    }

    func addWallet(_ request: NewWalletRequest, title: String, pendingSeedBackup: Bool = true) {
        let newWallet = WalletFactory.make(from: request, title: title, pendingSeedBackup: pendingSeedBackup)
        wallets.insert(newWallet, at: 0)

        _ = RealmManager.shared.saveNewWallet(
            title: title,
            walletId: newWallet.walletId,
            pendingSeedBackup: pendingSeedBackup,
            coin: newWallet.coin,
            birthdayHeight: newWallet.zcashWallet?.birthdayHeight
        )

        if case .zcashViewOnly = request {
            RealmManager.shared.saveZcashAccount(
                walletId: newWallet.walletId,
                accountIndex: 0,
                label: "Account 1",
                isImportedViewingKey: true
            )
        }

        setActiveWallet(newWallet)
    }

    func clearPendingSeedBackup(for wallet: BaseWallet) {
        wallet.pendingSeedBackup = false
        _ = RealmManager.shared.clearPendingSeedBackup(walletId: wallet.walletId)
    }

    func removeActiveWallet() {
        guard let activeWallet else {
            return
        }

        let walletId = activeWallet.walletId
        // removeFiles() first — it needs the still-live engine (e.g. XMRWallet.walletPath
        // comes from the Kit) to know what to delete.
        activeWallet.removeFiles()
        activeWallet.deactivate()
        self.activeWallet = nil

        _ = RealmManager.shared.removeWallet(walletId: walletId)
        wallets.removeAll { $0.walletId == walletId }

        if let foundActiveWallet = findActiveWallet() {
            setActiveWallet(foundActiveWallet)
        }

    }

    private func findActiveWallet() -> BaseWallet? {
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
