import Foundation
import Realm
import RealmSwift

class NodeData: Object, Identifiable {

    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var urlString: String = ""
    @Persisted var isTrusted: Bool = false
    @Persisted var createdAt: Date

    /// RPC login/password are kept out of Realm and read from the Keychain on demand,
    /// keyed by `_id` (stable across URL edits). See `KeychainHelper.nodeCredentials`.
    var credentials: (login: String, password: String) {
        KeychainHelper.nodeCredentials(for: _id.stringValue)
    }

}
