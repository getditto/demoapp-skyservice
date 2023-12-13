import Foundation
import RxSwift
import DittoSwift

extension DataService {

    /**
     These are all the cart line items for the user
     */
    func cartLineItems(for userId: String, with orderId: String? = nil) -> Observable<[CartLineItem]> {
        return self.workspaceId$
            .flatMapLatest { [weak self] (workspaceId) -> Observable<[CartLineItem]> in
                guard let `self` = self else { return Observable.empty() }

                var query = "workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == null && deleted == false"
                if let orderId = orderId {
                    query = "workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == '\(orderId)' && deleted == false"
                }

                return self.ditto.store["cartLineItems"]
                    .find(query)
                    .documents$().mapToDittoModel(type: CartLineItem.self)
            }
    }

    func cartLineItems(for orderIds: [String]) -> Observable<[CartLineItem]> {
        return self.workspaceId$
            .flatMapLatest { [weak self] (workspaceId) -> Observable<[CartLineItem]> in
                guard let `self` = self else { return Observable.empty() }
                let containsPredicate: String = orderIds.map{ "'\($0)'" }.joined(separator: ",")
                let query = "workspaceId == '\(workspaceId)' && contains([\(containsPredicate)], orderId) && deleted == false"
                return self.ditto.store["cartLineItems"]
                    .find(query)
                    .documents$().mapToDittoModel(type: CartLineItem.self)
            }
    }


    /**
     This will attempt to update or insert a new cartLineItemId for the `cartLineItemId`
     if the `cartLineItemId` parameter is nil, then it will insert.
     */
    func setCartLineItem(cartLineItemId: String? = nil, userId: String, menuItemId: String, quantity: Int, options: [String]) -> Observable<Void> {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return Observable.empty() }
        
        Task {
            do {
                
                if let cartLineItemId = cartLineItemId {
                    
                    let query = "UPDATE cartLineItems SET quantity = :quantity, options = :options, menuItemId = :menuItemId, userId = :userId, workspaceId = :workspaceId WHERE _id = :id"
                    
                    let args: [String:Any] = [
                        "quantity": quantity,
                        "options": options,
                        "menuItemId": menuItemId,
                        "userId": userId,
                        "workspaceId": workspaceId,
                        "id": cartLineItemId as Any
                    ]
                    
                    try await self.ditto.store.execute(query: query, arguments: args)
                } else {
                    
                    let query = "INSERT INTO cartLineItems DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
                    
                    let newDoc: [String:Any?] = [
                        "quantity": quantity,
                        "options": options,
                        "menuItemId": menuItemId,
                        "userId": userId,
                        "workspaceId": workspaceId,
                        "orderId": nil,
                        "deleted": false
                    ]
                    
                    try await self.ditto.store.execute(query: query, arguments: ["newDoc": newDoc])
                }
                
            } catch {
                print("Error \(error)")
            }
        }

        return Observable.just(Void())
    }

    func clearCartLineItems(for userId: String, with orderId: String? = nil) -> Observable<Void> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<Void> in
                Task {
                    do {
                        
                        var query = "SELECT * FROM cartLineItems WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL"
                        
                        var args: [String: Any?] = [
                            "workspaceId": workspaceId,
                            "userId": userId,
                        ]
                        
                        if let orderId = orderId {
                            query = "SELECT * FROM cartLineItems WHERE workspaceId = :workspaceId AND userId = :userId AND orderId = :orderId"

                            args = [
                                "workspaceId": workspaceId,
                                "userId": userId,
                                "orderId": orderId
                            ]
                        }
                        
                        let cartLineItemsDocs = try await self.ditto.store.execute(query: query, arguments: args).items
                        
                        for result in cartLineItemsDocs {
                            let query = "UPDATE cartLineItems SET deleted = :deleted WHERE _id = :id"
                            
                            let args: [String:Any] = [
                                "deleted": true,
                                "id": result.value["_id"] as Any
                            ]
                            
                            try await self.ditto.store.execute(query: query, arguments: args)
                        }
                        
                    } catch {
                        print("Error \(error)")
                    }
                }
                
                return Observable.just(())
            }
    }

    func removeCartLineItem(id: String) -> Observable<Void> {

        Task {
            do {
                
                let query = "UPDATE cartLineItems SET deleted = :deleted WHERE _id = :id"
                
                let args: [String:Any] = [
                    "deleted": true,
                    "id": id
                ]
                
                try await self.ditto.store.execute(query: query, arguments: args)
                
            } catch {
                print("Error \(error)")
            }
        }

        return Observable.just(())
    }

    func changeOrderStatus(orderId: String, status: Order.Status) async {
        
        do {
            
            let query = "UPDATE orders SET status = :status WHERE _id = :id"
            
            let args: [String:Any] = [
                "status": status.rawValue,
                "id": orderId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    func deleteOrder(orderId: String) async {
        do {
            
            let query = "UPDATE orders SET deleted = :deleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "deleted": true,
                "id": orderId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

}
