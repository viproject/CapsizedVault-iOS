//
//  WalletsData.swift
//  CapsizedVault
//
//  Created by Dmitrij on 05/12/2025.
//

import Foundation
import RealmSwift

class WalletsData: Object, Identifiable {
    
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var title: String = ""
    @Persisted var walletId: String = ""
    @Persisted var lastUsedAccount: Int = 0
    @Persisted var lastActive: Date
    @Persisted var createdAt: Date
    @Persisted var pendingSeedBackup: Bool = false
    /// Last known total unlocked balance in piconero (sum across all accounts).
    /// -1 means the wallet has never been synced / no cached value yet.
    @Persisted var cachedTotalUnlockedPiconero: Int64 = -1
    
}

