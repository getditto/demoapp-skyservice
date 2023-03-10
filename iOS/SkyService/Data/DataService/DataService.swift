import DittoSwift
import RxSwift
import RxOptional

final class AuthDelegate: DittoAuthenticationDelegate {
    func authenticationRequired(authenticator: DittoAuthenticator) {
        authenticator.loginWithToken(Env.DITTO_AUTH_PASSWORD, provider: Env.DITTO_AUTO_PROVIDER)  { err in
            print("Login request completed. Error? \(String(describing: err))")
        }
    }

    func authenticationExpiringSoon(authenticator: DittoAuthenticator, secondsRemaining: Int64) {
        authenticator.loginWithToken(Env.DITTO_AUTH_PASSWORD, provider: Env.DITTO_AUTO_PROVIDER)  { err in
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
        
        menuItems = ditto.store["menuItems"]
        users = ditto.store["users"]
        orders = ditto.store["orders"]
        chatMessages = ditto.store["chatMessages"]
        categories = ditto.store["categories"]
        notes = ditto.store["notes"]
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

        let queryString: String = "workspaceId == '\(workspaceId)'"
        // i had no way to stop a subscription
        [
            menuItems,
            users,
            orders,
            chatMessages,
            categories,
            notes
        ].forEach { (collection) in
            collection?.find(queryString).documents$()
                .subscribeNext({ _ in })
                .disposed(by: disposeBag)
        }

        self.ditto.store["workspaces"].findByID(workspaceId)
            .document$()
            .bind { _ in }
            .disposed(by: disposeBag)

        // registering background notifications

        chatMessages
            .find(queryString)
            .documentsWithEventInfo$()
            .filter { _ in Bundle.main.isCrew } // notify only crew
            .filter { _ in UIApplication.shared.applicationState == .background } // notify only in background
            .flatMapLatest { event -> Observable<ChatMessage> in
                var chatMessages: [ChatMessage] = []
                if case .update(let updates) = event.liveQueryEvent {
                    chatMessages = updates.insertions.map({ ChatMessage(document: event.documents[$0] ) })
                }
                return Observable.from(chatMessages)
            }
            .bind { (insertedChatMessage) in
                let content = UNMutableNotificationContent()
                content.title = "New Message"
                content.body = insertedChatMessage.body
                content.userInfo = [
                    "notificationType": "newChatMessage"
                ]
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "chat_notification.wav"))
                let req = UNNotificationRequest.init(identifier: "chatMessages", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
            .disposed(by: disposeBag)


        orders
            .find(queryString)
            .documentsWithEventInfo$()
            .filter { _ in Bundle.main.isCrew } // only crew should see this
            .flatMapLatest({ e -> Observable<DittoDocument> in
                let documents = e.documents
                let eventInfo = e.liveQueryEvent
                var insertedDocuments = [DittoDocument]()
                if case .update(let u) = eventInfo {
                    let insertionIndices = u.insertions
                    insertedDocuments = insertionIndices.map { documents[$0] }
                }
                return Observable.from(insertedDocuments)
            })
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


        orders
            .find(queryString)
            .documentsWithEventInfo$()
            .filter { _ in !Bundle.main.isCrew } // pax app only
            .flatMapLatest { e -> Observable<Order> in
                let documents = e.documents
                let eventInfo = e.liveQueryEvent
                var updatedOrders = [Order]()
                if case let .update(u) = eventInfo {
                    updatedOrders = u.updates
                        .compactMap({
                            let previousStatus = u.oldDocuments[$0]["status"].intValue
                            let newStatus = e.documents[$0]["status"].intValue
                            return previousStatus == newStatus ? nil: Order(document: documents[$0])
                        })
                        .filter({ $0.userId == self.userId })
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

        let justMenuItems$ = menuItems
            .find("workspaceId == '\(workspaceId)'")
            .documents$()
            .map { (docs) -> [MenuItem] in
                return docs.map({ MenuItem(document: $0) })
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

        return Observable.combineLatest(justMenuItems$, cartItems$, expansionSet$, categories$, self.canOrder$()) { menuItemsOriginal, cartItems, expansionSet, categories, canOrder in
            var menuItems = [MenuItem]()
            for var menuItem in menuItemsOriginal {
                menuItem.category = categories.first(where: { $0.id == menuItem.categoryId })
                menuItems.append(menuItem)
            }

            var sectionOfMenuItems = [SectionOfMenuItems]()
            for category in categories.sorted(by: { $0.ordinal < $1.ordinal }) {
                let menuItems = menuItems.filter({ $0.categoryId == category.id })
                    .sorted(by: { $0.ordinal < $1.ordinal })
                sectionOfMenuItems.append(SectionOfMenuItems(items: menuItems, category: category))
            }
            let uncatMenuItems = menuItems.filter({ $0.categoryId == nil || $0.category == nil })
                .sorted(by: { $0.ordinal < $1.ordinal })
            if !uncatMenuItems.isEmpty {
                sectionOfMenuItems.append(SectionOfMenuItems(items: uncatMenuItems, category: nil))
            }

            return (sectionOfMenuItems: sectionOfMenuItems, allCategories: categories, canOrder: canOrder)
        }
    }

    func deleteMenuItem(id: String) {
        menuItems.findByID(id).remove()
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
        return users.findByID(id).document$()
            .map({ doc in
                if let doc = doc {
                    return User(document: doc)
                } else {
                    return nil
                }
            })
    }

    func deleteUser(userId: String) {
        users.findByID(userId).remove()
    }

    func me$() -> Observable<User?> {
        return users.findByID("\(ditto.siteID)").document$()
            .map({ doc in
                if let doc = doc {
                    return User(document: doc)
                } else {
                    return nil
                }
            })
    }

    func users$() -> Observable<[User]> {
        workspaceId$
            .flatMapLatest { [weak users = self.users] (workspaceId) -> Observable<[User]> in
                guard let users = users else { return Observable.empty() }
                return users
                    .find("workspaceId == '\(workspaceId)'")
                    .documents$()
                    .mapToDittoModel(type: User.self)
            }
    }

    func setUser(id: String? = nil, name: String, seat: String?, role: Role, isManuallyCreated: Bool = false) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("Failed to get a workspaceId in `setUser`")
            return
        }
        ditto.store.write { (tx) in
            if let id = id, let _ = tx["users"].findByID(id).exec() {
                tx["users"].findByID(id).update { (m) in
                    m?["name"].set(name)
                    m?["seat"].set(seat)
                    m?["role"].set(role.rawValue)
                    m?["workspaceId"].set(workspaceId)
                    // no one should really override this
                    //m?["isManuallyCreated"].set(isManuallyCreated)
                }
            } else {
                try! tx["users"].upsert([
                    "_id": id?.toDittoID(),
                    "name": name,
                    "workspaceId": workspaceId,
                    "seat": seat,
                    "isManuallyCreated": isManuallyCreated,
                    "role": role.rawValue
                ], writeStrategy: .insertIfAbsent)
            }
        }
    }

    func categories$() -> Observable<[Category]> {
        return workspaceId$.flatMapLatest { [weak self] workspaceId -> Observable<[Category]> in
            guard let `self` = self else { return Observable.empty() }
            return self.categories
                .find("workspaceId == '\(workspaceId)'")
                .documents$()
                .map({ docs in
                    return docs.map { Category(document: $0) }
                        .sorted { (a, b) -> Bool in
                            return a.ordinal < b.ordinal
                        }
                })
        }
    }

    func categoryById$(id: String) -> Observable<Category?> {
        return categories.findByID(id).document$()
            .map { (doc) -> Category? in
                guard let doc = doc else { return nil }
                return Category(document: doc)
            }
    }

    func createCategory(name: String, details: String, isCrewOnly: Bool) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `createCategory`")
            return
        }
        ditto.store.write { (txn) in
            let count = txn["categories"].find("workspaceId == '\(workspaceId)'").exec().count
            let ordinal = Float.random(min: Float(count), max: Float(count + 1))
            try! txn["categories"].upsert([
                "name": name,
                "details": details,
                "workspaceId": workspaceId,
                "ordinal": ordinal,
                "isCrewOnly": isCrewOnly
            ])
        }
    }

    func updateCategory(id: String, name: String, details: String, isCrewOnly: Bool) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            debugPrint("No workspaceId was found while attempting to call `updateCategory`")
            return
        }
        categories.findByID(id).update { (mutable) in
            guard let mutable = mutable else { return }
            mutable["name"].set(name)
            mutable["workspaceId"].set(workspaceId)
            mutable["details"].set(details)
            mutable["isCrewOnly"].set(isCrewOnly)
        }
    }

    func updateCategoryOrdinal(id: String, newOrdinal: Float) {
        categories.findByID(id).update { (mutable) in
            guard let mutable = mutable else { return }
            mutable["ordinal"].set(newOrdinal)
        }
    }

    func deleteCategory(id: String) {
        categories.findByID(id).remove()
    }

    func evictAllData() {
        ditto.store.collectionNames().forEach {
            ditto.store[$0].findAll().evict()
        }
    }
}
