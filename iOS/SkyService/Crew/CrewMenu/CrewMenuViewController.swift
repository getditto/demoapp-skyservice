import UIKit
import Cartography
import RxSwift

class CrewMenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView()
    private var sectionsOfMenuItems = [SectionOfMenuItems]()
    var disposeBag = DisposeBag()
    private let categoriesVC = CategoriesViewController()

    private lazy var welcomeMessageButton: WelcomeMessageButton = {
        let button = WelcomeMessageButton(isCrew: Bundle.main.isCrew)
        button.addTarget(self, action: #selector(editWelcomeMessage), for: .touchUpInside)
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Menu"
        tabBarItem.image = UIImage(named: "menu")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true

        let categoriesButton = UIBarButtonItem(title: "Categories", style: .plain, target: self, action: nil)
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: nil)
        let editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(showEditing))

        navigationItem.leftBarButtonItem = categoriesButton
        navigationItem.rightBarButtonItems = [addButton, editButton]

        view.addSubview(welcomeMessageButton)
        view.addSubview(tableView)
        constrain(welcomeMessageButton, tableView) { welcomeMessageButton, tableView in
            welcomeMessageButton.top == welcomeMessageButton.superview!.safeAreaLayoutGuide.top
            welcomeMessageButton.left == welcomeMessageButton.superview!.left + 14
            welcomeMessageButton.right == welcomeMessageButton.superview!.right - 14

            tableView.top == welcomeMessageButton.bottom + 8
            tableView.left == tableView.superview!.left
            tableView.right == tableView.superview!.right
            tableView.bottom == tableView.superview!.bottom
        }
        tableView.dataSource = self
        tableView.delegate = self

        categoriesButton
            .rx
            .tap
            .bind { [unowned self] _ in
                self.navigationController?.pushViewController(categoriesVC, animated: true)
            }
            .disposed(by: disposeBag)

        DataService.shared
            .workspaceId$
            .map { WorkspaceId(stringLiteral: $0 )}
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)

        DataService.shared
            .welcomeMessage$()
            .bind(onNext: { [weak self] message in
                guard let self = self else { return }
                self.welcomeMessageButton.setTitle(message, for: .normal)
            }).disposed(by: disposeBag)

        DataService.shared.menuItemsAndAllCategories()
            .subscribeNext({ [weak self] (sectionsOfMenuItems, allCategories, _) in
                self?.sectionsOfMenuItems = sectionsOfMenuItems
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)

        addButton
            .rx
            .tap
            .flatMapLatest({ _ in
                return DataService.shared.createMenuItem(name: "", price: 0, details: "")
            })
            .bind { [weak self] insertedId in
                guard let `self` = self else { return }
                let vc = EditMenuItemViewController(menuItemId: insertedId, isCrewOnly: false)
                let nav = UINavigationController(rootViewController: vc)
                self.present(nav, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)
    }

    @objc func showEditing(_ sender: UIBarButtonItem) {
        if self.tableView.isEditing == true {
            self.tableView.setEditing(false, animated: true)
            sender.title = "Edit"
        }
        else {
            self.tableView.setEditing(true, animated: true)
            sender.title = "Done"
        }
    }

    @objc private func editWelcomeMessage() {
        guard let message = welcomeMessageButton.titleLabel?.text else { return }
        let alert = UIAlertController(title: "Welcome Message", message: " \(String(repeating: "\n", count: 7))", preferredStyle: .alert)

        let textView = UITextView()
        textView.addDoneButtonInKeyboard()
        textView.text = message
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
            Task {
                await DataService.shared.updateWelcomeMessage(textView.text)
            }
        })
        present(alert, animated: false, completion: nil)

    }

    // UITableViewDataSource

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionsOfMenuItems.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionsOfMenuItems[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sectionsOfMenuItems[indexPath.section].items[indexPath.row]
        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: "Cell")
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
            cell.accessoryType = .disclosureIndicator
        }
        cell.textLabel?.text = item.name
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 3)
        cell.detailTextLabel?.text = item.details
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = sectionsOfMenuItems[section]
        return section.category?.name ?? "Uncategorised"
    }

    // UITableViewDelegate

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        tableView.isEditing ? .delete : .none
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        let item = sectionsOfMenuItems[indexPath.section].items[indexPath.row]
        let nav = UINavigationController(
            rootViewController: EditMenuItemViewController(menuItemId: item.id, isCrewOnly: item.isCrewOnly))
        present(nav, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }
        let menuItemToMove = sectionsOfMenuItems[sourceIndexPath.section].items[sourceIndexPath.row]
        let destinationIndex: Int = destinationIndexPath.row
        let categoryId: String? = sectionsOfMenuItems[destinationIndexPath.section].category?.id
        let menuItems = sectionsOfMenuItems[destinationIndexPath.section].items;
        let differentSection = (sourceIndexPath.section != destinationIndexPath.section)
        let newOrdinal = calculateOrdinal(sourceIndex: sourceIndexPath.row, destinationIndex: destinationIndex, items: menuItems, differentSection: differentSection)
        Task {
            await DataService.shared.updateMenuItemOrdinal(id: menuItemToMove.id, newOrdinal: newOrdinal, categoryId: categoryId)
        }
    }

    private func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) async {
        if editingStyle == .delete {
            let item = sectionsOfMenuItems[indexPath.section].items[indexPath.row]
            await DataService.shared.deleteMenuItem(id: item.id)
        }
    }

    deinit {
        disposeBag = DisposeBag()
    }
    
}

