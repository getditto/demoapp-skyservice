import Foundation
import RxCocoa
import RxSwift
import RxDataSources

struct CartLineItemWithMenuItem: IdentifiableType, Equatable {
    var cartLineItem: CartLineItem
    var menuItem: MenuItem

    typealias Identity = String
    var identity: String {
        return self.cartLineItem.id
    }
}

struct SectionOfCartLineItemsWithMenuItem: AnimatableSectionModelType {

    var items: [CartLineItemWithMenuItem]

    init(original: SectionOfCartLineItemsWithMenuItem, items: [CartLineItemWithMenuItem]) {
        self = original
        self.items = items
    }

    init(items: [CartLineItemWithMenuItem]) {
        self.items = items
    }

    typealias Item = CartLineItemWithMenuItem

    typealias Identity = String

    var identity: String {
        // this doesn't matter, it just has to be the same. we are only using one section
        return "lineItems"
    }
}

struct CartViewModel {

    // from view controller
    let clearCartButtonDidClick$ = PublishSubject<Void>()
    let checkoutButtonDidClick$ = PublishSubject<Void>()
    let cartLineItemWithMenuItemDeleted$ = PublishSubject<CartLineItemWithMenuItem>()


    // to view controller
    let popViewController$: Observable<Void>
    let goToOrdersController$: Observable<Void>
    let sectionsOfCartItemsWithMenuItem$: Observable<[SectionOfCartLineItemsWithMenuItem]>
    let checkoutButtonVisible$: Observable<Bool>
    let finishedDeletingCartLineItemWithMenuItem$: Observable<Void>

    init(userId: String) {
        let menuItems$ = DataService.shared.menuItems$()
        let cartLineItems$ = DataService.shared.cartLineItems(for: userId)

        sectionsOfCartItemsWithMenuItem$ = Observable.combineLatest(menuItems$, cartLineItems$) { (menuItems, cartLineItems) -> [SectionOfCartLineItemsWithMenuItem] in
            var finalItems: [CartLineItemWithMenuItem] = []

            for c in cartLineItems {
                guard let menuItem = menuItems.first(where: { $0.id == c.menuItemId }) else { continue }
                finalItems.append(CartLineItemWithMenuItem(cartLineItem: c, menuItem: menuItem))
            }

            return [SectionOfCartLineItemsWithMenuItem(items: finalItems)]
        }


        goToOrdersController$ = checkoutButtonDidClick$.flatMapLatest({ _ in
            return DataService.shared.createOrder(for: userId)
        })

        popViewController$ = clearCartButtonDidClick$.flatMapLatest({ _ -> Observable<Void> in
            return DataService.shared.clearCartLineItems(for: userId)
        })

        checkoutButtonVisible$ = cartLineItems$.map({ $0.count > 0 })

        finishedDeletingCartLineItemWithMenuItem$ = cartLineItemWithMenuItemDeleted$.flatMapLatest({ item -> Observable<Void> in
            let id = item.cartLineItem.id
            return DataService.shared.removeCartLineItem(id: id)
        })
    }

}
