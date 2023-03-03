import RxSwift
import DittoSwift

extension DataService {

    func chatMessages$() -> Observable<[ChatMessage]> {
        return workspaceId$
            .flatMapLatest { [unowned chatMessages = self.chatMessages, users = self.users] (workspaceId) -> Observable<[ChatMessage]> in
                let chatMessages: Observable<[ChatMessage]> = chatMessages
                    .find("workspaceId == '\(workspaceId)'")
                    .sort("createdOn", direction: .ascending)
                    .documents$()
                    .mapToDittoModel(type: ChatMessage.self)

                let users: Observable<[User]> = users
                    .find("workspaceId == '\(workspaceId)'")
                    .documents$()
                    .mapToDittoModel(type: User.self)

                return Observable.combineLatest(chatMessages, users) { (chatMessages, users) in
                    for c in chatMessages {
                        c.user = users.first(where: { $0.id == c.senderId })
                    }
                    return chatMessages
                }
            }
    }

    func sendChatMessage(body: String){
        guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
        try! chatMessages.upsert([
            "mimeType": "text/plain",
            "body": body,
            "workspaceId": workspaceId,
            "senderUserId": self.userId,
            "createdOn": Date().isoDateString
        ])
    }

    func deleteAllChatMessages() {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `deleteAllChatMessages`")
            return
        }
        chatMessages.find("workspaceId == '\(workspaceId)'").remove()
    }

}
