import Foundation
import DittoSwift
import RxSwift

struct MenuItemOption: DittoModel, Ordinal, Equatable {

    enum MenuItemOptionType: String {
        case single = "single"
        case multiple = "multiple"
        case text = "text"

        var formTitle: String {
            switch self {
            case .multiple:
                return "Multiple Option"
            case .single:
                return "Single Option"
            case .text:
                return "Free Text"
            }
        }
    }

    var id: String
    var label: String
    var details: String
    var ordinal: Float
    var menuItemId: String
    var type: MenuItemOptionType
    var isRequired: Bool
    var deleted: Bool

    var allowedValues: [String]

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.label = document["label"].stringValue
        self.details = document["details"].stringValue
        self.ordinal = document["ordinal"].floatValue
        self.menuItemId = document["menuItemId"].stringValue
        self.type = MenuItemOptionType(rawValue: document["type"].stringValue)!
        self.isRequired = document["isRequired"].boolValue
        self.allowedValues = document["allowedValues"].register?.arrayValue.compactMap({ (v) -> String? in
            return v as? String
        }) ?? []
        self.deleted = document["deleted"].boolValue
    }
}


extension DataService {

    func menuItemOptions$() -> Observable<[MenuItemOption]> {
        return self.workspaceId$
            .flatMapLatest { [weak self] (workspaceId) -> Observable<[MenuItemOption]> in
                guard let `self` = self else { return Observable.empty() }
                return self.ditto
                    .store["menuItemOptions"]
                    .find("workspaceId == '\(workspaceId)' && deleted == false")
                    .documents$()
                    .mapToDittoModel(type: MenuItemOption.self)
            }
    }

    func menuItemOptions(_ menuItemId: String) -> Observable<[MenuItemOption]> {
        return self.ditto
            .store["menuItemOptions"]
            .find("menuItemId == '\(menuItemId)' && deleted == false")
            .documents$()
            .mapToDittoModel(type: MenuItemOption.self)
    }

    func menuItemOptionById(_ menuItemOptionId: String) -> Observable<MenuItemOption?> {
        return self.ditto
            .store["menuItemOptions"]
            .findByID(menuItemOptionId)
            .document$()
            .mapToDittoModel(type: MenuItemOption.self)
    }

    func deleteMenuItemOption(menuItemOptionId: String) {
        self.ditto.store["menuItemOptions"].findByID(menuItemOptionId).update{ (mutable) in
            guard let mutable = mutable else { return }
            mutable["deleted"].set(true)
        }
    }

    func createMenuItemOption(menuItemId: String, type: MenuItemOption.MenuItemOptionType) {
        guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
        self.ditto.store.write { (txn) in
            let lastVal: DittoDocument? = txn["menuItemOptions"].find("menuItemId == '\(menuItemId)' && deleted == false")
                .sort("ordinal", direction: .ascending).exec().last

            let ordinal: Float = {
                guard let lastOrdinal = lastVal?["ordinal"].float else {
                    return Float.random(min: 0, max: 1)
                }
                return lastOrdinal + Float.random(min: 0, max: 1)
            }()

            var label: String
            var details: String
            var allowedValues: [String]
            switch type {
            case .multiple:
                label = "Multiple menu option"
                details = "Allow the passenger to select multiple option values"
                allowedValues = ["Option A", "Option B", "Option C"]
            case .single:
                label = "Single menu option"
                details = "Allow the passenger to select a single option value"
                allowedValues = ["Option A", "Option B", "Option C"]
            case .text:
                label = "Add specific instructions (if any)"
                details = "Allow the passenger to type in an option value using a check box"
                allowedValues = []
            }

            try! txn["menuItemOptions"]
                .upsert([
                    "label": label,
                    "details": details,
                    "isRequired": type == .text ? false : true,
                    "type": type.rawValue,
                    "ordinal": ordinal,
                    "menuItemId": menuItemId,
                    "workspaceId": workspaceId,
                    "allowedValues": allowedValues,
                    "deleted": false
                ])
        }
    }

    func saveMenuItemOption(menuItemOptionId: String, label: String, details: String, isRequired: Bool, allowedValues: [String] = []) {
        guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
        self.ditto.store["menuItemOptions"].findByID(menuItemOptionId).update { (doc) in
            guard let doc = doc else { return }
            doc["label"].set(label)
            doc["details"].set(details)
            doc["isRequired"].set(isRequired)
            doc["workspaceId"].set(workspaceId)
            doc["allowedValues"].set(DittoRegister(value: allowedValues))
        }
    }

}
