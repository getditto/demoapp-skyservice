import UIKit
import Eureka
import RxSwift

class ItemCustomizationViewController: FormViewController {

    var viewModel: ItemCustomizationViewModel
    var disposeBag = DisposeBag()
    
    deinit {
        disposeBag = DisposeBag()
    }

    init(menuItemId: String, userId: String) {
        self.viewModel = ItemCustomizationViewModel(menuItemId: menuItemId, userId: userId)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let closeNavigationBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: nil, action: nil)
        self.navigationItem.leftBarButtonItem = closeNavigationBarButtonItem

        form
            +++ Section("details") { $0.tag = "detailsSection" }
            <<< TextAreaRow("details") { $0.disabled = true }
            +++ Section() { $0.tag = "addToCartSection" }
            <<< QuantityStepperRow("quantity").counterButtonDidClick({ _, value in
                self.viewModel.counterButtonDidClick$.onNext(value)
            })
            <<< UpdateCartButtonRow("addToCart") { row in
                row.title = "Add to Cart"
            }.onTap({ [weak self] cell, row in
                guard let `self` = self else { return }
                self.viewModel.addButtonDidClick$.onNext(self.form.values())
            })

        closeNavigationBarButtonItem
            .rx
            .tap
            .bind(to: viewModel.closeButtonDidClick$)
            .disposed(by: disposeBag)

        viewModel
            .dismissViewController$
            .bind { [weak self] _ in
                self?.dismiss(animated: true, completion: { () in
                    self?.disposeBag = DisposeBag()
                })
            }
            .disposed(by: disposeBag)

        viewModel
            .formStructure$
            .distinctUntilChanged()
            .bind { formStructure in
                self.title = formStructure.name
                self.form.setValues([
                    "details": formStructure.details,
                    "quantity": formStructure.quantity
                ])
                self.form.rowBy(tag: "details")?.reload()
                self.form.rowBy(tag: "quantity")?.reload()
            }
            .disposed(by: disposeBag)

        viewModel
            .options$
            .distinctUntilChanged()
            .bind { options in
                let detailsSection: Section = self.form.sectionBy(tag: "detailsSection")!
                let addToCartSection: Section = self.form.sectionBy(tag: "addToCartSection")!
                let detailSectionIndex = self.form.allSections.firstIndex(of: detailsSection)!
                let addToCartSectionIndex = self.form.allSections.firstIndex(of: addToCartSection)!
                let optionsRange = detailSectionIndex + 1..<addToCartSectionIndex
                self.form.removeSubrange(optionsRange)

                var indexToInsert = detailSectionIndex + 1
                for option in options.sorted(by: { $0.ordinal < $1.ordinal }) {
                    switch option.type {
                    case .multiple:
                        let selectableSection = SelectableSection<ListCheckRow<String>>(option.label, selectionType: SelectionType.multipleSelection) {
                            $0.tag = "option::\(option.id)"
                        }
                        for allowedValue in option.allowedValues {
                            selectableSection <<< ListCheckRow<String>(allowedValue){ listRow in
                                listRow.tag = "option::\(option.id)::\(allowedValue)"
                                listRow.title = allowedValue
                                listRow.selectableValue = allowedValue
                                listRow.value = nil
                            }
                        }
                        self.form.insert(selectableSection, at: indexToInsert)
                        indexToInsert = indexToInsert + 1
                    case .single:
                        let selectableSection = SelectableSection<ListCheckRow<String>>(option.label, selectionType: .singleSelection(enableDeselection: true)) {
                            $0.tag = "option::\(option.id)"
                        }
                        for allowedValue in option.allowedValues {
                            selectableSection <<< ListCheckRow<String>(allowedValue){ listRow in
                                listRow.tag = "option::\(option.id)::\(allowedValue)"
                                listRow.title = allowedValue
                                listRow.selectableValue = allowedValue
                                listRow.value = nil
                            }
                        }
                        self.form.insert(selectableSection, at: indexToInsert)
                        indexToInsert = indexToInsert + 1
                    case .text:
                        let textSection = Section() {
                            $0.tag = "option::\(option.id)"
                        }
                        <<< CustomTextAreaRow(option.id, { row in
                            row.tag = "option::\(option.id)"
                            row.title = option.label
                        })
                        self.form.insert(textSection, at: indexToInsert)
                        indexToInsert = indexToInsert + 1
                    }
                }

            }
            .disposed(by: disposeBag)
    }
}
