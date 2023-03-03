import UIKit
import Cartography

protocol OrdersFooterTableViewDelegate: AnyObject {
    func crewNoteEditButtonDidClick(order: Order)
}

final class OrdersFooterTableViewCell: UITableViewCell {

    static let REUSE_ID = String(describing: self)

    weak var delegate: OrdersFooterTableViewDelegate?
    var order: Order?
    var customLabel: UILabel = UILabel()

    lazy var borderView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        return v
    }()

    lazy var editButton: UIButton = {
        let b = PrimaryButton()
        b.imageView?.contentMode = .scaleAspectFit
        b.contentHorizontalAlignment = .fill
        b.contentVerticalAlignment = .fill
        b.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        b.setImage(UIImage(named: "edit"), for: .normal)
        b.tintColor = .systemGray
        b.backgroundColor = .systemGroupedBackground
        return b
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(customLabel)
        contentView.addSubview(borderView)
        contentView.addSubview(editButton)
        self.contentView.backgroundColor = .systemGroupedBackground
        constrain(customLabel, borderView, editButton) { customLabel, borderView, editButton in
            customLabel.top == customLabel.superview!.top
            customLabel.bottom == customLabel.superview!.bottom - 30
            customLabel.left == customLabel.superview!.left + 14
            customLabel.right == customLabel.superview!.right - 14

            editButton.height == 43
            editButton.width == 43
            editButton.top == editButton.superview!.top + 8
            editButton.right == editButton.superview!.right - 8

            borderView.height == 2.5
            borderView.bottom == borderView.superview!.bottom
            borderView.right == borderView.superview!.right
            borderView.left == borderView.superview!.left
        }
        self.customLabel.lineBreakMode = .byWordWrapping
        self.customLabel.numberOfLines = 0
        self.customLabel.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .heavy)

        editButton.addTarget(self, action: #selector(editButtonDidClick), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupWith(order: Order) {
        self.order = order
        self.customLabel.attributedText = {
            let m = NSMutableAttributedString()
            m.append(NSAttributedString(string: "\nCrew Note (only crews can see):\n\n", attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .regular),
                NSAttributedString.Key.foregroundColor: UIColor.lightText,
                NSAttributedString.Key.paragraphStyle: {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .left
                    return p
                }()
            ]))
            m.append(NSAttributedString(string: order.crewNote, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .regular),
                NSAttributedString.Key.foregroundColor: UIColor.white,
                NSAttributedString.Key.paragraphStyle: {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .left
                    return p
                }()
            ]))
            return m
        }()
    }

    @objc private func editButtonDidClick() {
        guard let order = order else { return }
        delegate?.crewNoteEditButtonDidClick(order: order)
    }
}
