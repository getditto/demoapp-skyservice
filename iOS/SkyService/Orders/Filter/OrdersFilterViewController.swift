//
//  OrdersFilterViewController.swift
//  SkyService
//
//  Created by kndoshn on 2021/05/09.
//

import UIKit
import Cartography

protocol OrdersFilterDelegate: AnyObject {
    func filterDidChange(_ filter: Order.Filter)
}

final class OrdersFilterViewController: UIViewController, OrdersFilterDetailDelegate {

    private let tableView = UITableView()
    private weak var delegate: OrdersFilterDelegate?
    private let filter: Order.Filter

    init(delegate: OrdersFilterDelegate, filter: Order.Filter) {
        self.delegate = delegate
        self.filter = filter
        super.init(nibName: nil, bundle: nil)
        title = "Orders Filter"
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Reset", style: .done, target: self, action: #selector(resetFilter))

        constrain(tableView) { tableView in
            tableView.fillToSuperView()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let selected = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selected, animated: true)
        }
    }

    private func cellTitle(indexPath: IndexPath) -> String {
        switch indexPath.row {
        case 0: return "Seat Abreasts"
        case 1: return "Order Statuses"
        case 2: return "Order User Type"
        default: return ""
        }
    }

    private func cellTitleColor(indexPath: IndexPath) -> UIColor {
        switch indexPath.row {
        case 0: return filter.isSeatAbreastFilterActive ? UIColor.primaryColor: UIColor.lightGray
        case 1: return filter.isOrderStatusFilterActive ? UIColor.primaryColor: UIColor.lightGray
        case 2: return filter.isOrderUserTypeFilterActive ? UIColor.primaryColor: UIColor.lightGray
        default: return UIColor.lightGray
        }
    }

    @objc private func resetFilter() {
        delegate?.filterDidChange(filter.reset())
        tableView.reloadData()
    }

    func filterDidChange(filter: Order.Filter) {
        delegate?.filterDidChange(filter)
        tableView.reloadData()
    }
}

extension OrdersFilterViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = cellTitle(indexPath: indexPath)
        cell.textLabel?.textColor = cellTitleColor(indexPath: indexPath)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let title = tableView.cellForRow(at: indexPath)?.textLabel?.text else { return }
        let type: OrdersFilterDetailViewController.FilterType
        switch title {
        case OrdersFilterDetailViewController.FilterType.seatAbreast.title:
            type = .seatAbreast
        case OrdersFilterDetailViewController.FilterType.orderStatus.title:
            type = .orderStatus
        case OrdersFilterDetailViewController.FilterType.orderUserType.title:
            type = .orderUserType
        default: print("unknown type"); type = .seatAbreast
        }
        navigationController?.pushViewController(
            OrdersFilterDetailViewController(filter: filter, type: type, delegate: self), animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
}
