import Eureka
import Cartography

final class QuantityStepperCell: Cell<Int>, CellType {

    enum ButtonType {
        case minus
        case plus
    }

    lazy var minusButton: UIButton = {
        let b = UIButton()
        b.setTitle("-", for: .normal)
        b.tintColor = .primaryColor
        b.setTitleColor(.primaryColor, for: .normal)
        b.setTitleColor(.secondaryLabel, for: .disabled)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 10)
        b.layer.cornerRadius = 8
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.primaryColor.cgColor
        b.tag = -1
        return b
    }()

    lazy var plusButton: UIButton = {
        let b = UIButton()
        b.setTitle("+", for: .normal)
        b.tintColor = .primaryColor
        b.setTitleColor(.primaryColor, for: .normal)
        b.setTitleColor(.secondaryLabel, for: .disabled)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 10)
        b.layer.cornerRadius = 8
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.primaryColor.cgColor
        b.tag = 1
        return b
    }()

    lazy var quantityLabel: UILabel = {
        let label = UILabel()
        label.text = "23"
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize + 2)
        return label
    }()

    required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func setup() {
        super.setup()
        height = { 70 }
        textLabel?.isHidden = true
        detailTextLabel?.isHidden = true
        selectionStyle = .none
        contentView.addSubview(minusButton)
        contentView.addSubview(plusButton)
        contentView.addSubview(quantityLabel)
        constrain(minusButton, plusButton, quantityLabel) { minusButton, plusButton, quantityLabel in

            quantityLabel.height == quantityLabel.superview!.height - 24
            quantityLabel.width == quantityLabel.height
            quantityLabel.centerX == quantityLabel.superview!.centerX
            quantityLabel.centerY == quantityLabel.superview!.centerY

            minusButton.height == minusButton.superview!.height - 24
            minusButton.width == minusButton.height
            minusButton.centerY == minusButton.superview!.centerY
            minusButton.right == quantityLabel.left - 12

            plusButton.height == plusButton.superview!.height - 24
            plusButton.width == plusButton.height
            plusButton.centerY == plusButton.superview!.centerY
            plusButton.left == quantityLabel.right + 12

        }

        self.plusButton.addTarget(self, action: #selector(buttonDidClick(sender:)), for: .touchUpInside)
        self.minusButton.addTarget(self, action: #selector(buttonDidClick(sender:)), for: .touchUpInside)
    }

    override func update() {
        super.update()
        self.quantityLabel.text = "\(self.row.value ?? 0)"
    }

    @objc func buttonDidClick(sender: UIButton) {
        guard let row = row as? QuantityStepperRow else { return }
        row.counterButtonCallback?(row, sender.tag)
    }

}

typealias CounterButtonCallback = ((_ row: QuantityStepperRow, _ value: Int) -> Void)

final class QuantityStepperRow: Row<QuantityStepperCell>, RowType {

    var counterButtonCallback: CounterButtonCallback?

    required init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<QuantityStepperCell>()
    }

    func counterButtonDidClick(_ callback: @escaping CounterButtonCallback) -> Self {
        self.counterButtonCallback = callback
        return self
    }


}
