import RxSwift
import RxCocoa
import RxDataSources

struct MenuItemWithCartLineItems: IdentifiableType, Equatable {
    typealias Identity = String
    var identity: String {
        return self.menuItem.id
    }
    var menuItem: MenuItem
    var cartLineItems: [CartLineItem]
    var options: [MenuItemOption]
}

struct SectionOfPassengerMenuItems: AnimatableSectionModelType, SectionModelType {

    typealias Item = MenuItemWithCartLineItems

    typealias Identity = String

    var items: [MenuItemWithCartLineItems]

    var category: Category?

    var identity: String {
        return self.category?.id ?? "uncategorised"
    }

    init(original: SectionOfPassengerMenuItems, items: [MenuItemWithCartLineItems]) {
        self = original
        self.items = items
    }

    init(category: Category?, items: [MenuItemWithCartLineItems]) {
        self.category = category
        self.items = items;
    }

}

class PassengerMenuViewModel {

    let sectionsOfPassengerMenuItems$: Observable<[SectionOfPassengerMenuItems]>

    // from ViewController
    let cartButtonDidClick$ = PublishSubject<Void>()
    let addButtonTappedSubject$ = PublishSubject<MenuItemWithCartLineItems>()

    // to viewController
    let presentMenuOptionsViewController$: Observable<(menuItemId: String, userId: String)>
    let titleView$: Observable<WorkspaceId>
    let canShowCartButton$: Observable<Bool>
    let goToCart$: Observable<String>

    init(userId: String) {
        let menuItems$ = DataService.shared.menuItems$()
        let categories$ = DataService.shared.categories$()
        let cartLineItems$ = DataService.shared.cartLineItems(for: userId).share()
        let menuItemOptions$ = DataService.shared.menuItemOptions$()

        sectionsOfPassengerMenuItems$ = Observable.combineLatest(menuItems$, categories$, cartLineItems$, menuItemOptions$) { (menuItems, categories, cartLineItems, menuItemOptions) -> [SectionOfPassengerMenuItems] in
            var sectionOfPassengerMenuItems = [SectionOfPassengerMenuItems]()
            let menuItems: [MenuItemWithCartLineItems] = menuItems
                .compactMap({ menuItem in
                    var menuItem = menuItem

                    if !Bundle.main.isCrew && menuItem.isCrewOnly {
                        return nil
                    }
                    // Don't show out-of-stock items to pax
                    if let remains = menuItem.remainsCount {
                        if !Bundle.main.isCrew && remains <= 0 { return nil }
                    }

                    let cartLineItems = cartLineItems.filter({ $0.menuItemId == menuItem.id })
                    let options = menuItemOptions.filter({ $0.menuItemId == menuItem.id })
                    return MenuItemWithCartLineItems(menuItem: menuItem, cartLineItems: cartLineItems, options: options)
                })
            for category in categories {
                guard Bundle.main.isCrew || !category.isCrewOnly else { break }

                let items = menuItems.filter({ $0.menuItem.categoryId == category.id }).sorted(by: { $0.menuItem.ordinal < $1.menuItem.ordinal })
                sectionOfPassengerMenuItems.append(SectionOfPassengerMenuItems(category: category, items: items))
            }
            let uncategorized = menuItems.filter({ $0.menuItem.categoryId == nil }).sorted(by: { $0.menuItem.ordinal < $1.menuItem.ordinal })
            if !uncategorized.isEmpty {
                sectionOfPassengerMenuItems.append(SectionOfPassengerMenuItems(category: nil, items: uncategorized))
            }
            return sectionOfPassengerMenuItems
        }

        titleView$ = DataService.shared.workspaceId$.map({ WorkspaceId(stringLiteral: $0) })

        presentMenuOptionsViewController$ = addButtonTappedSubject$
            .map({ (menuItem: $0.menuItem.id, userId: userId) })

        canShowCartButton$ = cartLineItems$.map({ $0.count > 0 })

        goToCart$ = cartButtonDidClick$.map({ _ in userId })
    }

}
