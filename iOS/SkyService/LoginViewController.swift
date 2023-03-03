//
//  CrewLoginViewController.swift
//  Etihad
//
//  Created by Maximilian Alexander on 3/25/21.
//

import Eureka


class LoginViewController: FormViewController {

    let mainFormSection = Section()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Bundle.main.isCrew ? "Welcome Etihad Meal Order Crew": "Etihad Meal Order"
        navigationController?.navigationBar.prefersLargeTitles = true

        form
            +++ mainFormSection
            <<< TextRow("name") { row in
                row.title = "Name: "
            }

        if !Bundle.main.isCrew {
            mainFormSection
                <<< SeatRow("seat") { row in
                    row.title = "Seat: "
                }
        } else {
            mainFormSection
                <<< PasswordRow("password") { row in
                    row.title = "Password: "
                }
        }

        form
            +++ Section()
            <<< ButtonRow("login", { (row) in
                row.title = Bundle.main.isCrew ? "Login" : "Enter"
                row.cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
            }).onCellSelection({ [weak self] (_, _) in
                guard let `self` = self else { return }
                self.loginButtonDidClick()
            })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let textRow = form.rowBy(tag: "name") as! TextRow
        textRow.cell.textField.becomeFirstResponder()
    }

    func loginButtonDidClick() {
        let name: String = form.values()["name"] as? String ?? ""
        let seat = form.values()["seat"] as? String
        let password = form.values()["password"] as? String ?? ""
        guard name.count >= 3 else {
            let alert = UIAlertController(title: "Please provide a name longer than 3 characters", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: { [weak self] _ in
                let textRow = self?.form.rowBy(tag: "name") as! TextRow
                textRow.cell.textField.becomeFirstResponder()
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }

        if Bundle.main.isCrew && password != "dittolovesetihad2003" {
            let alert = UIAlertController(title: "Incorrect password.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: { [weak self] _ in
                let textRow = self?.form.rowBy(tag: "password") as? PasswordRow
                textRow?.cell.textField.becomeFirstResponder()
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }

        if !Bundle.main.isCrew && seat == nil {
            let alert = UIAlertController(title: "Please select a seat!", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: { [weak self] _ in
                let pickerRow = self?.form.rowBy(tag: "seat") as! PickerInlineRow<String>
                pickerRow.select()
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }

        UserDefaults.standard.name = name
        UserDefaults.standard.seat = seat

        DataService.shared.setUser(id: DataService.shared.userId, name: UserDefaults.standard.name!, seat: UserDefaults.standard.seat)

        if Bundle.main.isCrew {
            self.navigationController?.setViewControllers([MainCrewViewController()], animated: true)
        } else {
            self.navigationController?.setViewControllers([PaxMenuViewController()], animated: true)
        }

    }
}
