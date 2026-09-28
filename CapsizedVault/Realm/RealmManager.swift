//
//  RealmManager.swift
//  CapsizedVault
//
//  Created by Dmitrij on 05/12/2025.
//

import Foundation
import Realm
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
        config.schemaVersion = 8
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 7 {
                // Realm zero-fills new Int64 fields; explicitly set -1 (= "never synced")
                // so the wallet list shows "–" instead of 0.0000 XMR for unsynced wallets.
                migration.enumerateObjects(ofType: "WalletsData") { _, newObject in
                    newObject?["cachedTotalUnlockedPiconero"] = Int64(-1)
                }
            }
            // Schema 8 drops NodeData.login/password (moved to Keychain, see KeychainHelper).
            // No known installs have saved custom node credentials yet, so nothing to carry
            // over — Realm removes the two columns on its own.
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

        var nodeId: String?
        do {
            try realm.write {
                let node = NodeData()
                node.urlString = urlString
                node.isTrusted = isTrusted
                node.createdAt = Date()
                realm.add(node)
                nodeId = node._id.stringValue
            }
        } catch {
            return false
        }

        if let nodeId {
            KeychainHelper.saveNodeCredentials(login: login, password: password, for: nodeId)
        }
        return true
    }

    func updateCustomNode(oldURLString: String, newURLString: String, isTrusted: Bool, login: String, password: String) -> Bool {
        guard let realm = getThreadSaveRealm() else { return false }

        if newURLString != oldURLString {
            let collides = realm.objects(NodeData.self).filter("urlString == %@", newURLString).first != nil
            if collides { return false }
        }

        var nodeId: String?
        do {
            try realm.write {
                if let node = realm.objects(NodeData.self).filter("urlString == %@", oldURLString).first {
                    node.urlString = newURLString
                    node.isTrusted = isTrusted
                    nodeId = node._id.stringValue
                }
            }
        } catch {
            return false
        }

        if let nodeId {
            KeychainHelper.saveNodeCredentials(login: login, password: password, for: nodeId)
        }
        return true
    }

    func removeCustomNode(urlString: String) -> Bool {
        guard let realm = getThreadSaveRealm() else { return false }

        let nodeIds = realm.objects(NodeData.self).filter("urlString == %@", urlString).map { $0._id.stringValue }

        do {
            try realm.write {
                let nodes = realm.objects(NodeData.self).filter("urlString == %@", urlString)
                realm.delete(nodes)
            }
        } catch {
            return false
        }

        for nodeId in nodeIds {
            KeychainHelper.deleteNodeCredentials(for: nodeId)
        }
        return true
    }

}
