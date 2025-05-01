import UIKit
import DittoSwift
import RxSwift
import RxOptional

final class AuthDelegate: DittoAuthenticationDelegate {
    func authenticationRequired(authenticator: DittoAuthenticator) {
        authenticator.login(token: Env.DITTO_AUTH_PASSWORD, provider: Env.DITTO_AUTH_PROVIDER)  { _, err in
            print("Login request completed. Error? \(String(describing: err))")
        }
    }

    func authenticationExpiringSoon(authenticator: DittoAuthenticator, secondsRemaining: Int64) {
        authenticator.login(token: Env.DITTO_AUTH_PASSWORD, provider: Env.DITTO_AUTH_PROVIDER)  { _, err in
            print("Login request completed. Error? \(String(describing: err))")
        }
    }
}

final class DataService {

    private(set) var ditto: Ditto!

    private(set) var menuItems: DittoCollection
    private(set) var orders: DittoCollection
    private(set) var users: DittoCollection
    private(set) var chatMessages: DittoCollection
    private(set) var categories: DittoCollection
    private(set) var notes: DittoCollection
    private(set) var authDelegate: AuthDelegate

    static var shared = DataService()
    
    private var seenOrders = [DittoQueryResultItem]()
    private var seenChats_crew = [DittoQueryResultItem]()

    let workspaceId$: Observable<String> = UserDefaults.standard.rx.observe(String.self, "workspaceId")
        .filterNil()
        .distinctUntilChanged()

    private var expansionSet$ = BehaviorSubject<Set<String>>(value: Set())

    private var disposeBag = DisposeBag()

    var userId: String {
        return "\(ditto.siteID)"
    }

