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
        self.type = MenuItemOptionType(rawValue: document["type"].stringValue) ?? MenuItemOptionType.single
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

    func deleteMenuItemOption(menuItemOptionId: String) async {
        do {
            let query = "UPDATE menuItemOptions SET deleted = :deleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "deleted": true,
                "id": menuItemOptionId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
                        
        } catch {
            print("Error: \(error)")
        }
    }

    func createMenuItemOption(menuItemId: String, type: MenuItemOption.MenuItemOptionType) async {
        guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
        
        do {
            let result = try await ditto.store.execute(query: "SELECT * FROM menuItemOptions WHERE menuItemId = :itemId AND deleted = 'false' ORDER BY ordinal ASC", arguments: ["itemId": menuItemId]).items.last
            
            let ordinal: Float = {
                guard let lastOrdinal = result?.value["ordinal"] as? Float else {
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
            
            let newDoc: [String:Any] = [
                "label": label,
                "details": details,
                "isRequired": type == .text ? false : true,
                "type": type.rawValue,
                "ordinal": ordinal,
                "menuItemId": menuItemId,
                "workspaceId": workspaceId,
                "allowedValues": allowedValues,
                "deleted": false
            ]
                    
            try await self.ditto.store.execute(query: "INSERT INTO menuItemOptions DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
            
        } catch {
            print("Error: \(error)")
        }
    }

    func saveMenuItemOption(menuItemOptionId: String, label: String, details: String, isRequired: Bool, allowedValues: [String] = []) async {
        do {
            guard let workspaceId: String = UserDefaults.standard.workspaceId?.description else { return }
            
            let query = "UPDATE menuItemOptions SET label = :label, details = :details, isRequired = :isRequired, workspaceId = :workspaceId, allowedValues = :allowedValues WHERE _id = :id"
            
            let args: [String:Any] = [
                "label": label,
                "details": details,
                "isRequired": isRequired,
                "workspaceId": workspaceId,
                "allowedValues": allowedValues,
                "id": menuItemOptionId
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
                        
        } catch {
            print("Error: \(error)")
        }
    }

}
