import UIKit
import Cartography
import RxSwift
import RxDataSources

class AddToCartButton: UIButton {

    var menuItem: MenuItemWithCartLineItems!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setTitle("+", for: .normal)
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.backgroundColor = .white
        self.layer.borderColor = UIColor.primaryColor.cgColor
        self.layer.borderWidth =  1.0
        self.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
        self.setTitleColor(.primaryColor, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class PassengerMenuViewController: UIViewController, SettingsViewControllerDelegate {

    var disposeBag = DisposeBag()

    private lazy var welcomeMessage: WelcomeMessageButton = {
        WelcomeMessageButton(isCrew: Bundle.main.isCrew)
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(PassengerMenuTableViewCell.self, forCellReuseIdentifier: PassengerMenuTableViewCell.REUSE_ID)
        // we add some bottom inset so that we can give the cart button some room
        // this room will prevent the cart button from hiding any more UITableViewCells
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        return tableView
    }()

    lazy var goToCartButton: PrimaryButton = {
        let button = PrimaryButton()
        button.setTitle("Go to cart", for: .normal)
        button.alpha = 0
        return button
    }()

    var dataSource: RxTableViewSectionedAnimatedDataSource<SectionOfPassengerMenuItems>!

    let viewModel: PassengerMenuViewModel
    
    init(userId: String) {
        self.viewModel = PassengerMenuViewModel(userId: userId)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.backgroundColor = Bundle.main.isCrew ? .black: .white
        view.backgroundColor = Bundle.main.isCrew ? .black: .white
        DataService.shared.startSyncing()
        self.navigationItem.title = "Menu"
        view.addSubview(tableView)
        view.addSubview(goToCartButton)
        view.addSubview(welcomeMessage)

        constrain(welcomeMessage, tableView, goToCartButton) { (welcomeMessage, tableView, goToCartButton) in
            welcomeMessage.top == welcomeMessage.superview!.safeAreaLayoutGuide.top
            welcomeMessage.left == welcomeMessage.superview!.left + 14
            welcomeMessage.right == welcomeMessage.superview!.right - 14

            tableView.top == welcomeMessage.bottom + 8
            tableView.left == tableView.superview!.left
            tableView.right == tableView.superview!.right
            tableView.bottom == tableView.superview!.bottom

            goToCartButton.left == goToCartButton.superview!.left + 16
            goToCartButton.right == goToCartButton.superview!.right - 16
            goToCartButton.bottom == goToCartButton.superview!.safeAreaLayoutGuide.bottom - 16
            goToCartButton.height == 54
        }

        let settingsBarButtonItem = UIBarButtonItem(image: UIImage(named: "settings"), style: .plain, target: nil, action: nil)
        if !Bundle.main.isCrew {
            navigationItem.leftBarButtonItem = settingsBarButtonItem
        }

        let ordersBarButtonItem = UIBarButtonItem(title: "Orders", style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = ordersBarButtonItem

        ordersBarButtonItem
            .rx
            .tap
            .bind { [weak self] _ in
                self?.navigationController?.pushViewController(OrdersViewController(), animated: true)
            }
            .disposed(by: disposeBag)

        settingsBarButtonItem
            .rx
            .tap
            .bind { [weak self] _ in
                guard let self = self else { return }
                let settingsViewController = SettingsViewController(shouldShowDismissButton: true)
                settingsViewController.delegate = self
                let nav = UINavigationController(rootViewController: settingsViewController)
                self.present(nav, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)

        goToCartButton
            .rx
            .tap
            .bind(to: viewModel.cartButtonDidClick$)
            .disposed(by: disposeBag)

        DataService.shared
            .welcomeMessage$()
            .bind(onNext: { [weak self] message in
                guard let self = self else { return }
                self.welcomeMessage.setTitle(message, for: .normal)
            }).disposed(by: disposeBag)

        dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfPassengerMenuItems>(configureCell: { [weak self] (dataSource, tableView, indexPath, item) -> UITableViewCell in
            guard let self = self else { return UITableViewCell() }

            let cell: PassengerMenuTableViewCell = tableView.dequeueReusableCell(withIdentifier: PassengerMenuTableViewCell.REUSE_ID) as! PassengerMenuTableViewCell
            cell.addButton.rx.tap
                .map({ _ in item })
                .bind(to: self.viewModel.addButtonTappedSubject$)
                .disposed(by: cell.disposeBag)
            if Bundle.main.isCrew, let remainsCount = item.menuItem.remainsCount {
                cell.textLabel?.text = "(\(remainsCount)) " + item.menuItem.name
            } else {
                cell.textLabel?.text = item.menuItem.name
            }
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 3)
            cell.detailTextLabel?.text = item.menuItem.details
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)

            return cell
        })

        dataSource.titleForHeaderInSection = { dataSource, index in
            let section = dataSource.sectionModels[index]
            return section.category?.name ?? "Uncategorised"
        }

        viewModel
            .sectionsOfPassengerMenuItems$
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        viewModel
            .presentMenuOptionsViewController$
            .bind { [weak self] menuItemId, userId in
                guard let `self` = self else { return }
                let nav = UINavigationController(rootViewController: ItemCustomizationViewController(menuItemId: menuItemId, userId: userId))
                self.present(nav, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)

        viewModel
            .titleView$
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)

        viewModel
            .canShowCartButton$
            .bind { [weak self] canShow in
                UIView.animate(withDuration: 0.1) {
                    self?.goToCartButton.alpha = canShow ? 1 : 0
                }
            }.disposed(by: disposeBag)

        viewModel
            .goToCart$
            .bind { [weak self] userId in
                guard let `self` = self else { return }
                self.navigationController?.pushViewController(CartViewController(userId: userId), animated: true)
            }
            .disposed(by: disposeBag)

    }

    deinit {
        DataService.shared.stopSyncing()
        disposeBag = DisposeBag()
    }

    func logoutButtonDidClick() {
        DataService.shared.stopSyncing()
        DataService.shared.evictAllData()
        UserDefaults.standard.workspaceId = nil
        let loginNav = UINavigationController(rootViewController: LoginViewController())
        (UIApplication.shared.delegate as! AppDelegate).setRootViewController(loginNav, animated: true)
    }
}
