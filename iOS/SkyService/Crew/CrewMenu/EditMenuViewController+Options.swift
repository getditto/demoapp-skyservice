import UIKit
import Eureka
import RxSwift

extension EditMenuItemViewController {

    func setupOptionsSection() {
        form +++
            Section("Options") { s in
                s.tag = "options"
            }
            +++
            Section()
            <<< ButtonRow("addOption", { (row) in
                row.title = "Add Option"
                row.cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
                row.cell.tintColor = .systemPurple
            }).onCellSelection({ [weak self] (cell, row) in
                guard let `self` = self else { return }
                let alert = UIAlertController(title: "Add Option", message: .none, preferredStyle: .actionSheet)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    alert.popoverPresentationController?.sourceView = self.view
                    alert.popoverPresentationController?.sourceRect = cell.frame
                }

                alert.addAction(UIAlertAction(title: "Single Selection Option", style: .default, handler: { _ in
                    Task {
                        await DataService.shared.createMenuItemOption(menuItemId: self.menuItemId, type: .single)
                    }
                }))

                alert.addAction(UIAlertAction(title: "Multi Selection Option", style: .default, handler: { (_) in
                    Task {
                        await DataService.shared.createMenuItemOption(menuItemId: self.menuItemId, type: .multiple)
                    }
                }))

                alert.addAction(UIAlertAction(title: "Text Option", style: .default, handler: { (_) in
                    Task {
                        await DataService.shared.createMenuItemOption(menuItemId: self.menuItemId, type: .text)
                    }
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in

                }))

                self.present(alert, animated: true, completion: nil)
            })


        DataService.shared
            .menuItemOptions(self.menuItemId)
            .distinctUntilChanged()
            .bind { [weak self] options in
                guard let `self` = self, let section = self.form.sectionBy(tag: "options") else { return }
                section.removeAll()
                for option in options {
                    let row = MenuItemOptionPushRow(option.id, { (row) in
                        row.title = option.type.formTitle
                        row.value = option
                        let deleteAction = SwipeAction(style: .destructive, title: "Delete") { (action, row, completionHandler) in
                            Task {
                                await DataService.shared.deleteMenuItemOption(menuItemOptionId: option.id)
                            }
                            completionHandler?(true)
                        }
                        row.trailingSwipe.actions = [deleteAction]
                    })
                    section.append(row)

                }
            }
            .disposed(by: disposeBag)
    }

}
