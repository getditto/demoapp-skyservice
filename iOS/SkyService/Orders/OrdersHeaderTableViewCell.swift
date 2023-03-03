import UIKit
import Cartography

protocol OrdersHeaderTableViewDelegate: AnyObject {
    func deleteButtonDidClick(order: Order, button: PrimaryButton)
}

class OrdersHeaderTableViewCell: UITableViewCell {

    static let REUSE_ID = "OrdersHeaderView"

    weak var delegate: OrdersHeaderTableViewDelegate?
    var order: Order?
    var customLabel: UILabel = UILabel()
    var segmentedControl = OrderSegmentedControl()

    lazy var dateFormatter: DateFormatter = {
        let d = DateFormatter()
        d.timeStyle = .short
        return d
    }()

    lazy var deleteButton: UIButton = {
        let b = PrimaryButton()
        b.setImage(UIImage(named: "trash"), for: .normal)
        b.tintColor = .systemGray
        b.backgroundColor = UIColor.systemGroupedBackground
        return b
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(customLabel)
        contentView.addSubview(segmentedControl)
        contentView.addSubview(deleteButton)

        self.contentView.backgroundColor = .systemGroupedBackground
        constrain(customLabel, segmentedControl, deleteButton) { customLabel, segmentedControl, deleteButton in
            customLabel.top == customLabel.superview!.top + 14
            customLabel.left == customLabel.superview!.left + 14
            customLabel.right == deleteButton.left - 8

            deleteButton.top == customLabel.top
            deleteButton.right == deleteButton.superview!.right - 14

            segmentedControl.height == 30
            segmentedControl.top == customLabel.bottom + 14
            segmentedControl.left == segmentedControl.superview!.left + 14
            segmentedControl.right == segmentedControl.superview!.right - 14
            segmentedControl.bottom == segmentedControl.superview!.bottom - 14
        }
        customLabel.lineBreakMode = .byWordWrapping
        customLabel.numberOfLines = 0
        customLabel.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: UIFont.Weight.heavy)

        // only crew should be able to edit this control
        segmentedControl.isUserInteractionEnabled = Bundle.main.isCrew

        deleteButton.addTarget(self, action: #selector(deleteButtonDidClick), for: .touchUpInside)
        deleteButton.isHidden = !Bundle.main.isCrew
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    func setupWith(order: Order, user: User?) {
        self.order = order
        self.customLabel.attributedText = {
            let m = NSMutableAttributedString()

            let firstPart = Bundle.main.isCrew ? "Seat: \(user?.seat ?? "")" : ""
            m.append(NSAttributedString(string: firstPart, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize + 8, weight: .bold),
                NSAttributedString.Key.paragraphStyle: {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .left
                    return p
                }()
            ]))

            let secondPart = Bundle.main.isCrew ? "\nName: \(user?.name ?? "Deleted user")" : "Order"
            m.append(NSAttributedString(string: secondPart, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize + 3, weight: .regular),
                NSAttributedString.Key.paragraphStyle: {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .left
                    return p
                }()
            ]))

            let thirdPart = "\nOrdered: \(dateFormatter.string(from: order.createdOn))"
            m.append(NSAttributedString(string: thirdPart, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: UIFont.labelFontSize + 3, weight: .regular),
                NSAttributedString.Key.paragraphStyle: {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .left
                    return p
                }()
            ]))
            return m
        }()
        self.segmentedControl.orderId = order.id
        self.segmentedControl.status = order.status
    }

    @objc private func deleteButtonDidClick(button: PrimaryButton) {
        guard let order = order else { return }
        delegate?.deleteButtonDidClick(order: order, button: button)
    }
}
