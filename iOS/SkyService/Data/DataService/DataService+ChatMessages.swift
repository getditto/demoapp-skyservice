import RxSwift
import DittoSwift

extension DataService {

    func chatMessages$() -> Observable<[ChatMessage]> {
        return workspaceId$
            .flatMapLatest { [unowned chatMessages = self.chatMessages, users = self.users] (workspaceId) -> Observable<[ChatMessage]> in
                
                var query = "SELECT * FROM chatMessages WHERE workspaceId = :workspaceId AND deleted = false ORDER BY createdOn ASC"
                var args: [String:Any?] = [
                    "workspaceId": workspaceId,
                ]
                
               let chatMessages: Observable<[ChatMessage]> = self.ditto
                    .resultItems$(query: query, args: args)
                    .mapToDittoModel(type: ChatMessage.self)
                
                query = "SELECT * FROM users WHERE workspaceId = :workspaceId"
                args = [
                    "workspaceId": workspaceId,
                ]
                
               let users: Observable<[User]> = self.ditto
                    .resultItems$(query: query, args: args)
                    .mapToDittoModel(type: User.self)

                return Observable.combineLatest(chatMessages, users) { (chatMessages, users) in
                    for c in chatMessages {
                        c.user = users.first(where: { $0.id == c.senderId })
                    }
                    return chatMessages
                }
            }
    }

    func sendChatMessage(body: String) async{
        guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
        
        do {
            
            let newDoc: [String:Any] = [
                "mimeType": "text/plain",
                "body": body,
                "workspaceId": workspaceId,
                "senderUserId": self.userId,
                "createdOn": Date().isoDateString,
                "deleted": false
            ]
                    
            try await self.ditto.store.execute(query: "INSERT INTO chatMessages DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
            
        } catch {
            print("Error \(error)")
        }
    }

    func deleteAllChatMessages() async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `deleteAllChatMessages`")
            return
        }
        
        do {
            let chatResults = try await ditto.store.execute(query: "SELECT * FROM chatMessages WHERE workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items
            
            for result in chatResults {
                try await self.ditto.store.execute(query: "UPDATE chatMessages SET deleted = :deleted WHERE _id = :id", arguments: ["deleted": true, "id": result.value["_id"] as Any?])
            }
            
        } catch {
            print("Error \(error)")
        }
    }

}
