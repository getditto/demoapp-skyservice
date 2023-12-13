import UIKit
import Cartography
import RxSwift
import RxDataSources

final class PassengersViewController: UIViewController, UITableViewDelegate {

    let tableView: UITableView = UITableView()
    private lazy var informationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.text = "Total passengers: 0"
        return label
    }()

    var dataSource: RxTableViewSectionedAnimatedDataSource<SectionOfUser>!
    var disposeBag = DisposeBag()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Passengers"
        tabBarItem.image = UIImage(named: "users")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true

        view.addSubview(informationLabel)
        view.addSubview(tableView)

        constrain(informationLabel, tableView) { informationLabel, tableView in
            informationLabel.top == informationLabel.superview!.safeAreaLayoutGuide.top
            informationLabel.left == informationLabel.superview!.left + 14
            informationLabel.right == informationLabel.superview!.right - 14

            tableView.top == informationLabel.bottom + 8
            tableView.left == tableView.superview!.left
            tableView.right == tableView.superview!.right
            tableView.bottom == tableView.superview!.bottom
        }

        dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfUser> { (dataSource, tableView, indexPath, item) -> UITableViewCell in
            var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: "Cell")
            if (cell == nil) {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
                cell.accessoryView = {
                    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 45, height: 35))
                    label.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
                    label.adjustsFontSizeToFitWidth = true
                    return label
                }()
            }
            cell.textLabel?.text = item.name
            cell.detailTextLabel?.text = item.isManuallyCreated ? "Created by Crew" : "Logged In by User"
            cell.detailTextLabel?.textColor = .secondaryLabel
            (cell.accessoryView as! UILabel).text = item.seat
            return cell
        }

        tableView.delegate = self

        DataService.shared.users$()
            .map({ (users) -> [SectionOfUser] in
                var sections = [SectionOfUser]()
                // Passengers are sorted by seat numbers
                let passengers = users
                    .filter({ $0.role == .passenger })
                    .sorted(by: { $0.seatAbreast ?? "" < $1.seatAbreast ?? "" })
                    .sorted(by: { $0.seatNumber ?? 0 < $1.seatNumber ?? 0 })
                let crews = users.filter({ $0.role == .crew })
                sections.append(SectionOfUser(items: passengers, identity: "Passengers"))
                sections.append(SectionOfUser(items: crews, identity: "Crew") )
                return sections
            })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        DataService.shared.users$()
            .subscribeNext { [weak self] (users) in
                guard let self = self else { return }
                let passengers = users.filter { !$0.isCrew }
                self.informationLabel.text = "Total passengers: \(passengers.count)"
            }
            .disposed(by: disposeBag)

        DataService.shared
            .workspaceId$
            .map { WorkspaceId(stringLiteral: $0 )}
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)

        let addBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showCreateUserAlert))
        navigationItem.rightBarButtonItem = addBarButtonItem
    }

    @objc private func showCreateUserAlert() {
        let alert = UIAlertController(title: "Create a manual user?", message: "Warning: A manual user is controlled only by the cabin crew. No passenger will be able to log in for this flight", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes, create", style: .default) { [weak self] _ in
            self?.createUser()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func createUser() {
        let alert = UIAlertController(title: "Seat", message: nil, preferredStyle: .alert)
        alert.addTextField()
        let textField = alert.textFields?.first
        textField?.placeholder = "0A"
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            guard let text = textField?.text, !text.isEmpty else { return }
            Task {
                await DataService.shared.setUser(
                    id: UUID().uuidString,
                    name: "Manually Created User",
                    seat: text,
                    role: .passenger,
                    isManuallyCreated: true)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(createAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let h = UITableViewHeaderFooterView()
        h.textLabel?.text = section == 1 ? "Crew Members" : "Passengers"
        return h
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = dataSource.sectionModels[indexPath.section].items[indexPath.row]

        let settingsViewController = SettingsViewController(userId: user.id)
        let nav = UINavigationController(rootViewController: settingsViewController)
        self.present(nav, animated: true, completion: nil)
    }
}
