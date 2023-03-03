//
//  OrdersFilterDetailViewController.swift
//  SkyService
//
//  Created by kndoshn on 2021/05/10.
//

import UIKit
import Cartography

protocol OrdersFilterDetailDelegate: AnyObject {
    func filterDidChange(filter: Order.Filter)
}

final class OrdersFilterDetailViewController: UIViewController {

    struct Cell {
        let title: String
        let hasCheck: Bool
    }

    enum FilterType {
        case seatAbreast
        case orderStatus
        case orderUserType

        var title: String {
            switch self {
            case .seatAbreast: return "Seat Abreasts"
            case .orderStatus: return "Order Statuses"
            case .orderUserType: return "Order User Type"
            }
        }

        func cells(filter: Order.Filter) -> [Cell] {
            switch self {
            case .seatAbreast:
                return ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K"].map {
                    Cell(title: $0, hasCheck: filter.seatAbreast.contains($0))
                }
            case .orderStatus:
                return Order.Status.allCases.map {
                    Cell(title: $0.humanReadable, hasCheck: filter.orderStatus.contains($0))
                }
            case .orderUserType:
                return [
                    Cell(title: "By Crews", hasCheck: filter.orderUserType.contains(.crew)),
                    Cell(title: "By Passengers", hasCheck: filter.orderUserType.contains(.passenger))]
            }
        }
    }

    private var filter: Order.Filter
    private let type: FilterType
    private let tableView = UITableView()
    private weak var delegate: OrdersFilterDetailDelegate?

    var cells: [Cell] { type.cells(filter: filter) }

    init(filter: Order.Filter, type: FilterType, delegate: OrdersFilterDetailDelegate) {
        self.filter = filter
        self.type = type
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        title = type.title
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

        constrain(tableView) { tableView in
            tableView.fillToSuperView()
        }
    }
}

extension OrdersFilterDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let cellInfo = cells[indexPath.row]
        cell.textLabel?.text = cellInfo.title
        cell.accessoryType = cellInfo.hasCheck ? .checkmark: .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        filter = update(filter: filter, indexPath: indexPath)
        delegate?.filterDidChange(filter: filter)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    private func update(filter: Order.Filter, indexPath: IndexPath) -> Order.Filter {
        let selected = cells[indexPath.row]
        switch type {
        case .seatAbreast: return updateSeatAbreast(filter: filter, selected: selected)
        case .orderStatus: return updateOrderStatus(filter: filter, selected: selected)
        case .orderUserType: return updateOrderUserType(filter: filter, selected: selected)
        }
    }

    private func updateSeatAbreast(filter: Order.Filter, selected: Cell) -> Order.Filter {
        selected.hasCheck ?
            filter.seatAbreast.removeAll(where: { $0 == selected.title }):
            filter.seatAbreast.append(selected.title)
        return filter
    }

    private func updateOrderStatus(filter: Order.Filter, selected: Cell) -> Order.Filter {
        guard let orderStatus = Order.Status.allCases.first(where: { $0.humanReadable == selected.title }) else { return filter }
        selected.hasCheck ?
            filter.orderStatus.removeAll(where: { $0.humanReadable == selected.title }):
            filter.orderStatus.append(orderStatus)
        return filter
    }

    private func updateOrderUserType(filter: Order.Filter, selected: Cell) -> Order.Filter {
        if selected.title == "By Crews" {
            selected.hasCheck ?
                filter.orderUserType.removeAll(where: { $0 == .crew }):
                filter.orderUserType.append(.crew)
        } else {
            selected.hasCheck ?
                filter.orderUserType.removeAll(where: { $0 == .passenger }):
                filter.orderUserType.append(.passenger)
        }
        return filter
    }
}
