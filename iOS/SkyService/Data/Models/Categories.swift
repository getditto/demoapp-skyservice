import RxDataSources
import DittoSwift

struct Category: Equatable, IdentifiableType, Ordinal, DittoModel {
    
    typealias Identity = String
    var identity: String { return self.id }

    var id: String
    var name: String
    var details: String
    var ordinal: Float
    var isCrewOnly: Bool
    var deleted: Bool

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.name = document["name"].stringValue
        self.details = document["details"].stringValue
        self.ordinal = document["ordinal"].floatValue
        self.isCrewOnly = document["isCrewOnly"].boolValue
        self.deleted = document["deleted"].boolValue
    }
    
    init(resultItem: [String : Any?]) {
        self.id = resultItem["_id"] as! String
        self.name = resultItem["name"] as? String ?? ""
        self.ordinal = resultItem["ordinal"] as? Float ?? 0
        self.details = resultItem["details"] as? String ?? ""
        self.isCrewOnly = resultItem["isCrewOnly"] as? Bool ?? false
        self.deleted = resultItem["deleted"] as? Bool ?? false
    }
}

struct SectionOfCategories: AnimatableSectionModelType {
    var items: [Category]

    init(items: [Category]) {
        self.items = items
        self.identity = "Category Items"
    }

    init(original: SectionOfCategories, items: [Category]) {
        self = original
        self.items = items
    }

    var identity: String
    typealias Item = Category
    typealias Identity = String
}
