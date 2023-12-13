import RxSwift
import DittoSwift

extension DataService {

    func canOrder$() -> Observable<Bool> {
        return workspaceId$
            .flatMapLatest { [weak self] workspaceId -> Observable<Bool> in
                guard let `self` = self else { return Observable.just(false) }
                return self.ditto.store["workspaces"].findByID(workspaceId).document$()
                    .map({ doc in
                        guard let doc = doc else { return true }
                        return doc["isOrderingEnabled"].bool ?? true
                    })
            }
    }

    func welcomeMessage$() -> Observable<String> {
        let defaultMessage = "Welcome to SkyService!"
        return workspaceId$
            .flatMapLatest { [weak self] workspaceId -> Observable<String> in
                guard let self = self else { return Observable.just("") }
                return self.ditto.store["workspaces"].findByID(workspaceId).document$()
                    .map({ doc in
                        return doc?["welcomeMessage"].string ?? defaultMessage
                    })
            }
    }

    func updateWelcomeMessage(_ message: String) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }
        
        do {
            let query = "UPDATE workspaces SET welcomeMessage = :welcomeMessage WHERE _id = :id"
            
            let args: [String:Any] = [
                "welcomeMessage": message,
                "id": workspaceId
            ]
            
            try await ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    func setEnableOrdering(isOrderingEnabled: Bool) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }
        
        do {
            
            if (try await ditto.store.execute(query: "SELECT * FROM workspaces WHERE workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items.isNotEmpty) {
                
                let query = "UPDATE workspaces SET isOrderingEnabled = :isOrderingEnabled WHERE _id = :id"
                
                let args: [String:Any] = [
                    "isOrderingEnabled": isOrderingEnabled,
                    "id": workspaceId
                ]
                
                try await self.ditto.store.execute(query: query, arguments: args)
            } else {
                
                let newDoc: [String:Any] = [
                    "_id": workspaceId.toDittoID(),
                    "isOrderingEnabled": isOrderingEnabled
                ]
                        
                try await self.ditto.store.execute(query: "INSERT INTO workspaces DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
            }

        } catch {
            print("Error \(error)")
        }
    }

}
