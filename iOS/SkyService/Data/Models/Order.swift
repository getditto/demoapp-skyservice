import UIKit
import DittoSwift
import RxDataSources

struct Order: Equatable, DittoModel {

    enum Status: Int, CaseIterable {
        case open
        case preparing
        case fulfilled
        case canceled
        
        var humanReadable: String {
            switch self {
            case .open:
                return "order placed"
            case .preparing:
                return "preparing"
            case .fulfilled:
                return "order delivered"
            case .canceled:
                return "cancelled"
            }
        }

        var segmentedControlTitle: String {
            switch self {
            case .open:
                return "placed"
            case .preparing:
                return "preparing"
            case .fulfilled:
                return "delivered"
            case .canceled:
                return "cancelled"
            }
        }

        var tintColor: UIColor {
            switch self {
            case .open:
                return .secondaryLabel
            case .preparing:
                return .systemBlue
            case .fulfilled:
                return .systemGreen
            case .canceled:
                return .systemRed
            }
        }

        var segmentedControlTextColor: UIColor {
            switch self {
            case .open:
                return UIColor.darkText
            default:
                return UIColor.white
            }
        }

        var isFinished: Bool {
            return self == .canceled || self == .fulfilled
        }
    }

    enum SortType: CaseIterable {
        case orderedTime
        case seatNumber
        case orderStatus

        var name: String {
            switch self {
            case .orderedTime: return "Ordered Time"
            case .seatNumber: return "Seat Number"
            case .orderStatus: return "Order Status"
            }
        }
    }

    class Filter {
        enum OrderUserType: CaseIterable {
            case crew, passenger
        }
        var seatAbreast: [String]
        var orderStatus = Status.allCases
        var orderUserType = [OrderUserType.crew, OrderUserType.passenger]

        var defaultAbreast = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K"]
        var totalCategoryCount: Int?

        init() {
            self.seatAbreast = defaultAbreast
        }

        func reset() -> Self {
            seatAbreast = defaultAbreast
            orderStatus = Status.allCases
            orderUserType = [OrderUserType.crew, OrderUserType.passenger]
            return self
        }

        func removeAllCategoryFilter() -> Self {
            seatAbreast = defaultAbreast
            orderStatus = Status.allCases
            orderUserType = [OrderUserType.crew, OrderUserType.passenger]
            return self
        }

        var isAnyFilterActive: Bool {
            return isSeatAbreastFilterActive ||
                    isOrderStatusFilterActive ||
                    isOrderUserTypeFilterActive
        }
        var isSeatAbreastFilterActive: Bool {
            seatAbreast.count < defaultAbreast.count
        }
        var isOrderStatusFilterActive: Bool {
            orderStatus.count < Order.Status.allCases.count
        }
        var isOrderUserTypeFilterActive: Bool {
            orderUserType.count < Order.Filter.OrderUserType.allCases.count
        }
    }

    var id: String
    var total: Float
    var createdOn: Date
    var status: Status
    var userId: String
    var crewNote: String
    var deleted: Bool
    
    init(resultItem: [String : Any?]) {
        self.id = resultItem["_id"] as! String
        self.total = resultItem["total"] as? Float ?? 0
        self.createdOn = Date(dateString: resultItem["createdOn"] as? String ?? "")
        self.status = Status(rawValue: resultItem["status"] as? Int ?? 0) ?? .open
        self.userId = resultItem["userId"] as? String ?? ""
        self.crewNote = resultItem["crewNote"] as? String ?? ""
        self.deleted = resultItem["deleted"] as? Bool ?? false
    }
}

extension Array where Element == Order {
    // MARK: SORT

    func sort(by type: Order.SortType, users: [User]) -> [Element] {
        switch type {
        case .orderedTime: return orderedTimeSort()
        case .seatNumber: return seatNumberSort(users: users)
        case .orderStatus: return orderStatusSort()
        }
    }
    private func orderedTimeSort() -> [Element] {
        return self.sorted {
            $0.createdOn > $1.createdOn
        }
    }

    private func seatNumberSort(users: [User]) -> [Element] {
        let sortedByAbreast = self.sorted { order1, order2 in
            let user1 = users.first { user in
                user.id == order1.userId
            }
            let user2 = users.first { user in
                user.id == order2.userId
            }
            guard let abreast1 = user1?.seatAbreast, let abreast2 = user2?.seatAbreast else { return false }
            return abreast1 < abreast2
        }

        return sortedByAbreast.sorted { order1, order2 in
            let user1 = users.first { user in
                user.id == order1.userId
            }
            let user2 = users.first { user in
                user.id == order2.userId
            }
            guard let number1 = user1?.seatNumber, let number2 = user2?.seatNumber else { return false }
            return number1 < number2
        }
    }

    private func orderStatusSort() -> [Element] {
        return self.sorted {
            $0.status.rawValue < $1.status.rawValue
        }
    }

    // MARK: FILTER

    func filter(
        by filter: Order.Filter,
        users: [User],
        menuItems: [MenuItem],
        cartLineItems: [CartLineItem],
        listType: OrderListType
    ) -> [Element] {
        return seatAbrestFilter(filter.seatAbreast, users: users)
            .orderStatusFilter(filter.orderStatus, listType)
            .orderUserTypeFilter(filter.orderUserType, users: users)
    }

    private func seatAbrestFilter(_ filter: [String], users: [User]) -> [Element] {
        return self.filter { order in
            let user = users.first { user in
                user.id == order.userId
            }
            guard let alphabet = user?.seat?.last else { return true }
            return filter.contains(String(alphabet))
        }
    }

    private func orderStatusFilter(_ filter: [Order.Status], _ listType: OrderListType) -> [Element] {
        let filtered = self.filter {
            filter.contains($0.status)
        }
        return filtered
    }

    private func orderUserTypeFilter(_ filter: [Order.Filter.OrderUserType], users: [User]) -> [Element] {
        return self.filter { order in
            let user = users.first { user in
                user.id == order.userId
            }

            if let user = user {
                return (!user.isManuallyCreated && filter.contains(.passenger)) ||
                        (user.isManuallyCreated && filter.contains(.crew))
            } else {
                // We need to show orders from unknown users.
                // See details: https://github.com/getditto/demo-apps/issues/384
                return true
            }
        }
    }
}
