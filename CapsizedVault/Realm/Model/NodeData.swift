import Foundation
import RealmSwift

class NodeData: Object, Identifiable {

    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var urlString: String = ""
    @Persisted var isTrusted: Bool = false
    @Persisted var login: String = ""
    @Persisted var password: String = ""
    @Persisted var createdAt: Date

}
