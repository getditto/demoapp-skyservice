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
        let insertedId: DittoDocumentID = try! menuItems.upsert([
            "name": name,
            "price": price,
            "details": details,
            "workspaceId": workspaceId,
            "createdOn": Date().isoDateString,
            "categoryId": categoryId,
            "ordinal": Float.random(min: 0, max: 1),
            "maxCartQuantityPerUser": maxCartQuantityPerUser,
            "totalCount": nil,
            "usedCount": nil,
            "deleted": false
        ])
        return Observable.just(insertedId.toString())
    }

    func saveMenuItem(id: String, name: String, price: Float, details: String, categoryId: String? = nil, maxCartQuantityPerUser: Int? = nil) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to find a workspaceId while attempting to save a menuItem `saveMenuItem`")
            return
        }
        menuItems.findByID(id).update({ (doc) in
            doc?["name"].set(name)
            doc?["price"].set(price)
            doc?["details"].set(details)
            doc?["workspaceId"].set(workspaceId)
            doc?["categoryId"].set(categoryId)
            doc?["maxCartQuantityPerUser"].set(maxCartQuantityPerUser)
        })
    }

    func updateMenuItemOrdinal(id: String, newOrdinal: Float, categoryId: String?) {
        menuItems.findByID(id).update({ (doc) in
            doc?["ordinal"].set(newOrdinal)
            doc?["categoryId"].set(categoryId)
        })
    }

    func updateMenuItemTotalCount(id: String, value: Double) {
        if let item = menuItems.findByID(id).exec() {
            if let current = item["totalCount"].double {
                menuItems.findByID(id).update { mutable in
                    guard let mutable = mutable else { return }
                    mutable["totalCount"].counter?.increment(by: value - current)
                }
            } else {
                menuItems.findByID(id).update { mutable in
                    guard let mutable = mutable else { return }
                    mutable["totalCount"].set(DittoCounter())
                    mutable["totalCount"].counter?.increment(by: value)
                }
            }
        }
    }

    func changeIsCrewOnly(menuItemId: String, isCrewOnly: Bool) {
        menuItems.findByID(menuItemId).update { m in
            m?["isCrewOnly"].set(isCrewOnly)
        }
    }

    func getIsCrewOnly(menuItemId: String) -> Bool {
        let doc = menuItems.findByID(menuItemId).exec()
        return doc?["isCrewOnly"].bool ?? false
    }
}
