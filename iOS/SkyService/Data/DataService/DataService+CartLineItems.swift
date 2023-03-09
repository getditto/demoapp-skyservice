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
                    query = "workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == '\(orderId)' deleted == false"
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
        self.ditto.store.write { (trx) in
            if let cartLineItemId = cartLineItemId {
                trx["cartLineItems"].findByID(cartLineItemId).update { (doc) in
                    guard let doc = doc else { return }
                    doc["quantity"].set(quantity)
                    doc["options"].set(DittoRegister(value: options))
                    doc["menuItemId"].set(menuItemId)
                    doc["userId"].set(userId)
                    doc["workspaceId"].set(workspaceId)
                }
            } else {
                try! trx["cartLineItems"].upsert([
                    "quantity": quantity,
                    "options": options,
                    "menuItemId": menuItemId,
                    "userId": userId,
                    "workspaceId": workspaceId,
                    "orderId": nil,
                    "deleted": false
                ])
            }
        }
        return Observable.just(Void())
    }

    func clearCartLineItems(for userId: String, with orderId: String? = nil) -> Observable<Void> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<Void> in

                var query = "workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == null"
                if let orderId = orderId {
                    query = "workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == '\(orderId)'"
                }
                                
                let cartLineItemsDocs = self.ditto.store["cartLineItems"].find(query).exec()
                for doc in cartLineItemsDocs {
                    self.ditto.store["cartLineItems"].findByID(doc.id).update { (mutable) in
                        guard let mutable = mutable else { return }
                        mutable["deleted"].set(true)
                    }
                }
                
                
                return Observable.just(())
            }
    }

    func removeCartLineItem(id: String) -> Observable<Void> {
        self.ditto.store["cartLineItems"].findByID(id).update { (mutable) in
            guard let mutable = mutable else { return }
            mutable["deleted"].set(true)
        }
        return Observable.just(())
    }

    func changeOrderStatus(orderId: String, status: Order.Status) {
        self.orders.findByID(orderId).update { (m) in
            m?["status"].set(status.rawValue)
        }
    }

    func deleteOrder(orderId: String) {
        self.orders.findByID(orderId).update { (mutable) in
            guard let mutable = mutable else { return }
            mutable["deleted"].set(true)
        }
    }

}
