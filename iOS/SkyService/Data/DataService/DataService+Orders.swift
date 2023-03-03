import RxSwift
import DittoSwift

extension DataService {

    func orders(for userId: String? = nil) -> Observable<[Order]> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<[Order]> in
                var query = "workspaceId == '\(workspaceId)'"
                if let userId = userId {
                    // provided a userId, so we want a more specific set
                    query = "workspaceId == '\(workspaceId)' && userId == '\(userId)'"
                }
                return self.orders.find(query).documents$().mapToDittoModel(type: Order.self)
            }.map { orders in
                return orders.sorted(by: { $0.createdOn > $1.createdOn })
            }
    }

    func createOrder(for userId: String) -> Observable<Void> {
        return self.workspaceId$
            .flatMapLatest { workspaceId -> Observable<Void> in
                // get the current cart line items synchronously from the store
                self.ditto.store.write { txn in
                    let insertedOrderId = try! txn["orders"].upsert([
                        "workspaceId": workspaceId,
                        "userId": userId,
                        "createdOn": Date().isoDateString,
                        "total": 0,
                        "status": Order.Status.open.rawValue,
                    ])
                    var usedItems = [[String: Any]]()
                    txn["cartLineItems"].find("workspaceId == '\(workspaceId)' && userId == '\(userId)' && orderId == null").update { mutableDocs in
                        mutableDocs.forEach { mutableDoc in
                            mutableDoc["orderId"].set(insertedOrderId)

                            usedItems.append(
                                ["menuItemId": mutableDoc["menuItemId"].stringValue,
                                 "quantity": mutableDoc["quantity"].doubleValue])
                        }

                    }
                    usedItems.forEach { used in
                        let id = used["menuItemId"] as! String
                        let quantity = used["quantity"] as! Double
                        txn["menuItems"].findByID(id).update { mutableDoc in
                            let usedCount = mutableDoc?["usedCount"].int
                            
                            if usedCount == nil {
                                mutableDoc?["usedCount"].set(DittoCounter())
                                mutableDoc?["usedCount"].counter?.increment(by: quantity)
                            } else {
                                mutableDoc?["usedCount"].counter?.increment(by: quantity)
                            }
                        }
                    }
                }
                return Observable.just(())
            }
    }

    func updateCrewNote(order: Order, newNote: String) {
        orders.findByID(order.id).update { m in
            m?["crewNote"].set(newNote)
        }
    }
}
