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
    var totalCount: Int?
    var usedCount: Int?
    var isCrewOnly: Bool
    /**
     This is to specify maximum quantity that a user can select
     */
    var maxCartQuantityPerUser: Int?
    var ordinal: Float

    //usedForCombineLatest
    var category: Category?

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.name = document["name"].stringValue
        self.details = document["details"].stringValue
        self.price = document["price"].floatValue
        self.categoryId = document["categoryId"].string
        self.totalCount = document["totalCount"].int
        self.usedCount = document["usedCount"].int
        self.isCrewOnly = document["isCrewOnly"].boolValue

        if let ordinal = document["ordinal"].float {
            self.ordinal = ordinal
        } else {
            self.ordinal = Float.random(min: 0, max: 0.5)
        }
    }

    var remainsCount: Int? {
        guard let total = totalCount else { return nil }
        let used = usedCount ?? 0
        return total - used
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
