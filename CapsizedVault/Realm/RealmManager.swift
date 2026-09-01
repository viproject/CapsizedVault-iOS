//
//  RealmManager.swift
//  CapsizedVault
//
//  Created by Dmitrij on 05/12/2025.
//

import Foundation
import RealmSwift
import OSLog


class RealmManager {

    static let shared = RealmManager()
    private static let logger = Logger(subsystem: "io.capsized.vault", category: "RealmManager")
    
    private init () {

    }
    
    private var _realm: Realm?
    private var _realmConfiguration: Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = 7
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 7 {
                // Realm zero-fills new Int64 fields; explicitly set -1 (= "never synced")
                // so the wallet list shows "–" instead of 0.0000 XMR for unsynced wallets.
                migration.enumerateObjects(ofType: "WalletsData") { _, newObject in
                    newObject?["cachedTotalUnlockedPiconero"] = Int64(-1)
                }
            }
        }
        return config
    }
    
    func getRealmConfiguration () -> Realm.Configuration {
        return _realmConfiguration
    }
    
    func getMainRealm () -> Realm? {
        guard let realm = _realm else {
            do {
                _realm = try Realm(configuration: _realmConfiguration)
            }
            catch (let error) {
                Self.logger.error("Unable to create main realm: \(error.localizedDescription)")
            }
            
            return _realm
        }
        
        return realm
    }
    
    private func getBackgroundRealm () -> Realm? {

        do {
            let realm = try Realm(configuration: _realmConfiguration)
            return realm
        }
        catch (_) {
        }
        
        return nil
    }
    
    func getThreadSaveRealm () -> Realm? {
        var realmOptional: Realm?
        if Thread.isMainThread {
            realmOptional = getMainRealm()
        }
        else {
            realmOptional = getBackgroundRealm()
        }
        return realmOptional

    }
    
    //was app crash with error 'The Realm is already in a write transaction' (2 apps were running on mac)
    //https://stackoverflow.com/questions/39366182/the-realm-is-already-in-a-write-transaction
    
    func saveNewWallet (title: String, walletId: String, pendingSeedBackup: Bool = true) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }

        do {
            try realm.write {
                let newXMRWallet = WalletsData()
                newXMRWallet.title = title
                newXMRWallet.walletId = walletId
                newXMRWallet.lastActive = Date()
                newXMRWallet.createdAt = Date()
                newXMRWallet.pendingSeedBackup = pendingSeedBackup
                realm.add(newXMRWallet)
            }
        }
        catch (_) {
            return false
        }
        
        return true
        
    }
    
    func updateWalletTitle (walletId: String, newTitle: String) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }
        
        do {
            try realm.write {
                let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
                
                for wallet in walletsData {
                    if wallet.walletId == walletId {
                        wallet.title = newTitle
                    }
                }
            }
            
        }
        catch {
            return false
        }
        
        return true
    }
    
    func setActiveWallet (walletId: String) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }
        
        do {
            try realm.write {
                let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
                for wallet in walletsData {
                    if wallet.walletId == walletId {
                        wallet.lastActive = Date()
                    }
                }
            }
        }
        catch (_) {
            return false
        }
        
        return true
    }
    
    func setActiveAccount (walletId: String, accountIndex: Int) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }
        
        do {
            try realm.write {
                let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
                for wallet in walletsData {
                    if wallet.walletId == walletId {
                        wallet.lastUsedAccount = accountIndex
                    }
                }
            }
        }
        catch {
            return false
        }
        
        return true
    }
    
    func removeWallet (walletId: String) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }
        
        do {
            try realm.write {
                let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
                for wallet in walletsData {
                    if wallet.walletId == walletId {
                        realm.delete(wallet)
                    }
                }
            }
        }
        catch {
            return false
        }
        
        return true
    }
    
    func clearPendingSeedBackup(walletId: String) -> Bool {
        guard let realm = getThreadSaveRealm() else {
            return false
        }

        do {
            try realm.write {
                let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
                for wallet in walletsData {
                    if wallet.walletId == walletId {
                        wallet.pendingSeedBackup = false
                    }
                }
            }
        }
        catch {
            return false
        }

        return true
    }

    func updateCachedBalance(walletId: String, totalUnlocked: Int64) -> Bool {
        guard let realm = getThreadSaveRealm() else { return false }
        do {
            try realm.write {
                for wallet in realm.objects(WalletsData.self) where wallet.walletId == walletId {
                    wallet.cachedTotalUnlockedPiconero = totalUnlocked
                }
            }
        } catch { return false }
        return true
    }

    func getXMRWallets () -> Results<WalletsData> {
        let realm = getThreadSaveRealm()!
        let walletsData: Results<WalletsData> = realm.objects(WalletsData.self)
        return walletsData
    }

    // MARK: - Custom Nodes

    func getCustomNodes() -> [NodeData] {
        guard let realm = getThreadSaveRealm() else { return [] }
        return Array(realm.objects(NodeData.self).sorted(byKeyPath: "createdAt", ascending: true))
    }

    func addCustomNode(urlString: String, isTrusted: Bool, login: String, password: String) -> Bool {
        guard let realm = getThreadSaveRealm() else { return false }

        let exists = realm.objects(NodeData.self).filter("urlString == %@", urlString).first != nil
        if exists { return false }

        do {
            try realm.write {
                let node = NodeData()
                node.urlString = urlString
                node.isTrusted = isTrusted
                node.login = login
                node.password = password
                node.createdAt = Date()
                realm.add(node)
            }
        } catch {
            return false
        }
        return true
    }

    func removeCustomNode(urlString: String) -> Bool {
        guard let realm = getThreadSaveRealm() else { return false }

        do {
            try realm.write {
                let nodes = realm.objects(NodeData.self).filter("urlString == %@", urlString)
                realm.delete(nodes)
            }
        } catch {
            return false
        }
        return true
    }

}
