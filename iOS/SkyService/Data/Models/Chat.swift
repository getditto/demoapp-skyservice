import DittoSwift
import RxDataSources
import Chatto
import ChattoAdditions


class ChatMessage: MessageModelProtocol, DittoModel {

    static var chatItemType: ChatItemType {
        return "text/plain"
    }

    var senderId: String

    var isIncoming: Bool {
        self.senderId != DataService.shared.userId
    }

    var date: Date

    var status: MessageStatus

    var type: ChatItemType

    var uid: String

    var body: String

    var user: User? = nil

    var workspaceId: String
    
    var deleted: Bool

    required init(document: DittoDocument) {
        self.uid = document.id.toString()
        self.type = document["mimeType"].string ?? Self.chatItemType
        self.status = .success
        self.date = Date(dateString: document["date"].stringValue)
        self.senderId = document["senderUserId"].stringValue
        self.body = document["body"].stringValue
        self.workspaceId = document["workspaceId"].stringValue
        self.deleted = document["deleted"].boolValue

    }

}



