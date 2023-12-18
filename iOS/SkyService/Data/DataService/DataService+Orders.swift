import RxSwift
import DittoSwift

extension DataService {

    func orders(for userId: String? = nil) -> Observable<[Order]> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<[Order]> in
                
                var query = "SELECT * FROM orders WHERE workspaceId = :workspaceId AND deleted = false"
                var args: [String: Any?] = [
                    "workspaceId": workspaceId
                ]
                
                if let userId = userId {
                    query = "SELECT * FROM orders WHERE workspaceId = :workspaceId AND userId = :userId AND deleted = false"
                    args = [
                        "workspaceId": workspaceId,
                        "userId": userId
                    ]
                }
                
                return self.ditto
                    .resultItems$(query: query, args: args)
                    .mapToDittoModel(type: Order.self)
                
            }.map { orders in
                return orders.sorted(by: { $0.createdOn > $1.createdOn })
            }
    }

    func createOrder(for userId: String) -> Observable<Void> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<Void> in
                Task {
                    do {
                        var query = "INSERT INTO orders DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
                        let newDoc: [String:Any] = [
                            "workspaceId": workspaceId,
                            "userId": userId,
                            "createdOn": Date().isoDateString,
                            "total": 0,
                            "status": Order.Status.open.rawValue,
                            "deleted": false
                        ]
                        let resultID = try await self.ditto.store.execute(query: query, arguments: ["newDoc": newDoc]).mutatedDocumentIDs()
                        
                        var usedItems = [[String: Any]]()
                        
                        query = "UPDATE cartLineItems SET orderId = :orderId WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL"
                        
                        let args: [String:Any] = [
                            "orderId": resultID.first as Any,
                            "workspaceId": workspaceId,
                            "userId": userId,
                        ]
                        
                        try await self.ditto.store.execute(query: query, arguments: args)
                        
                        query = "SELECT * FROM cartLineItems WHERE workspaceId = :workspaceId AND userId = :userId AND orderId = :orderId"
                        let results = try await self.ditto.store.execute(query: query, arguments: args).items
                        
                        for result in results {
                            if let menuItemId = result.value["menuItemId"] as? String,
                               let quantity = result.value["quantity"] as? Double {
                                usedItems.append(["menuItemId": menuItemId, "quantity": quantity])
                            }
                        }
                        
                        //Coounters not yet supported in DQL
                        usedItems.forEach { used in
                            let id = used["menuItemId"] as! String
                            let quantity = used["quantity"] as! Double
                            self.ditto.store["menuItems"].findByID(id).update { mutableDoc in
                                let usedCount = mutableDoc?["usedCount"].int
                                
                                if usedCount == nil {
                                    mutableDoc?["usedCount"].set(DittoCounter())
                                    mutableDoc?["usedCount"].counter?.increment(by: quantity)
                                } else {
                                    mutableDoc?["usedCount"].counter?.increment(by: quantity)
                                }
                            }
                        }
                        
                    } catch {
                        print("Error \(error)")
                    }
                }
                
                return Observable.just(())
            }
    }

    func updateCrewNote(order: Order, newNote: String) async {
        do {
            
            let query = "UPDATE orders SET crewNote = :crewNote WHERE _id = :id"
            
            let args: [String:Any] = [
                "crewNote": newNote,
                "id": order.id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
        
        
    }
}
