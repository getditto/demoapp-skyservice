import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var dataService: DataService!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        dataService = DataService.shared

        window = UIWindow()
        window?.tintColor = UIColor.primaryColor
        window?.overrideUserInterfaceStyle = Bundle.main.isCrew ? .dark : .light
        window?.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().backgroundColor = .black

        let firstViewController: UIViewController = {
            if Bundle.main.isCrew {
                guard UserDefaults.standard.workspaceId != nil else {
                    let nav = UINavigationController(rootViewController: LoginViewController())
                    nav.navigationBar.prefersLargeTitles = true
                    return nav
                }
                return MainCrewTabController()
            } else {
                guard UserDefaults.standard.workspaceId != nil else {
                    let nav = UINavigationController(rootViewController: LoginViewController())
                    nav.navigationBar.prefersLargeTitles = true
                    return nav
                }
                let nav = UINavigationController(rootViewController: PassengerMenuViewController(userId: DataService.shared.userId))
                nav.navigationBar.prefersLargeTitles = true
                return nav
            }
        }()
        
        storeCurrentAppVersion()
        
        window?.rootViewController = {
            return firstViewController
        }()
        window?.makeKeyAndVisible()
                
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        print(notification.request.content.userInfo)
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let notificationType = response.notification.request.content.userInfo["notificationType"] as? String {
            if notificationType == "newChatMessage" && Bundle.main.isCrew {
                AppDelegate.crewTabController?.goToController(ChatViewController.self)
            }
            if notificationType == "receivedNewOrder" && Bundle.main.isCrew {
                AppDelegate.crewTabController?.goToController(OrdersViewController.self)
            }
            if notificationType == "orderStatusChanged" && !Bundle.main.isCrew && UserDefaults.standard.workspaceId != nil {
                if let ordersViewController = AppDelegate.mainPaxNavigationController?.viewControllers.first(where: { $0 is OrdersViewController }) {
                    AppDelegate.mainPaxNavigationController?.popToViewController(ordersViewController, animated: true)
                } else {
                    AppDelegate.mainPaxNavigationController?.pushViewController(OrdersViewController(), animated: true)
                }
            }
        }
        completionHandler()
    }



    func userNotificationCenter(center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        //Handle the notification
        completionHandler(
            [UNNotificationPresentationOptions.alert,
             UNNotificationPresentationOptions.sound,
             UNNotificationPresentationOptions.badge])
    }

    func setRootViewController(_ vc: UIViewController, animated: Bool = true) {
        guard animated, let window = self.window else {
            self.window?.rootViewController = vc
            self.window?.makeKeyAndVisible()
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()
        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil,
                          completion: nil)
    }

    private func storeCurrentAppVersion() {
        UserDefaults.standard.currentAppVersion = Bundle.main.releaseVersionNumber
    }

    // utility helpers
    weak static var crewTabController: MainCrewTabController? {
        return (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController as? MainCrewTabController
    }

    weak static var mainPaxNavigationController: UINavigationController? {
        return (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController as? UINavigationController
    }
}
