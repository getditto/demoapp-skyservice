import Foundation
import DittoSwift

struct Note: DittoModel, Ordinal {

    var id: String
    var userId: String
    var workspaceId: String
    var body: String
    var createdOn: Date
    var editedOn: Date?
    var ordinal: Float
    var isCompleted: Bool
    var isShared: Bool
    var deleted: Bool

    var user: User?

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.userId = document["userId"].stringValue
        self.workspaceId = document["workspaceId"].stringValue
        self.body = document["body"].stringValue
        self.createdOn = Date(dateString: document["createdOn"].stringValue)
        self.isCompleted = document["isCompleted"].boolValue
        self.editedOn = {
            guard let s = document["editedOn"].string else { return nil }
            return Date(dateString: s)
        }()
        self.ordinal = document["ordinal"].floatValue
        self.isShared = document["isShared"].boolValue
        self.deleted = document["deleted"].boolValue

    }
}
