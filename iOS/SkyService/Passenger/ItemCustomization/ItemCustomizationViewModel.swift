import Foundation
import RxSwift

struct FormStructure: Equatable {
    var name: String
    var details: String
    var options: [MenuItemOption]
    var quantity: Int
    var selectedOptions: [String: [String]]
}

struct ItemCustomizationViewModel {

    struct FormValues {
        let quantity: Int
        let menuItemId: String
        let userId: String
        let options: [String]
    }

    // from view
    let closeButtonDidClick$ = PublishSubject<Void>()
    let counterButtonDidClick$ = PublishSubject<Int>()
    let addButtonDidClick$ = PublishSubject<[String: Any?]>()

    // to view
    let options$: Observable<[MenuItemOption]>
    let name$: Observable<String>
    let dismissViewController$: Observable<Void>
    let formStructure$: Observable<FormStructure>


    init(menuItemId: String, userId: String) {
        let menuItem$ = DataService.shared.menuItemById$(menuItemId)
        options$ = DataService.shared.menuItemOptions(menuItemId)


        let completedCartLineItem$ = addButtonDidClick$
            .flatMapLatest { formValues -> Observable<Void> in
                let quantity = abs(formValues["quantity"] as? Int ?? 0)
                let options: [String] = formValues.keys.filter({ $0.starts(with: "option::")}).compactMap({ formValues[$0] as? String })

                return DataService.shared.setCartLineItem(userId: userId, menuItemId: menuItemId, quantity: quantity, options: options)
            }

        // this is the name of theproduct
        name$ = menuItem$.map({ $0?.name }).filterNil()
        // if the user clicks the close button or if the menu item suddenly does not exist (because it was deleted)
        dismissViewController$ = Observable.merge([
            closeButtonDidClick$,
            menuItem$.filter({ $0 == nil }).map({ _ in Void() }),
            completedCartLineItem$
        ])

        let quantity$ = counterButtonDidClick$
            .scan(1, accumulator: { lastValue, newValue in
                let sum = lastValue + newValue
                // prevent the user from returning a quantity less than 0
                return sum < 1 ? 1 : sum
            })
            .startWith(1)

        formStructure$ = Observable.combineLatest(menuItem$, options$, quantity$) { menuItem, options, quantity in
            return FormStructure(name: menuItem?.name ?? "", details: menuItem?.details ?? "", options: options, quantity: quantity, selectedOptions: [:])
        }.share()


    }
}
