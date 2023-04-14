import UIKit
import Eureka

final class CapitalizedLetterAndNumberRowCell: TextCell {

    static let ACCEPTABLE_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    override func setup() {
        super.setup()
        self.textField.autocapitalizationType = .allCharacters
    }

    override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let invalidCharacters = NSCharacterSet.alphanumerics.inverted
        let filtered = string.components(separatedBy: invalidCharacters).joined(separator: "")
        return (string == filtered)
    }

    override func textFieldDidChange(_ textField: UITextField) {
        textField.text = textField.text?.uppercased()
        row.value = textField.text
    }

}

final class CapitalizedLetterAndNumberRow: Row<CapitalizedLetterAndNumberRowCell>, RowType {

}