    private init() {
        DittoLogger.minimumLogLevel = DittoLogLevel.debug

        self.authDelegate = AuthDelegate()
        ditto = Ditto(identity: .onlineWithAuthentication(appID: Env.DITTO_APP_ID, authenticationDelegate: authDelegate))

        // Sync Small Peer Info to Big Peer
        ditto.smallPeerInfo.isEnabled = true
        ditto.smallPeerInfo.syncScope = .bigPeerOnly

        do {
            try ditto.disableSyncWithV3()
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
        menuItems = ditto.store["menuItems"]
        users = ditto.store["users"]
        orders = ditto.store["orders"]
        chatMessages = ditto.store["chatMessages"]
        categories = ditto.store["categories"]
        notes = ditto.store["notes"]
        
    }
    
    func populateSeenItems(workspaceId: String) {
        // initialze seen arrays with data that came through before app start up
        // Makes it so app does not get bombarded with notifications for every previous order
        Task {
            do {
                self.seenOrders = try await self.ditto.store.execute(query: "SELECT * FROM orders WHERE deleted = false AND workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items
                
                self.seenChats_crew = try await self.ditto.store.execute(query: "SELECT * FROM chatMessages WHERE deleted = false AND workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items
            } catch {
                print("Error \(error)")
            }
        }
    }

    func startSyncing() {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to get a workspaceId in `startSyncing`")
            return
        }

        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                print("Local notification permissions granted.")
            } else {
                print("Local notification permissions error or not granted.")
            }
        }
        do {
            try ditto.startSync()
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
        self.populateSeenItems(workspaceId: workspaceId)

        // i had no way to stop a subscription
        [
            menuItems,
            users,
            orders,
            chatMessages,
            categories,
            notes
        ].forEach { (collection) in
            let query = "SELECT * FROM \(collection.name) WHERE workspaceId = :workspaceId"
            let args: [String: Any?] = [
                "workspaceId": workspaceId
            ]
            
            self.ditto
                .resultItems$(query: query, args: args)
                .subscribeNext({ _ in })
                .disposed(by: disposeBag)
        }
        
        let query = "SELECT * FROM workspaces WHERE _id = :id"
        let args: [String: Any?] = [
            "id": workspaceId
        ]
        
        self.ditto
            .resultItems$(query: query, args: args)
            .bind { _ in }
            .disposed(by: disposeBag)

        // registering background notifications

        self.ditto
            .resultItems$(query: "SELECT * FROM orders WHERE workspaceId = :workspaceId AND deleted = false", args: ["workspaceId": workspaceId])
            .filter { _ in !Bundle.main.isCrew } // pax app only
            .flatMapLatest { resultItems -> Observable<Order> in
                var updatedOrders = [Order]()
                resultItems.forEach { item in
                    guard let itemId = item.value["_id"] as? String else {
                        return // Skip items without a valid "_id"
                    }
                    
                    let prevStatus = self.seenOrders.compactMap { seenItem in
                        if (seenItem.value["_id"] as? String) == itemId {
                            return seenItem.value["status"] as? Int
                        }
                        return nil
                    }.first
                    
                    let newStatus = item.value["status"] as? Int
                    
                    if !(prevStatus == newStatus) {
                        updatedOrders.append(Order(resultItem: item.value))
                    }
                }
                return Observable.from(updatedOrders)
            }
            .bind { (updatedOrder) in
                let content = UNMutableNotificationContent()
                content.title = "Order Status Update"
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "order_changed.wav"))
                content.body = self.getStatusUpdateText(status: updatedOrder.status.humanReadable)
                content.sound =  UNNotificationSound.default
                content.userInfo = [
                    "notificationType": "orderStatusChanged"
                ]
                let req = UNNotificationRequest.init(identifier: "orders", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
            .disposed(by: disposeBag)
        
        self.ditto
            .resultItems$(query: "SELECT * FROM orders WHERE workspaceId = :workspaceId AND deleted = false", args: ["workspaceId": workspaceId])
            .filter { _ in Bundle.main.isCrew } // only crew should see this
            .flatMapLatest { resultItems -> Observable<DittoQueryResultItem> in
                let insertedItems = resultItems.filter { item in
                    guard let itemId = item.value["_id"] as? String else {
                        return false // Skip items without a valid "_id"
                    }
                    let isItemAlreadySeen = self.seenOrders.contains { seenItem in
                        return (seenItem.value["_id"] as? String) == itemId
                    }
                    if !isItemAlreadySeen {
                        self.seenOrders.append(item)
                        return true
                    }
                    return false
                }
                return Observable.from(insertedItems)
            }
            .bind { insertedDoc in
                let content = UNMutableNotificationContent()
                content.title = "Meal Order"
                content.body = "A new order has been received"
                content.userInfo = [
                    "notificationType": "receivedNewOrder"
                ]
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "new_order.wav"))
                let req = UNNotificationRequest.init(identifier: "orders", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
            .disposed(by: disposeBag)
        
        self.ditto
            .resultItems$(query: "SELECT * FROM chatMessages WHERE workspaceId = :workspaceId AND deleted = false", args: ["workspaceId": workspaceId])
            .filter { _ in Bundle.main.isCrew } // notify only crew
            .filter { _ in UIApplication.shared.applicationState == .background } // notify only in background
            .flatMapLatest { resultItems -> Observable<DittoQueryResultItem> in
                let insertedItems = resultItems.filter { item in
                    guard let itemId = item.value["_id"] as? String else {
                        return false // Skip items without a valid "_id"
                    }
                    let isItemAlreadySeen = self.seenChats_crew.contains { seenItem in
                        return (seenItem.value["_id"] as? String) == itemId
                    }
                    if !isItemAlreadySeen {
                        self.seenChats_crew.append(item)
                        return true
                    }
                    return false
                }
                return Observable.from(insertedItems)
            }
            .bind { (insertedChatMessage) in
                let content = UNMutableNotificationContent()
                content.title = "New Message"
                content.body = insertedChatMessage.value["body"] as? String ?? ""
                content.userInfo = [
                    "notificationType": "newChatMessage"
                ]
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "chat_notification.wav"))
                let req = UNNotificationRequest.init(identifier: "chatMessages", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
            .disposed(by: disposeBag)
     
    }
    
    private func getStatusUpdateText (status: String) -> String {
        switch status {
        case "order placed":
            return "Your order has been placed"
        case "preparing":
            return "Your order is being prepared"
        case "order delivered":
            return "Your order has been delivered"
        default:
            return "Your order has been cancelled"
        }
    }

    func stopSyncing() {
        disposeBag = DisposeBag()
    }

    deinit {
        disposeBag = DisposeBag()
    }

    func menuItemsAndAllCategories(userId: String? = nil) -> Observable<(sectionOfMenuItems: [SectionOfMenuItems], allCategories:[Category], canOrder: Bool)> {
        
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to find a workspaceId while attempting to save a menuItem `menuItemsAndAllCategories`")
            return Observable.empty()
        }
        
        let query = "SELECT * FROM menuItems WHERE workspaceId = :workspaceId AND deleted = false"
        let args: [String: Any?] = [
            "workspaceId": workspaceId
        ]
        
        let justMenuItems$ = self.ditto
            .resultItems$(query: query, args: args)
            .map { (docs) -> [MenuItem] in
                return docs.map({ MenuItem(resultItem: $0.value) })
            }

        let cartItems$: Observable<[String: Int]> = {
            if let userId = userId {
                return UserDefaults.standard.rx.observe([String: Int].self, "cartItems:\(userId)")
                    .map({ $0 ?? [:] })
            } else {
                return Observable.just([:])
            }
        }()

        let categories$ = self.categories$()

        return Observable.combineLatest(justMenuItems$, cartItems$, expansionSet$, categories$, self.canOrder$()) { menuItems, cartItems, expansionSet, categories, canOrder in
            var sectionOfMenuItems = [SectionOfMenuItems]()
            for category in categories.sorted(by: { $0.ordinal < $1.ordinal }) {
                let menuItems = menuItems.filter({ $0.categoryId == category.id })
                    .sorted(by: { $0.ordinal < $1.ordinal })
                sectionOfMenuItems.append(SectionOfMenuItems(items: menuItems, category: category))
            }
            let uncatMenuItems = menuItems.filter({ $0.categoryId == nil })
                .sorted(by: { $0.ordinal < $1.ordinal })
            if !uncatMenuItems.isEmpty {
                sectionOfMenuItems.append(SectionOfMenuItems(items: uncatMenuItems, category: nil))
            }

            return (sectionOfMenuItems: sectionOfMenuItems, allCategories: categories, canOrder: canOrder)
        }
    }

