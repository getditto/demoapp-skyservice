import UIKit
import Eureka

final class LoginViewController: FormViewController {

    private let password = "dittoskyservice"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Bundle.main.isCrew ? "SkyService Crew" : "SkyService"

        form
            +++ Section()
            <<< TextRow("name", { row in
                row.title = "Name:"
                row.add(rule: RuleRequired(msg: "Please enter a name"))
                row.add(rule: RuleMinLength(minLength: 3, msg: "The name must be 3 or more characters long"))
                row.validationOptions = .validatesOnChangeAfterBlurred
            }).cellUpdate({ (cell, row) in
                if !row.isValid {
                    cell.textLabel?.textColor = UIColor.systemRed
                }
            }).onChange({ (row) in
                UserDefaults.standard.cachedName = row.value
            })
            <<< CapitalizedLetterAndNumberRow("seat", { row in
                row.title = "Seat:"
                row.hidden = Condition(booleanLiteral: Bundle.main.isCrew)
                if !Bundle.main.isCrew {
                    row.add(rule: RuleRequired(msg: "Please enter a seat"))
                    row.add(rule: RuleMinLength(minLength: 2, msg: "The seat must be 2 or more characters long"))
                    row.add(rule: RuleClosure<String> { value in
                        self.isSeatNumValid(seat: value) ? nil: ValidationError(msg: "Seat invalid format\nexample: 1A")
                    })
                    row.validationOptions = .validatesOnChangeAfterBlurred
                }
            }).cellUpdate({ (cell, row) in
                if !row.isValid {
                    cell.textLabel?.textColor = UIColor.systemRed
                }
            }).onChange({ (row) in
                UserDefaults.standard.cachedSeat = row.value
            })
            <<< PasswordRow("password", { row in
                row.title = "Password:"
                row.hidden = Condition(booleanLiteral: !Bundle.main.isCrew)
                if Bundle.main.isCrew {
                    row.add(rule: RuleRequired(msg: "Please enter a password"))
                    row.add(rule: RuleClosure(closure: { (val) -> ValidationError? in
                        if val != self.password {
                            return ValidationError(msg: "Incorrect password")
                        }
                        return nil
                    }))
                    row.validationOptions = .validatesOnDemand
                }
            }).cellUpdate({ (cell, row) in
                if !row.isValid {
                    cell.textLabel?.textColor = UIColor.systemRed
                }
            })
            .onChange({ (row) in
                UserDefaults.standard.cachedPassword = row.value
            })

        form
            +++ Section()
            <<< DateRow("departureDate", { (row) in
                row.title = "Flight departure date:"
                row.add(rule: RuleRequired(msg: "Please select a departure date"))
                row.validationOptions = .validatesOnChangeAfterBlurred
            })
            .onCellSelection({ (cell, row) in
                if row.value == nil {
                    row.value = Date()
                }
            })
            .cellUpdate({ (cell, row) in
                if !row.isValid {
                    cell.textLabel?.textColor = UIColor.systemRed
                } else {
                    cell.textLabel?.textColor = Bundle.main.isCrew ? UIColor.white: UIColor.black
                }
            })
            .onChange({ (row) in
                UserDefaults.standard.cachedDepartureDate = row.value
            })
            <<< TextRow("flightNumber", { row in
                row.add(rule: RuleRequired())
                row.add(rule: RuleMinLength(minLength: 3, msg: "The flight number needs to be more than 3 characters long"))
                row.add(rule: RuleClosure<String> { value in
                    self.isFlightNumberValid(flightNumber: value) ? nil: ValidationError(msg: "Flight number too short")
                })
                row.title = "Flight number:"
                row.validationOptions = .validatesOnChangeAfterBlurred
            })
            .cellUpdate({ (cell, row) in
                if !row.isValid {
                    cell.textLabel?.textColor = UIColor.systemRed
                } else {
                    cell.textLabel?.textColor = Bundle.main.isCrew ? UIColor.white: UIColor.black
                }
            })
            .onChange({ (row) in
                UserDefaults.standard.cachedFlightNumber = row.value
            })

        form
            +++ Section()
            <<< ButtonRow("Login", { (row) in
                row.title = "Login"
                row.cell.tintColor = UIColor.primaryColor
                row.cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
            }).onCellSelection({ (_, _) in
                self.attemptLogin()
            })

        form.setValues([
            "name": UserDefaults.standard.cachedName ?? Randoms.randomFakeFirstName(),
            "password": UserDefaults.standard.cachedPassword ?? Env.DITTO_AUTH_PASSWORD,
        ])
        if Bundle.main.isCrew {
            form.setValues([
                "departureDate": UserDefaults.standard.cachedDepartureDate ?? Date(),
                "flightNumber": flightPrefix
            ])
        }
        tableView.reloadData()
    }

    private func format(string: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.date(from: string ?? "")
    }

    private func isSeatNumValid(seat: String?) -> Bool {
        guard let seat = seat else { return false }
        guard let lastChar = seat.uppercased().last else { return false }
        let lastDropped = String(seat.dropLast())
        guard let num = Int(lastDropped) else { return false }
        return lastChar.isLetter &&
            (lastChar >= "A" && lastChar <= "Z") &&
            (num >= 1 && num <= 200)
    }

    private func isFlightNumberValid(flightNumber str: String?) -> Bool {
        return true // removing validation for now
        /*
        guard let str = str else { return false }
        let prefix = str.uppercased().prefix(2)
        // guard prefix == flightPrefix else { return false }
        let suffix = str.dropFirst(2)
        guard let num = Int(suffix) else { return false }
        return num >= 1 && num <= 9999 */
    }

    private var flightPrefix: String {
        // TODO: Switch if specific airlines
        return "DIT101"
    }

    private func formatFlightNumber(_ flightNumber: String) -> String {
        let noSpaces = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard let transformed = noSpaces.applyingTransform(.fullwidthToHalfwidth, reverse: false) else { return flightNumber }
        return transformed
    }

    func attemptLogin() {
        let validationErrors = form.validate()
        guard validationErrors.isEmpty else {
            let alert = UIAlertController(title: "Invalid input", message: validationErrors.first!.msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        let departureDate: Date = form.values()["departureDate"] as! Date
        let flightNumber: String = form.values()["flightNumber"] as! String
        let formattedFlightNumber = formatFlightNumber(flightNumber)
        let name: String = (form.values()["name"] as! String).trimmingCharacters(in: .whitespacesAndNewlines)
        let seat: String? = (form.values()["seat"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let workspaceId: WorkspaceId = WorkspaceId(departureDate: departureDate, flightNumber: formattedFlightNumber)
        UserDefaults.standard.workspaceId = workspaceId
        DataService.shared.setUser(id: DataService.shared.userId, name: name, seat: seat, role: Bundle.main.isCrew ? .crew : .passenger)

        if Bundle.main.isCrew {
            (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(MainCrewTabController(), animated: true)
        } else {
            let navController = UINavigationController(rootViewController: PassengerMenuViewController(userId: DataService.shared.userId))
            (UIApplication.shared.delegate as? AppDelegate)?.setRootViewController(navController, animated: true)
        }
    }
}
