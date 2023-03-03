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

    func updateWelcomeMessage(_ message: String) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }
        ditto.store["workspaces"].findByID(workspaceId).update { m in
            m?["welcomeMessage"].set(message)
        }
    }

    func setEnableOrdering(isOrderingEnabled: Bool) {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }
        ditto.store.write { (txn) in
            if txn["workspaces"].findByID(workspaceId).exec() != nil {
                txn["workspaces"].findByID(workspaceId).update { (m) in
                    m?["isOrderingEnabled"].set(isOrderingEnabled)
                }
            } else {
                try! txn["workspaces"].upsert([
                    "_id": workspaceId.toDittoID(),
                    "isOrderingEnabled": isOrderingEnabled
                ])
            }
        }
    }

}
