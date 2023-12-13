import UIKit
import RxSwift
import Eureka

class EditMenuItemViewController: FormViewController {

    let menuItemId: String
    var disposeBag = DisposeBag()
    private let isCrewOnly: Bool

    init(menuItemId: String, isCrewOnly: Bool) {
        self.menuItemId = menuItemId
        self.isCrewOnly = isCrewOnly
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Edit Menu Item"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(dismissButtonDidClick))

        form
            +++ Section()
            <<< TextRow("name", { (row) in
                row.title = "Name"
            })
            <<< CustomTextAreaRow("details") { row in
                row.title = "Details"
            }
            <<< DecimalRow("price", { (row) in
                row.title = "Price"
                row.hidden = Condition(booleanLiteral: true)
            })
            <<< IntRow("max", { (row) in
                row.title = "Price"
                row.hidden = Condition(booleanLiteral: true)
            })
            <<< PushRow<Category>("category") { row in
                row.title = "Category"
                row.options = []
                row.selectorTitle = "Choose a category"
            }.cellSetup({ (cell, row) in
                cell.textLabel?.text = row.value?.name
            }).cellUpdate({ (cell, row) in
                cell.detailTextLabel?.text = row.value?.name
            }).onPresent({ (from, to) in
                to.selectableRowSetup = { row in
                    row.title = row.selectableValue?.name
                }
                to.selectableRowCellUpdate = { cell, row in
                    cell.textLabel?.text = row.selectableValue?.name
                }
            })
            <<< SwitchRow("isCrewOnlyMenu") { row in
                row.title = "Crew Only"
            }.cellSetup({ [weak self] cell, row in
                guard let self = self else { return }
                row.value = self.isCrewOnly
            })
            .onChange({ [weak self] row in
                guard let self = self else { return }
                guard let value = row.value else { return }
                Task {
                    await DataService.shared.changeIsCrewOnly(menuItemId: self.menuItemId, isCrewOnly: value)
                }
            })
            +++ Section()
            <<< ButtonRow("save", { (row) in
                row.title = "Save Changes"
                row.cell.tintColor = .systemGreen
                row.cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: UIFont.Weight.bold)
            }).onCellSelection({ [weak self] (_, _) in
                self?.save()
            })

        setupOptionsSection()
        setupStocksSection()

        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: self, action: #selector(delete(sender:)))

        let menuItem = DataService.shared.menuItemById$(menuItemId)
        let categories = DataService.shared.categories$()

        Observable.combineLatest(menuItem, categories)
            .subscribeNext({ [weak self] menuItem, categories in
                guard let menuItem = menuItem else { return }
                let category = categories.first(where: { $0.id == menuItem.categoryId })
                self?.form.setValues([
                    "name": menuItem.name,
                    "details": menuItem.details,
                    "price": Double(menuItem.price),
                    "category": category,
                    "maxCartQuantityPerUser": menuItem.maxCartQuantityPerUser
                ])
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        DataService.shared.categories$()
            .subscribeNext { [weak self] (categories) in
                guard let `self` = self else { return }
                guard let row = self.form.rowBy(tag: "category") as? PushRow<Category> else { return }
                row.options = categories
            }
            .disposed(by: disposeBag)
    }

    @objc func dismissButtonDidClick() {
        let name = form.values()["name"] as? String ?? ""
        if name.isEmpty {
            Task {
                await DataService.shared.deleteMenuItem(id: menuItemId)
            }
        }
        dismiss(animated: true, completion: nil)
    }

    func save() {
        let name: String = self.form.values()["name"] as? String ?? ""
        let details: String = self.form.values()["details"] as? String ?? ""
        let price: Float = Float(self.form.values()["price"] as? Double ?? 0)
        let categoryId: String? = {
            guard let category = self.form.values()["category"] as? Category else {
                return nil
            }
            return category.id
        }()
        if name.isEmpty {
            let alert = UIAlertController(title: "Name is Empty", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: false, completion: nil)
            return
        }

        let maxCartQuantityPerUser = self.form.values()["maxCartQuantityPerUser"] as? Int ?? nil
        Task {
            await DataService.shared.saveMenuItem(id: menuItemId, name: name, price: price, details: details, categoryId: categoryId, maxCartQuantityPerUser: maxCartQuantityPerUser)
        }
        self.dismiss(animated: true, completion: nil)
    }

    @objc func delete(sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Delete menu item?", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Yes, delete", style: .destructive, handler: { [weak self] (_) in
            guard let `self` = self else { return }
            Task {
                await DataService.shared.deleteMenuItem(id: self.menuItemId)
            }
            self.dismiss(animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if UIDevice.current.userInterfaceIdiom == .pad {
            alert.popoverPresentationController?.barButtonItem = sender
        }

        present(alert, animated: true, completion: nil)
    }

}
