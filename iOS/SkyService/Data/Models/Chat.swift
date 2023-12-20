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
    
    required init(resultItem: [String:Any?]) {
        self.uid = resultItem["_id"] as! String
        self.type = resultItem["type"] as? String ?? Self.chatItemType
        self.status = .success
        self.date = Date(dateString: resultItem["date"] as? String ?? "")
        self.senderId = resultItem["senderId"] as? String ?? ""
        self.body = resultItem["body"] as? String ?? ""
        self.workspaceId = resultItem["workspaceId"] as? String ?? ""
        self.deleted = resultItem["deleted"] as? Bool ?? false
    }

}



