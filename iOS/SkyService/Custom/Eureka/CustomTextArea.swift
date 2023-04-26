import UIKit
import Eureka
import Cartography

class UITextViewFixed: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        setup()
    }
    func setup() {
        textContainerInset = UIEdgeInsets.zero
        textContainer.lineFragmentPadding = 0
    }
}

final class CustomTextAreaRowCell: Cell<String>, CellType, UITextViewDelegate {

    lazy var titleLabel: UILabel = {
        let l = UILabel()
        return l
    }()

    lazy var textArea: UITextViewFixed = {
        let t = UITextViewFixed()
        t.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        t.backgroundColor = .clear
        return t
    }()


    required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        contentView.addSubview(textArea)
        height = { 100 }
        constrain(titleLabel, textArea) { titleLabel, textArea in


            titleLabel.top == titleLabel.superview!.top + 8
            titleLabel.left == titleLabel.superview!.left + 16
            titleLabel.right == titleLabel.superview!.right - 16
            titleLabel.height == 20

            textArea.left == textArea.superview!.left + 16
            textArea.right == textArea.superview!.right - 16
            textArea.top == titleLabel.bottom + 10
            textArea.bottom == textArea.superview!.bottom
        }
    }

    override func setup() {
        super.setup()
        textLabel?.isHidden = true
        detailTextLabel?.isHidden = true
        titleLabel.text = row.title
        textArea.delegate = self
        selectionStyle = .none
    }

    override func update() {
        super.update()
        titleLabel.text = row.title
        textArea.text = row.value
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textViewDidChange(_ textView: UITextView) {
        row.value = textView.text
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        self.titleLabel.textColor = UIColor.primaryColor
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        self.titleLabel.textColor = UIColor.label
    }

}

final class CustomTextAreaRow: Row<CustomTextAreaRowCell>, RowType {

}
