import UIKit

class MainCrewTabController: UITabBarController, UITabBarControllerDelegate, SettingsViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        let settingsViewController = SettingsViewController()
        settingsViewController.delegate = self

        viewControllers = [
            UINavigationController(rootViewController: settingsViewController),
            UINavigationController(rootViewController: OrdersViewController()),
            UINavigationController(rootViewController: CrewMenuViewController()),
            UINavigationController(rootViewController: PassengersViewController()),
            UINavigationController(rootViewController: ChatViewController()),
            UINavigationController(rootViewController: NotesViewController(notesType: .personal)),
            UINavigationController(rootViewController: NotesViewController(notesType: .shared))
        ]

        customizableViewControllers = Array((viewControllers ?? []).dropFirst())

        if let vcs = viewControllers, vcs.indices.contains(UserDefaults.standard.lastTabIndex) {
            self.selectedIndex = UserDefaults.standard.lastTabIndex
        }

        delegate = self
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        DataService.shared.startSyncing()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        UserDefaults.standard.lastTabIndex = tabBarController.selectedIndex
    }

    deinit {
        DataService.shared.stopSyncing()
    }

    func logoutButtonDidClick() {
        DataService.shared.stopSyncing()
        DataService.shared.evictAllData()
        UserDefaults.standard.workspaceId = nil
        let loginNav = UINavigationController(rootViewController: LoginViewController())
        (UIApplication.shared.delegate as! AppDelegate).setRootViewController(loginNav, animated: true)
    }

    func goToController<T: UIViewController>(_ controllerType: T.Type) {
        let firstController = self.viewControllers?
            .compactMap({ $0 as? UINavigationController })
            .compactMap({ $0.viewControllers.first })
            .filter({ $0 is T })
            .first

        if firstController?.navigationController != self.selectedViewController {
            self.selectedViewController = firstController?.navigationController
        }

    }
}
