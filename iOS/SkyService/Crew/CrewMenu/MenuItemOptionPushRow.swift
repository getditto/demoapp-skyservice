import Eureka
import RxSwift

final class MenuItemOptionPushRow: OptionsRow<PushSelectorCell<MenuItemOption>>, PresenterRowType, RowType {

    public typealias PresenterRow = MenuItemOptionRowViewController

    /// Defines how the view controller will be presented, pushed, etc.
    public var presentationMode: PresentationMode<PresenterRow>?

    /// Will be called before the presentation occurs.
    public var onPresentCallback: ((FormViewController, PresenterRow) -> Void)?

    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .show(controllerProvider: ControllerProvider.callback { return MenuItemOptionRowViewController(){ _ in } }, onDismiss: { vc in _ = vc.navigationController?.popViewController(animated: true) })

        displayValueFor = {
            guard let menuItemOption = $0 else { return "" }
            return menuItemOption.label
        }
    }

    /**
     Extends `didSelect` method
     */
    override func customDidSelect() {
        super.customDidSelect()
        guard let presentationMode = presentationMode, !isDisabled else { return }
        if let controller = presentationMode.makeController() {
            controller.row = self
            controller.title = selectorTitle ?? controller.title
            onPresentCallback?(cell.formViewController()!, controller)
            presentationMode.present(controller, row: self, presentingController: self.cell.formViewController()!)
        } else {
            presentationMode.present(nil, row: self, presentingController: self.cell.formViewController()!)
        }
    }
}


class MenuItemOptionRowViewController: FormViewController, TypedRowControllerType {

    var row: RowOf<MenuItemOption>!

    var onDismissCallback: ((UIViewController) -> Void)?

    var disposeBag = DisposeBag()

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    convenience public init(_ callback: ((UIViewController) -> ())?){
        self.init(nibName: nil, bundle: nil)
        onDismissCallback = callback
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        form
            +++ Section()
            <<< LabelRow("menuItemName") { row in
                row.title = "Menu Item:"
            }
            +++ Section()
            <<< LabelRow("type") { row in
                row.title = "Option Type:"
            }
            +++ Section()
            <<< TextRow("label", { (row) in
                row.title = "Option label:"
            })
            <<< CustomTextAreaRow("details", { (row) in
                row.title = "Option details:"
            })
            <<< SwitchRow("isRequired", { (row) in
                row.title = "Required:"
            })

        form
            +++
            MultivaluedSection(multivaluedOptions: [.Insert, .Delete, .Reorder],
                               header: "Allowed Values") { section in
                section.tag = "allowedValues"
                section.multivaluedRowToInsertAt = { _ in
                    TextRow { _ in

                    }
                }
            }

        guard let menuItemOptionId: String = self.row?.value?.id else { return }

        form
            +++ Section()
            <<< ButtonRow("delete") { row in
                row.title = "Delete"
                row.cell.tintColor = .systemRed
            }.onCellSelection({ [weak self] (_, _) in
                let alert = UIAlertController(title: "Delete this option?", message: "This will not affect existing orders", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Yes, delete", style: .destructive, handler: { [weak self, weak row = self?.row] (_) in
                    guard let `self` = self, let value = row?.value else { return }
                    DataService.shared.deleteMenuItemOption(menuItemOptionId: value.id)
                    self.navigationController?.popViewController(animated: true)
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

                self?.present(alert, animated: true, completion: nil)
            })


        DataService.shared.menuItemOptionById(menuItemOptionId)
            .take(1)
            .filterNil()
            .flatMapLatest({ DataService.shared.menuItemById$($0.menuItemId) })
            .filterNil()
            .map({ $0.name })
            .bind { [weak self] menuItemName in
                self?.form.setValues([
                    "menuItemName": menuItemName
                ])
            }
            .disposed(by: disposeBag)


        DataService.shared.menuItemOptionById(menuItemOptionId)
            .take(1)
            .bind { [weak self] option in
                guard let option = option else {
                    self?.navigationController?.popViewController(animated: true)
                    return
                }
                guard var section = self?.form.sectionBy(tag: "allowedValues") as? MultivaluedSection else { return }
                self?.form.setValues([
                    "type": option.type.rawValue,
                    "label": option.label,
                    "details": option.details,
                    "isRequired": option.isRequired
                ])
                section.hidden = Condition(booleanLiteral: option.type == .text)
                for (index, allowedValue) in option.allowedValues.reversed().enumerated() {
                    let textRow = TextRow("\(index)") { (row) in
                        row.value = allowedValue
                    }
                    section.insert(textRow, at: 0)
                }
                self?.tableView.reloadData()
            }
            .disposed(by: disposeBag)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let menuItemOptionId = self.row.value?.id else { return }
        let label: String = self.form.values()["label"] as? String ?? ""
        let details: String = self.form.values()["details"] as? String ?? ""
        let isRequired: Bool = self.form.values()["isRequired"] as? Bool ?? false
        let allowedValues = self.form.sectionBy(tag: "allowedValues")?.allRows.compactMap({ $0 as? TextRow })
                .compactMap({ $0.value }) ?? []

        DataService.shared.saveMenuItemOption(menuItemOptionId: menuItemOptionId, label: label, details: details, isRequired: isRequired, allowedValues: allowedValues)


    }

    deinit {
        disposeBag = DisposeBag()
    }

}
