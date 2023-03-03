import UIKit
import RxSwift
import Cartography
import Eureka

class EditMenuItemOptionsViewController: UIViewController {

    let tableView = UITableView()
    let menuItemId: String
    var disposeBag = DisposeBag()

    init(menuItemId: String) {
        self.menuItemId = menuItemId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        constrain(tableView, block: { tableView in tableView.fillToSuperView() })

        let addSectionBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        let editBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: nil, action: nil)
        navigationItem.rightBarButtonItems = [
            addSectionBarButtonItem,
            editBarButtonItem
        ]

        addSectionBarButtonItem
            .rx
            .tap
            .bind { [weak self, weak addSectionBarButtonItem] _ in
                guard let `self` = self else { return }
                let alert = UIAlertController(title: "Add option", message: .none, preferredStyle: .actionSheet)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    alert.popoverPresentationController?.barButtonItem = addSectionBarButtonItem
                }
                alert.addAction(UIAlertAction(title: "Single Option", style: .default, handler: { (_) in

                }))

                alert.addAction(UIAlertAction(title: "Multi Option", style: .default, handler: { (_) in

                }))

                alert.addAction(UIAlertAction(title: "Text Option", style: .default, handler: { (_) in

                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)

        editBarButtonItem
            .rx
            .tap
            .bind { [weak self] _ in
                let isEditing = self?.isEditing ?? false
                self?.tableView.setEditing(!isEditing, animated: true)
            }
            .disposed(by: disposeBag)
    }

}
