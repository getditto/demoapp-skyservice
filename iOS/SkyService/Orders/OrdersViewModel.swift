import Foundation
import RxSwift
import RxDataSources


struct OrderSection: AnimatableSectionModelType, IdentifiableType {

    var items: [Row]

    init(original: OrderSection, items: [Row]) {
        self = original
        self.items = items
    }

    init(order: Order, user: User?, cartLineItemsWithMenuItems: [CartLineItemWithMenuItem]) {
        var rows: [Row] = []
        rows.append(.header(order: order, user: user))
        cartLineItemsWithMenuItems.forEach({ rows.append(Row.item(cartLineItem: $0)) })
        rows.append(.footer(order: order))
        self.items = rows
    }


    enum Row: IdentifiableType, Equatable {
        case header(order: Order, user: User?)
        case item(cartLineItem: CartLineItemWithMenuItem)
        case footer(order: Order)
        var identity: String {
            switch self {
            case .header(let order, _):
                return "\(order.id)-header"
            case .item(let item):
                return item.cartLineItem.id
            case .footer(let order):
                return "\(order.id)-footer"
            }
        }
        typealias Identity = String
    }


    typealias Item = Row

    typealias Identity = String

    var identity: String {
        return "order-section-\(self.items[0].identity)"
    }

}

enum OrderListType {
    case processing, finished
}

struct OrdersViewModel {
    // from view
    let sortTypeDidChange$ = BehaviorSubject<Order.SortType>(value: .orderedTime)
    let filterDidChange$ = BehaviorSubject<Order.Filter>(value: Order.Filter())
    let filterButtonDidClick$ = PublishSubject<Void>()
    let listTypeDidChange$ = BehaviorSubject<OrderListType>(value: .processing)

    // to view
    let orderSection$: Observable<[OrderSection]>
    let workspaceId$: Observable<WorkspaceId>
    let categories$: Observable<[Category]>
    let goToFilterViewController$: Observable<(Order.Filter, [Category])>

    /**
     If `userId` is nil, then we will assume the crew is trying to see all the orders
     */
    init(userId: String?) {
        let orders$ = DataService.shared.orders(for: userId).share()
        let users$ = DataService.shared.users$()
        let menuItems$ = DataService.shared.menuItems$()
        let sortType$ = sortTypeDidChange$.flatMapLatest { Observable.just($0) }
        let filter$ = filterDidChange$.flatMapLatest { Observable.just($0) }
        let listType$ = listTypeDidChange$.flatMapLatest { Observable.just($0) }
        categories$ = DataService.shared.categories$().share()
        workspaceId$ = DataService.shared.workspaceId$.map{ WorkspaceId(stringLiteral: $0) }

        orderSection$ = orders$.flatMapLatest { orders -> Observable<[OrderSection]> in
            let orderIds = orders.map{ $0.id }
            return Observable.combineLatest(
                Observable.just(orders),
                users$,
                menuItems$,
                DataService.shared.categories$(),
                DataService.shared.cartLineItems(for: orderIds),
                sortType$,
                listType$,
                filter$
            ) { orders, users, menuItems, categories, cartLineItems, sortType, listType, filter -> [OrderSection] in
                var orderSections: [OrderSection] = []

                let filteredOrders = Bundle.main.isCrew ? orders.filter(
                    by: filter,
                    users: users,
                    menuItems: menuItems,
                    cartLineItems: cartLineItems,
                    listType: listType) : orders
                let sortedOrders = Bundle.main.isCrew ? filteredOrders.sort(by: sortType, users: users) : orders

                for order in sortedOrders {
                    let cartLineItemWithMenuItems = cartLineItems.filter({ $0.orderId == order.id })
                        .compactMap { cartLineItem -> CartLineItemWithMenuItem? in
                            guard let menuItem = menuItems.first(where: { $0.id == cartLineItem.menuItemId }) else { return nil}
                            return CartLineItemWithMenuItem(cartLineItem: cartLineItem, menuItem: menuItem)
                        }
                    let user: User? = users.first(where: { $0.id == order.userId })
                    let orderSection = OrderSection(order: order, user: user, cartLineItemsWithMenuItems: cartLineItemWithMenuItems)
                    orderSections.append(orderSection)
                }
                return orderSections
            }
        }

        goToFilterViewController$ = filterButtonDidClick$.flatMapLatest {
            return Observable.combineLatest(filter$, DataService.shared.categories$()) { filter, categories in
                return (filter, categories)
            }
        }
    }
}
