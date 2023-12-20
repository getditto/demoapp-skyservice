import DittoSwift
import RxDataSources

struct MenuItem: IdentifiableType, Equatable, Ordinal, DittoModel {
    var identity: String {
        return self.id
    }

    typealias Identity = String

    var id: String
    var name: String
    var details: String
    var price: Float
    var categoryId: String?
    var isCrewOnly: Bool
    var deleted: Bool
    /**
     This is to specify maximum quantity that a user can select
     */
    var maxCartQuantityPerUser: Int?
    var ordinal: Float
 
    init(resultItem: [String : Any?]) {
        self.id = resultItem["_id"] as! String
        self.name = resultItem["name"] as? String ?? ""
        self.details = resultItem["details"] as? String ?? ""
        self.isCrewOnly = resultItem["isCrewOnly"] as? Bool ?? false
        self.deleted = resultItem["deleted"] as? Bool ?? false
        self.price = resultItem["price"] as? Float ?? 0
        self.categoryId = resultItem["categoryId"] as? String ?? ""
        self.ordinal = resultItem["ordinal"] as? Float ?? 0.0
    }
}

struct SectionOfMenuItems: AnimatableSectionModelType {
    var items: [MenuItem]
    var category: Category?

    init(items: [MenuItem], category: Category? = nil) {
        self.items = items
        self.category = category
    }

    init(original: SectionOfMenuItems, items: [MenuItem]) {
        self = original
        self.items = items
    }

    var identity: String {
        guard let category = self.category else { return "No Category" }
        return category.id
    }
    typealias Item = MenuItem
    typealias Identity = String
}
