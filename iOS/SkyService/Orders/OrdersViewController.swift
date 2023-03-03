import UIKit
import Cartography
import RxSwift
import RxDataSources

class OrdersViewController: UIViewController, UITableViewDelegate, OrdersHeaderTableViewDelegate, OrdersSortViewDelegate, OrdersFilterDelegate, OrdersFooterTableViewDelegate {

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: CGRect.zero, style: .plain)
        tableView.register(OrdersHeaderTableViewCell.self, forCellReuseIdentifier: OrdersHeaderTableViewCell.REUSE_ID)
        tableView.register(OrdersFooterTableViewCell.self, forCellReuseIdentifier: OrdersFooterTableViewCell.REUSE_ID)
        return tableView
    }()
    private lazy var informationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.text = "Number of orders: 0"
        return label
    }()

//    lazy var listTypeToggle: UISegmentedControl = {
//        let control = UISegmentedControl(items: ["Processing", "Finished"])
//        control.selectedSegmentIndex = 0
//        return control
//    }()

    lazy var dateFormatter: DateFormatter = {
        let d = DateFormatter()
        d.timeStyle = .medium
        return d
    }()

    lazy var noOrdersLabel: UILabel = {
        let u = UILabel()
        u.text = "Waiting for orders"
        u.textAlignment = .center
        u.alpha = 0
        return u
    }()

    let viewModel: OrdersViewModel
    var dataSource: RxTableViewSectionedReloadDataSource<OrderSection>!
    var disposeBag = DisposeBag()
    var sortButton: UIBarButtonItem!
    var filterButton: UIBarButtonItem!

    init(userId: String? = DataService.shared.userId) {
        viewModel = Bundle.main.isCrew ? OrdersViewModel(userId: nil): OrdersViewModel(userId: userId)
        super.init(nibName: nil, bundle: nil)
        title = Bundle.main.isCrew ? "Orders" : "My Orders"
        tabBarItem.image = UIImage(named: "orders")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        view.addSubview(tableView)
        view.addSubview(informationLabel)
//        view.addSubview(listTypeToggle)
        view.addSubview(noOrdersLabel)
        tableView.tableFooterView = UIView()

        constrain(informationLabel, /*listTypeToggle,*/ tableView, noOrdersLabel) { informationLabel, /*listTypeToggle,*/ tableView, noOrdersLabel in
            informationLabel.top == informationLabel.superview!.safeAreaLayoutGuide.top
            informationLabel.left == informationLabel.superview!.left + 14
            informationLabel.right == informationLabel.superview!.right - 14

            tableView.top == informationLabel.bottom + 8
            tableView.left == tableView.superview!.left
            tableView.right == tableView.superview!.right
            tableView.bottom == tableView.superview!.bottom

            noOrdersLabel.left == noOrdersLabel.superview!.left + 16
            noOrdersLabel.right == noOrdersLabel.superview!.right - 16
            noOrdersLabel.centerY == noOrdersLabel.superview!.centerY
            noOrdersLabel.height == noOrdersLabel.superview!.height
        }

        if (Bundle.main.isCrew) {
            sortButton = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(goToSort))
            sortButton.tintColor = UIColor.lightGray
            filterButton = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: nil)
            filterButton.tintColor = UIColor.lightGray
            navigationItem.rightBarButtonItems = [
                sortButton,
                filterButton
            ]

             filterButton.rx.tap
                .bind(to: viewModel.filterButtonDidClick$)
                .disposed(by: disposeBag)

            viewModel.goToFilterViewController$
                .bind { [weak self] filter, categories in
                    guard let self = self else { return }
                    guard let topView = self.navigationController?.viewControllers.last else { return }
                    guard topView is Self else { return }
                    self.navigationController?.pushViewController(
                        OrdersFilterViewController(delegate: self, filter: filter), animated: true)
                }.disposed(by: disposeBag)
        }

        viewModel.categories$
            .distinctUntilChanged()
            .subscribeNext { [weak self] categories in
                guard let self = self else { return }
                guard let filter = try? self.viewModel.filterDidChange$.value() else { return }
                self.viewModel.filterDidChange$.onNext(filter)
            }.disposed(by: disposeBag)

        dataSource = RxTableViewSectionedReloadDataSource<OrderSection>(configureCell: { [weak self] (dataSource, tableView, indexPath, item) -> UITableViewCell in
            guard let self = self else { return UITableViewCell() }

            var cell: UITableViewCell
            switch item {
            case .header(order: let order, user: let user):
                let header = OrdersHeaderTableViewCell() // WORKAROUND: Not reusing cells to avoid order-status cache issue when sort
                header.delegate = self
                header.setupWith(order: order, user: user)
                header.segmentedControl.addTarget(self, action: #selector(self.segmentedControlValueChanged), for: .valueChanged)
                cell = header
            case .item(cartLineItem: let i):
                cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
                cell.backgroundColor = UIColor.systemGray6
                cell.selectionStyle = .none
                if let remainsCount = i.menuItem.remainsCount, Bundle.main.isCrew {
                    cell.textLabel?.text = "\(i.cartLineItem.quantity) \(i.menuItem.name) (remains: \(remainsCount))"
                } else {
                    cell.textLabel?.text = "\(i.cartLineItem.quantity) \(i.menuItem.name)"
                }
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 2)
                cell.textLabel?.numberOfLines = 0
                cell.detailTextLabel?.text = i.menuItem.details + self.createOptionsText(i.cartLineItem)
                cell.detailTextLabel?.numberOfLines = 0
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
            case .footer(order: let order):
                guard Bundle.main.isCrew else { return UITableViewCell() }
                let footerView = tableView.dequeueReusableCell(withIdentifier: OrdersFooterTableViewCell.REUSE_ID, for: indexPath) as! OrdersFooterTableViewCell
                footerView.setupWith(order: order)
                footerView.delegate = self
                cell = footerView
            }
            return cell
        })

        tableView
          .rx.setDelegate(self)
          .disposed(by: disposeBag)

        viewModel
            .orderSection$
            .do(onNext: { [weak self] (orders) in
                guard let self = self else { return }
                self.noOrdersLabel.alpha = orders.count == 0 ? 1 : 0
                self.informationLabel.text = "Number of orders: \(orders.count)"
            })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        viewModel
            .workspaceId$
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func deleteButtonDidClick(order: Order, button: PrimaryButton) {
        let alert = UIAlertController(title: "Delete Order?", message: nil, preferredStyle: .actionSheet)

        if UIDevice.current.userInterfaceIdiom == .pad {
            alert.popoverPresentationController?.sourceView = button
            alert.popoverPresentationController?.sourceRect = button.bounds
        }

        alert.addAction(UIAlertAction(title: "Yes, Delete", style: .destructive, handler: { (_) in
            DataService.shared.deleteOrder(orderId: order.id)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in

        }))

        self.present(alert, animated: true, completion: nil)
    }

    @objc func segmentedControlValueChanged(_ sender: OrderSegmentedControl) {
        let newStatus = Order.Status.allCases[sender.index]
        guard let orderId = sender.orderId else { return }
        DataService.shared.changeOrderStatus(orderId: orderId, status: newStatus)
    }

    @objc private func listTypeChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            viewModel.listTypeDidChange$.onNext(.processing)
        } else {
            viewModel.listTypeDidChange$.onNext(.finished)
        }
    }

    func attemptToDeleteOrder(orderId: String) {
        let alert = UIAlertController(title: "Delete Order?", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Yes, Delete", style: .destructive, handler: { (_) in
            DataService.shared.deleteOrder(orderId: orderId)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    @objc private func goToSort() {
        guard let currentType = try? viewModel.sortTypeDidChange$.value() else { return }
        navigationController?.pushViewController(
            OrdersSortViewController(delegate: self, currentType: currentType), animated: true)
    }

    func sortTypeDidChange(type: Order.SortType) {
        viewModel.sortTypeDidChange$.onNext(type)
        if type != .orderedTime {
            sortButton.tintColor = UIColor.primaryColor
            sortButton.style = .done
        } else {
            sortButton.tintColor = UIColor.lightGray
            sortButton.style = .plain
        }
        tableView.reloadData()
    }

    func filterDidChange(_ filter: Order.Filter) {
        viewModel.filterDidChange$.onNext(filter)
        if filter.isAnyFilterActive {
            filterButton.tintColor = UIColor.primaryColor
            filterButton.style = .done
        } else {
            filterButton.tintColor = UIColor.lightGray
            filterButton.style = .plain
        }
        tableView.reloadData()
    }

    func crewNoteEditButtonDidClick(order: Order) {
        let alert = UIAlertController(title: "Crew Note", message: " \(String(repeating: "\n", count: 7))", preferredStyle: .alert)

        let textView = UITextView()
        textView.addDoneButtonInKeyboard()
        textView.text = order.crewNote
        textView.font =  UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .regular)
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.layer.cornerRadius = 6

        alert.view.addSubview(textView)
        constrain(textView) { textView in
            textView.top == textView.superview!.top + 60
            textView.left == textView.superview!.left + 10
            textView.right == textView.superview!.right - 10
            textView.bottom == textView.superview!.bottom - 60
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            DataService.shared.updateCrewNote(order: order, newNote: textView.text)
        })
        present(alert, animated: false, completion: nil)
    }

    private func createOptionsText(_ item: CartLineItem) -> String {
        guard !item.options.isEmpty else { return "" }
        var text = """


        OPTIONS:

        """

        item.options.forEach {
            text.append("- \($0)\n")
        }
        return text
    }
}
