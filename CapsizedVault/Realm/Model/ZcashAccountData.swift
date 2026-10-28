//
//  ZcashAccountData.swift
//  CapsizedVault
//
//  Metadata for a ZIP-32 account (or imported viewing key) under a Zcash wallet.
//  Added in schema 9 — no rows exist from before this migration.
//

import Foundation
import Realm
import RealmSwift

class ZcashAccountData: Object, Identifiable {

    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var walletId: String = ""
    @Persisted var accountIndex: Int = 0
    /// Display label, set by the user for the wallet's own derived accounts, or carrying
    /// provenance (e.g. "Imported viewing key") for a pasted-in third-party UFVK, so the two
    /// can never be confused in the UI.
    @Persisted var label: String = ""
    @Persisted var isImportedViewingKey: Bool = false
    @Persisted var createdAt: Date = Date()
    /// The SDK's `AccountUUID` raw bytes (added schema 10) — a random identifier, not key
    /// material, kept only so `ZECWallet.activate()` can re-match this row to the right SDK
    /// account on relaunch instead of re-deriving/re-importing it. `nil` for rows written
    /// before schema 10; those get backfilled the first time the wallet activates again.
    @Persisted var accountUUID: Data?

    // No UFVK or other key material here, ever — those are read from the Zcash SDK on
    // demand and never cached or logged. See `NodeData.credentials` for the same pattern
    // applied to node RPC credentials.

}
