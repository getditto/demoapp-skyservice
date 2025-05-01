import RxSwift
import SwiftUI
import Eureka
import NotificationBannerSwift
import DittoAllToolsMenu
import MessageUI

protocol SettingsViewControllerDelegate: AnyObject {
    func logoutButtonDidClick()
}

class SettingsViewController: FormViewController {

    var disposeBag = DisposeBag()

    weak var delegate: SettingsViewControllerDelegate?

    let userId: String
    let shouldShowDismissButton: Bool

    init(userId: String = DataService.shared.userId, shouldShowDismissButton: Bool = false) {
        self.userId = userId
        self.shouldShowDismissButton = shouldShowDismissButton
        super.init(nibName: nil, bundle: nil)
        tabBarItem.image = UIImage(named: "settings")
        tabBarItem.title = "Settings"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
        self.navigationController?.navigationBar.prefersLargeTitles = true

        if userId != DataService.shared.userId {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonDidClick))
        }

        if shouldShowDismissButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonDidClick))
        }

        form
            +++ Section("Current flight info") {
                $0.hidden = Condition(booleanLiteral: DataService.shared.userId != self.userId)
            }
            <<< LabelRow("workspaceIdDepartureDate", { (row) in
                row.title = "Departure date:"
                row.value = {
                    guard let departureDate = UserDefaults.standard.workspaceId?.departureDate else { return nil }
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    return dateFormatter.string(from: departureDate)
                }()
            })
            <<< LabelRow("workspaceIdFlightNumber", { (row) in
                row.title = "Flight:"
                row.value = {
                    guard let workspaceId = UserDefaults.standard.workspaceId else { return nil }
                    return workspaceId.flightNumber
                }()
            })
            <<< SwitchRow("workspaceOrderingEnabled") { row in
                row.title = "Ordering enabled"
                row.disabled = Condition(booleanLiteral: !Bundle.main.isCrew)
            }.onChange({ (row) in
                guard let value = row.value else { return }
                Task {
                    await DataService.shared.setEnableOrdering(isOrderingEnabled: value)
                }
            })

        form
            +++ Section(DataService.shared.userId == self.userId ? "My profile" : "profile")
            <<< TextRow("name", { (row) in
                row.title = "Name:"
            }).cellUpdate { cell, row in
                cell.textField.clearButtonMode = .whileEditing
            }
            <<< CapitalizedLetterAndNumberRow("seat", { (row) in
                row.title = "Seat:"
            }).cellUpdate { cell, row in
                cell.textField.clearButtonMode = .whileEditing
            }
            <<< SegmentedRow<Role>("role", { (row) in
                row.title = "Role:"
                row.hidden = Condition(booleanLiteral: !Bundle.main.isCrew)
                row.options = Role.allCases
            }).cellSetup { cell, row in
                cell.segmentedControl.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
            }
            <<< ButtonRow("save") { row in
                row.title = "Save profile"
                row.cell.tintColor = .systemGreen
            }.onCellSelection({ (_, _) in
                self.saveButtonDidClick()
            })

        form
            +++ Section() { $0.hidden = Condition(booleanLiteral: !Bundle.main.isCrew) }
            <<< ButtonRow("orderForUser", { row in
                row.title = "Order for user"
                row.cell.tintColor = .systemTeal
            })
            .onCellSelection({ (_, _) in
                self.orderForUser()
            })
        form
            +++ Section()
            <<< ButtonRow("delete user") { row in
                row.title = "Delete user"
                row.cell.tintColor = .systemRed
                row.hidden = true // default hidden
            }.onCellSelection{ [weak self] (cell, row) in
                guard let `self` = self else { return }
                let alert = UIAlertController(title: "DELETE user?", message: "Warning: This also deletes orders by this user", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Yes, delete", style: .destructive, handler: { (_) in
                    Task {
                        await DataService.shared.deleteUser(userId: self.userId)
                    }
                    self.dismiss(animated: true)
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

                self.present(alert, animated: true)
            }


        if self.userId == DataService.shared.userId {
            form
                +++ appAndDittoInfoSection()
        }

        form
            +++ Section() { $0.hidden = Condition(booleanLiteral: self.userId != DataService.shared.userId) }
            <<< ButtonRow("feedback") { row in
                row.title = "Send feedback"
            }.onCellSelection({ [unowned self] (_, _) in
                self.sendFeedbackEmail()
            })
            <<< ButtonRow("dittoTools", { (row) in
                row.title = "Ditto Tools"
                row.cell.tintColor = .systemPurple
            }).onCellSelection({ [weak self] (_, _) in
                guard let `self` = self else { return }
                let vc = UIHostingController(rootView: AllToolsMenu(ditto: DataService.shared.ditto))
                navigationController?.pushViewController(vc, animated: true)
            })
            

        form
            +++ Section() { $0.hidden = Condition(booleanLiteral: self.userId != DataService.shared.userId) }
            <<< ButtonRow("Device settings", { (row) in
                row.title = "Device settings"
                row.cell.tintColor = Bundle.main.isCrew ? UIColor.white: UIColor.black
            })
            .onCellSelection({ [weak self] (cell, row) in
                guard let self = self else { return }
                self.deviceSettingsButtonDidClick()
            })

        form
            +++ Section() { $0.hidden = Condition(booleanLiteral: self.userId != DataService.shared.userId) }
            <<< ButtonRow("Logout", { (row) in
                row.title = "Logout"
                row.cell.tintColor = .systemRed
            })
            .onCellSelection({ [weak self] (cell, row) in
                guard let `self` = self else { return }
                self.logoutButtonDidClick()
            })

        form
            +++ Section() { $0.hidden = Condition(booleanLiteral: self.userId != DataService.shared.userId) }
            <<< ButtonRow("prepopulate") { row in
                row.title = "Prepopulate data"
                row.hidden = Condition(booleanLiteral: !Bundle.main.isCrew)
                row.cell.tintColor = .systemGray2
            }.onCellSelection({ [weak self] (cell, row) in
                guard let `self` = self else { return }
                let alert = UIAlertController(title: "Prepopulate?", message: "This will prepopulate menu items and categories. This is primarily used for testing purposes!", preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Yes, prepopulate.", style: .default, handler: { (_) in
                    Task {
                        await DataService.shared.prepopulateMenuItems()
                    }
                    let banner = StatusBarNotificationBanner(title: "Prepopulated menu items", style: .success)
                    banner.show()
                    AppDelegate.crewTabController?.goToController(CrewMenuViewController.self)
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            })


        DataService.shared
            .userById(self.userId)
            .subscribeNext { [weak self] (user) in
                guard let `self` = self, let user = user else { return }
                self.form.setValues([
                    "name": user.name,
                    "seat": user.seat,
                    "role": user.role,
                    "isManuallyCreated": user.isManuallyCreated
                ])

                let deleteRow = self.form.rowBy(tag: "delete user")
                deleteRow?.hidden = Condition(booleanLiteral: user.isCrew && !user.isManuallyCreated)
                deleteRow?.evaluateHidden()

                self.tableView.reloadData()
            }
            .disposed(by: disposeBag)

        DataService.shared
            .canOrder$()
            .distinctUntilChanged()
            .bind { [weak self] canOrder in
                guard let `self` = self else { return }
                self.form.setValues([
                    "workspaceOrderingEnabled": canOrder
                ])
                self.form.rowBy(tag: "workspaceOrderingEnabled")?.reload()
            }
            .disposed(by: disposeBag)
    }

    @objc func cancelButtonDidClick() {
        self.dismiss(animated: true, completion: nil)
    }

    func saveButtonDidClick() {
        let name = (form.values()["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let seat = (form.values()["seat"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let role = form.values()["role"] as? Role ?? .passenger
        let isManuallyCreated = form.values()["isManuallyCreated"] as? Bool ?? false
        Task {
            await DataService.shared.setUser(id: self.userId, name: name, seat: seat, role: role, isManuallyCreated: isManuallyCreated)
        }
        let banner = StatusBarNotificationBanner(title: "Saved changes", style: .success)
        banner.show()
        dismiss(animated: true)
    }

    func logoutButtonDidClick() {
        let alert = UIAlertController(title: "Logout?", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Logout", style: .destructive, handler: { (_) in
            self.delegate?.logoutButtonDidClick()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    func orderForUser() {
        let paxMenuViewController = PassengerMenuViewController(userId: self.userId)
        navigationController?.pushViewController(paxMenuViewController, animated: true)
    }

    @objc func closeButtonDidClick() {
        self.dismiss(animated: true, completion: nil)
    }

    func deviceSettingsButtonDidClick() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        guard UIApplication.shared.canOpenURL(settingsURL) else {
            return
        }
        UIApplication.shared.open(settingsURL, completionHandler: nil)
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {

    func sendFeedbackEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["contact@ditto.live"])


            let ditto = DataService.shared.ditto!
            let sdkVersion = ditto.sdkVersion
            let versions = sdkVersion.dropFirst(4).split(separator: "_")
            let semVer = String(versions[0])
            let commitHash = String(versions[1])
            let releaseVersionNumber = Bundle.main.releaseVersionNumber!
            let buildVersionNumber = Bundle.main.buildVersionNumber!

            let subject: String
            if Bundle.main.isCrew {
                subject = "Ecoflight crew app - Version \(releaseVersionNumber) Build \(buildVersionNumber)"
            } else {
                subject = "Ecoflight passenger app - Version \(releaseVersionNumber) Build \(buildVersionNumber)"
            }

            let body = """
            Write your feedback here: <br/> <br/>

            <strong>App: </strong> Version \(releaseVersionNumber) Build \(buildVersionNumber)<br/>
            <strong>iOS Version</strong> \(UIDevice.current.systemVersion)<br/>
            <strong>Ditto SDK Version: </strong> \(semVer) \(commitHash)<br/>
            """

            mail.setSubject(subject)
            mail.setMessageBody(body, isHTML: true)
            present(mail, animated: true)
        } else {
            // show failure alert
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

}
