import RxSwift
import DittoSwift

extension DataService {

    func menuItemById$(_ id: String) -> Observable<MenuItem?> {
        return menuItems.findByID(id).document$()
            .map { (doc) -> MenuItem? in
                if let doc = doc {
                    return MenuItem(document: doc)
                }
                return nil
            }
    }

    func menuItems$() -> Observable<[MenuItem]> {
        //Counter type not supported in DQL
        return workspaceId$
            .flatMapLatest { [unowned menuItems = self.menuItems] (workspaceId) -> Observable<[MenuItem]> in
                return menuItems
                    .find("workspaceId == '\(workspaceId)' && deleted == false")
                    .documents$()
                    .mapToDittoModel(type: MenuItem.self)
            }
    }

    func createMenuItem(name: String, price: Float, details: String, categoryId: String? = nil, maxCartQuantityPerUser: Int? = nil) -> Observable<String> {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to find a workspaceId while attempting to save a menuItem `saveMenuItem`")
            return Observable.empty()
        }

        return Observable.create { observer in
            Task {
                do {
                    let query = "INSERT INTO menuItems DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
                    
                    let newDoc: [String:Any?] = [
                        "name": name,
                        "price": price,
                        "details": details,
                        "workspaceId": workspaceId,
                        "createdOn": Date().isoDateString,
                        "categoryId": categoryId,
                        "ordinal": Float.random(min: 0, max: 1),
                        "maxCartQuantityPerUser": maxCartQuantityPerUser,
                        "deleted": false
                    ]
                    
                    let result = try await self.ditto.store.execute(query: query, arguments: ["newDoc": newDoc]).mutatedDocumentIDs().first?.toString() ?? ""

                    DispatchQueue.main.async {
                        observer.onNext(result)
                        observer.onCompleted()
                    }
                } catch {
                    print("Error \(error)")

                    DispatchQueue.main.async {
                        observer.onError(error)
                    }
                }
            }

            return Disposables.create()
        }
        
    }

    func saveMenuItem(id: String, name: String, price: Float, details: String, categoryId: String? = nil, maxCartQuantityPerUser: Int? = nil) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to find a workspaceId while attempting to save a menuItem `saveMenuItem`")
            return
        }
        
        do {
            let query = "UPDATE menuItems SET name = :name, price = :price, details = :details, workspaceId = :workspaceId, categoryId = :categoryId, maxCartQuantityPerUser = :maxCartQuantityPerUser WHERE _id = :id"
            
            let args: [String:Any] = [
                "name": name,
                "id": id,
                "price": price,
                "details": details,
                "workspaceId": workspaceId,
                "categoryId": categoryId as Any,
                "maxCartQuantityPerUser": maxCartQuantityPerUser as Any,
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    func updateMenuItemOrdinal(id: String, newOrdinal: Float, categoryId: String?) async {
        do {
            let query = "UPDATE menuItems SET ordinal = :ordinal, categoryId = :categoryId WHERE _id = :id"
            
            let args: [String:Any] = [
                "ordinal": newOrdinal,
                "categoryId": categoryId as Any,
                "id": id,
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    func changeIsCrewOnly(menuItemId: String, isCrewOnly: Bool) async {
        do{
            let query = "UPDATE menuItems SET isCrewOnly = :isCrewOnly WHERE _id = :id"
            
            let args: [String:Any] = [
                "isCrewOnly": isCrewOnly,
                "id": menuItemId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    func getIsCrewOnly(menuItemId: String) async -> Bool {
        do {
            
            let query = "SELECT * FROM menuItems WHERE _id = :id"
            
            let result = try await self.ditto.store.execute(query: query, arguments: ["id": menuItemId]).items
            
            return result.first?.value["isCrewOnly"] as? Bool ?? false

        } catch {
            print("Error \(error)")
            return false
        }
    }
}
