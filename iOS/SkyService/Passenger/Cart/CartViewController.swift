import UIKit
import Cartography
import RxSwift
import RxDataSources
import RxUIAlert

class CartViewController: UIViewController {

    var disposeBag = DisposeBag()

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(CartLineItemTableViewCell.self, forCellReuseIdentifier: CartLineItemTableViewCell.REUSE_ID)
        // we add some bottom inset so that we can give the cart button some room
        // this room will prevent the cart button from hiding any more UITableViewCells
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        return tableView;
    }()

    lazy var checkoutButton: PrimaryButton = {
        let button = PrimaryButton()
        button.setTitle("Submit Order", for: .normal)
        button.alpha = 0
        return button
    }()

    let viewModel: CartViewModel

    init(userId: String = DataService.shared.userId) {
        self.viewModel = CartViewModel(userId: userId)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cart"
        view.addSubview(tableView)
        view.addSubview(checkoutButton)
        constrain(tableView, checkoutButton) { tableView, checkoutButton in
            tableView.fillToSuperView()
            checkoutButton.left == checkoutButton.superview!.left + 16
            checkoutButton.right == checkoutButton.superview!.right - 16
            checkoutButton.bottom == checkoutButton.superview!.safeAreaLayoutGuide.bottom - 16
            checkoutButton.height == 54
        }

        let trashBarButtonItem = UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = trashBarButtonItem

        trashBarButtonItem
            .rx
            .tap
            .flatMapLatest({ [weak self] _ -> Observable<OutputAction> in
                guard let `self` = self else { return Observable.empty() }
                return self.rx.alert(title: "Are you sure you want to clear your cart?", message: nil, actions: [
                    AlertAction(title: "Yes, clear", type: 1, style: .destructive),
                    AlertAction(title: "Cancel", type: 0, style: .cancel),
                ], preferredStyle: .alert, vc: self)
            })
            .filter({ outputAction in
                return outputAction.index == 1
            })
            .map({ _ in Void() })
            .bind(to: viewModel.clearCartButtonDidClick$)
            .disposed(by: disposeBag)

        checkoutButton
            .rx
            .tap
            .bind(to: viewModel.checkoutButtonDidClick$)
            .disposed(by: disposeBag)

        tableView
            .rx
            .modelDeleted(CartLineItemWithMenuItem.self)
            .bind(to: viewModel.cartLineItemWithMenuItemDeleted$)
            .disposed(by: disposeBag)

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfCartLineItemsWithMenuItem> { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: CartLineItemTableViewCell.REUSE_ID, for: indexPath) as! CartLineItemTableViewCell
            cell.quantityLabel.text = "\(item.cartLineItem.quantity)"
            cell.contentsLabel.attributedText = {
                let m = NSMutableAttributedString()
                m.append(NSAttributedString(string: item.menuItem.name, attributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
                ]))
                for option in item.cartLineItem.options {
                    m.append(NSAttributedString(string: "\n\u{2022} \(option)", attributes: [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize)
                    ]))
                }
                return m
            }()
            return cell
        }

        dataSource.canEditRowAtIndexPath = { dataSource, indexPath  in
            return true
        }

        viewModel
            .checkoutButtonVisible$
            .bind { [weak self] isVisible in
                UIView.animate(withDuration: 0.15) {
                    self?.checkoutButton.alpha = isVisible ? 1 : 0
                }
            }
            .disposed(by: disposeBag)

        DataService.shared.canOrder$()
            .distinctUntilChanged()
            .bind { [weak self] canOrder in
                self?.checkoutButton.changeEnabled(canOrder)
            }
            .disposed(by: disposeBag)

        viewModel.sectionsOfCartItemsWithMenuItem$
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        viewModel.popViewController$
            .bind { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }.disposed(by: disposeBag)

        viewModel
            .finishedDeletingCartLineItemWithMenuItem$
            .bind { }
            .disposed(by: disposeBag)

        viewModel.goToOrdersController$
            .bind { [weak self] in
                guard let self = self else { return }
                if Bundle.main.isCrew { // order for users
                    self.dismiss(animated: true)
                    AppDelegate.crewTabController?.goToController(OrdersViewController.self)
                } else {
                    self.navigationController?.popToRootViewController(animated: true)
                    self.navigationController?.pushViewController(OrdersViewController(), animated: true)
                }
            }
            .disposed(by: disposeBag)
    }

}


extension CartViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let testAction = UIContextualAction(style: .destructive, title: "Remove") { (_, _, completionHandler) in
            self.tableView.dataSource?.tableView!(self.tableView, commit: .delete, forRowAt: indexPath)
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [testAction])
    }
}
