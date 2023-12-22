import UIKit
import RxSwift
import Eureka

class EditCategoryViewController: FormViewController {

    var disposeBag = DisposeBag()
    let categoryId: String?

    init(categoryId: String? = nil) {
        self.categoryId = categoryId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.categoryId == nil ? "Create Category": "Edit Category"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonDidClick))

        form
            +++ Section()
            <<< TextRow("name") { row in
                row.title = "Category Name:"
            }
            <<< CustomTextAreaRow("details") { row in
                row.title = "Details: "
            }
            <<< SwitchRow("isCrewOnly") { row in
                row.title = "Crew Only"
            }
            +++ Section()
            <<< ButtonRow("save") { row in
                row.title = "Save"
            }.onCellSelection({ [weak self] (_, _) in
                guard let `self` = self else { return }
                self.saveButtonDidClick()
            })
            +++ Section()
            <<< ButtonRow("delete") { row in
                row.title = "Delete Category"
                row.hidden = Condition(booleanLiteral: true)
                row.cell.tintColor = .systemRed
            }.onCellSelection({ [weak self] (_, _) in
                guard let `self` = self else { return }
                self.attemptToDelete()
            })

        if let categoryId = categoryId {
            DataService.shared.categoryById$(id: categoryId)
                .subscribeNext { [weak self] (category) in
                    guard let `self` = self else { return }
                    guard let category = category else {
                        self.dismiss(animated: true, completion: nil)
                        return
                    }
                    self.form.setValues([
                        "name": category.name,
                        "details": category.details,
                        "isCrewOnly": category.isCrewOnly
                    ])
                    self.form.rowBy(tag: "delete")?.hidden = Condition(booleanLiteral: false)
                    self.form.rowBy(tag: "delete")?.evaluateHidden()
                    self.tableView.reloadData()
                }
                .disposed(by: disposeBag)
        }
    }

    @objc func cancelButtonDidClick() {
        self.dismiss(animated: true, completion: nil)
    }

    func attemptToDelete() {
        let alert = UIAlertController(title: "Are you sure?", message: "This will delete the category but not the menu items", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes, delete", style: .destructive, handler: { [weak self] (_) in
            guard let `self` = self else { return }
            guard let categoryId = self.categoryId else {
                self.dismiss(animated: true, completion: nil)
                return
            }
            self.dismiss(animated: true) {
                Task {
                    await DataService.shared.deleteCategory(id: categoryId)
                }
            }

        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func saveButtonDidClick() {
        let name: String = (form.values()["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let details = form.values()["details"] as? String ?? ""
        let isCrewOnly = form.values()["isCrewOnly"] as? Bool ?? false
        if name.count < 3 {
            let alert = UIAlertController(title: "Uh oh", message: "Please enter a name longer than 3 characters.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        if let categoryId = self.categoryId {
            Task {
                await DataService.shared.updateCategory(id: categoryId, name: name, details: details, isCrewOnly: isCrewOnly)
            }
        } else {
            Task {
                await DataService.shared.createCategory(name: name, details: details, isCrewOnly: isCrewOnly)
            }
        }
        self.dismiss(animated: true, completion: nil)
    }

}