    func deleteMenuItem(id: String) async {
        do {
            let query = "UPDATE menuItems SET deleted = :deleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "deleted": true,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
                        
        } catch {
            print("Error: \(error)")
        }
    }

    func setCartItem(forUserId: String, menuItemId: String, quantity: Int = 1) {
        var dict: [String: Int]! = UserDefaults.standard.dictionary(forKey: "cartItems:\(forUserId)") as? [String: Int]
        if dict == nil {
            UserDefaults.standard.setValue([String: Int](), forKey: "cartItems:\(forUserId)")
            dict = [:]
        }
        if quantity == 0 {
            dict.removeValue(forKey: menuItemId)
        } else {
            dict[menuItemId] = quantity
        }
        UserDefaults.standard.setValue(dict, forKey: "cartItems:\(forUserId)")
    }

    func clearCart(forUserId: String) {
        UserDefaults.standard.setValue([:], forKey: "cartItems:\(forUserId)")
    }

    func quantityForCartItem(forUserId: String, _ menuItemId: String) -> Int? {
        let dict = UserDefaults.standard.dictionary(forKey: "cartItems:\(forUserId)") as? [String: [String: Any]] ?? [:]
        guard let val = dict[menuItemId] else {
            return nil
        }
        return val["quantity"] as? Int
    }


    func userById(_ id: String) -> Observable<User?> {
        let query = "SELECT * FROM users WHERE _id = :id"
        let args: [String: Any?] = [
            "id": id
        ]
        
        return self.ditto
            .resultItems$(query: query, args: args)
            .map({ item in
                if let doc = item.first {
                    return User(resultItem: doc.value)
                } else {
                    return nil
                }
            })
    }

    func deleteUser(userId: String) async {
        do {
            let query = "UPDATE users SET deleted = :deleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "deleted": true,
                "id": userId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
                        
        } catch {
            print("Error: \(error)")
        }
    }

    func me$() -> Observable<User?> {
        let query = "SELECT * FROM users WHERE _id = :id"
        let args: [String: Any?] = [
            "id": ditto.siteID
        ]
        
        return self.ditto
            .resultItems$(query: query, args: args)
            .map({ item in
                if let doc = item.first {
                    return User(resultItem: doc.value)
                } else {
                    return nil
                }
            })
    }

    func users$() -> Observable<[User]> {
        workspaceId$
            .flatMapLatest { [weak users = self.users] (workspaceId) -> Observable<[User]> in
                guard let users = users else { return Observable.empty() }
                
                let query = "SELECT * FROM users WHERE workspaceId =:workspaceId AND deleted = false"
                let args: [String:Any?] = [
                    "workspaceId": workspaceId
                ]
                
                return self.ditto
                    .resultItems$(query: query, args: args)
                    .mapToDittoModel(type: User.self)
            }
    }

