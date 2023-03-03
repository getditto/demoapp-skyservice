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

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.name = document["name"].stringValue
        self.details = document["details"].stringValue
        self.ordinal = document["ordinal"].floatValue
        self.isCrewOnly = document["isCrewOnly"].boolValue
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
