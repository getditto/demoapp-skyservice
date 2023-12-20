import DittoSwift
import RxDataSources

struct User: Equatable, IdentifiableType, DittoModel {

    typealias Identity = String
    var identity: String {
        return id
    }

    var id: String
    var name: String
    var seat: String?
    var role: Role
    var isManuallyCreated: Bool
    var deleted: Bool

    /**
     TODO: remove this!
     */
    var isCrew: Bool {
        return self.role == .crew
    }

    init(resultItem: [String : Any?]) {
        self.id = resultItem["_id"] as! String
        self.name = resultItem["name"] as? String ?? ""
        self.seat = resultItem["seat"] as? String ?? ""
        self.isManuallyCreated = resultItem["isManuallyCreated"] as? Bool ?? false
        self.role = {
            guard let val = resultItem["role"] as? String else {
            return .passenger
        }
            return Role(rawValue: val) ?? .passenger
        }()
        
        self.deleted = resultItem["deleted"] as? Bool ?? false
    }

    var seatAbreast: String? {
        if let seat = seat, !seat.isEmpty, let last = seat.last, last.isLetter {
            return String(last)
        } else {
            return nil
        }
    }

    var seatNumber: Int? {
        let isSeatEmpty = seat == nil || seat == ""
        return isSeatEmpty ? nil : Int(seat!.dropLast())
    }
}

struct SectionOfUser: AnimatableSectionModelType {

    var items: [User]

    var identity: String = "Users"

    typealias Item = User
    typealias Identity = String

    init(original: SectionOfUser, items: [User]) {
        self = original
        self.items = items
    }

    init(items: [User], identity: String = "Users") {
        self.items = items
        self.identity = identity
    }

}
