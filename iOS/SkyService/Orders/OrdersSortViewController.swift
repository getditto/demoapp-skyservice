//
//  OrdersSortViewController.swift
//  SkyService
//
//  Created by kndoshn on 2021/05/09.
//

import UIKit
import Cartography

protocol OrdersSortViewDelegate: AnyObject {
    func sortTypeDidChange(type: Order.SortType)
}

final class OrdersSortViewController: UIViewController {

    private let tableView = UITableView()
    private weak var delegate: OrdersSortViewDelegate?
    private let currentType: Order.SortType

    init(delegate: OrdersSortViewDelegate, currentType: Order.SortType) {
        self.delegate = delegate
        self.currentType = currentType
        super.init(nibName: nil, bundle: nil)
        title = "Orders Sort"
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

extension OrdersSortViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = Order.SortType.allCases[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = type.name

        if type == currentType {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedType = Order.SortType.allCases[indexPath.row]

        tableView.visibleCells.forEach {
            if $0.textLabel != nil && $0.textLabel!.text == selectedType.name {
                $0.accessoryType = .checkmark
            } else {
                $0.accessoryType = .none
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)

        delegate?.sortTypeDidChange(type: selectedType)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Order.SortType.allCases.count
    }
}