    func setUser(id: String? = nil, name: String, seat: String?, role: Role, isManuallyCreated: Bool = false) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to get a workspaceId in `setUser`")
            return
        }
        
        do {
            
            
            //Add workspaceId to small_peer_info metadata
            //This adds it right after the user logs in
            try ditto.smallPeerInfo.setMetadata(["workspace_id": workspaceId])
            
            if let id = id, !(try await ditto.store.execute(query: "SELECT * FROM users WHERE _id = :id", arguments: ["id": id]).items.isEmpty) {
                
                let query = "UPDATE users SET name = :name, seat = :seat, role = :role, workspaceId = :workspaceId WHERE _id = :id"
                
                let args: [String:Any] = [
                    "name": name,
                    "seat": seat as Any,
                    "role": role.rawValue,
                    "workspaceId": workspaceId,
                    "id": id
                ]
                
                try await self.ditto.store.execute(query: query, arguments: args)
            } else {
                let newDoc: [String:Any] = [
                    "_id": id?.toDittoID() as Any,
                    "name": name,
                    "workspaceId": workspaceId,
                    "seat": seat as Any,
                    "isManuallyCreated": isManuallyCreated,
                    "role": role.rawValue,
                    "deleted": false
                ]
                        
                try await self.ditto.store.execute(query: "INSERT INTO users DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
            }
        } catch {
            print("Error: \(error)")
        }
    }

    func categories$() -> Observable<[Category]> {
        return workspaceId$.flatMapLatest { [weak self] workspaceId -> Observable<[Category]> in
            guard let `self` = self else { return Observable.empty() }
            
            let query = "SELECT * FROM categories WHERE workspaceId = :workspaceId AND deleted = false"
            let args: [String:Any?] = [
                "workspaceId": workspaceId
            ]
            
            return self.ditto
                .resultItems$(query: query, args: args)
                .map({ results in
                    return results.map { Category(resultItem: $0.value) }
                        .sorted { (a, b) -> Bool in
                            return a.ordinal < b.ordinal
                        }
                })
        }
    }

    func categoryById$(id: String) -> Observable<Category?> {
        let query = "SELECT * FROM categories WHERE _id = :id"
        let args: [String:Any?] = [
            "id": id
        ]
        
        return self.ditto
            .resultItems$(query: query, args: args)
            .map { (result) -> Category? in
                guard let resultItem = result.first?.value as? [String: Any?] else { return nil }
                return Category(resultItem: resultItem)
            }
        
    }

    func createCategory(name: String, details: String, isCrewOnly: Bool) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `createCategory`")
            return
        }
        
        do {
            
            let count = try await ditto.store.execute(query: "SELECT * FROM categories WHERE workspaceId = :workspaceId AND deleted = 'false'", arguments: ["workspaceId": workspaceId]).items.count
            
            let ordinal = Float.random(min: Float(count), max: Float(count + 1))
            
            let query = "INSERT INTO categories DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
            
            let newDoc: [String:Any] = [
                "name": name,
                "details": details,
                "isCrewOnly": isCrewOnly,
                "ordinal": ordinal,
                "workspaceId": workspaceId,
                "deleted": false
            ]
            
            try await self.ditto.store.execute(query: query, arguments: ["newDoc": newDoc])

        } catch {
            print("Error \(error)")
        }
        
        
    }

    func updateCategory(id: String, name: String, details: String, isCrewOnly: Bool) async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `updateCategory`")
            return
        }
        
        do {
            let query = "UPDATE categories SET name = :name, details = :details, isCrewOnly = :isCrewOnly, workspaceId = :workspaceId WHERE _id = :id"
            
            let args: [String:Any] = [
                "name": name,
                "details": details,
                "isCrewOnly": isCrewOnly,
                "workspaceId": workspaceId,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
        } catch {
            print("Error \(error)")
        }
    }

    func updateCategoryOrdinal(id: String, newOrdinal: Float) async {
        do {
            let query = "UPDATE categories SET ordinal = :ordinal WHERE _id = :id"
            
            let args: [String:Any] = [
                "ordinal": newOrdinal,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
        } catch {
            print("Error \(error)")
        }
    }

    func deleteCategory(id: String) async {
        do {
            let query = "UPDATE categories SET deleted = :deleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "deleted": true,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
        } catch {
            print("Error \(error)")
        }
    }

    func evictAllData() async {
                
        for collection in ditto.store.collectionNames() {
            do {
                try await self.ditto.store.execute(query: "EVICT FROM \(collection)")
            } catch {
                print("Error \(error)")
            }
        }
        
    }
    
    
}
