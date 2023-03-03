import UIKit
import Cartography

class CartLineItemTableViewCell: UITableViewCell {

    static let REUSE_ID = "CartLineItemTableViewCell"
    private static let QUANTITY_LABEL_LENGTH: CGFloat = 36

    lazy var quantityLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
        label.textAlignment = .center
        label.layer.cornerRadius = Self.QUANTITY_LABEL_LENGTH / 2
        label.layer.borderColor = UIColor.separator.cgColor
        label.layer.borderWidth = 1.0
        return label
    }()

    lazy var contentsLabel: VerticalTopAlignLabel = {
        let label = VerticalTopAlignLabel()
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        // we don't care for the default text label
        textLabel?.isHidden = true
        // we don't care for the default detail text label
        detailTextLabel?.isHidden = true
        contentView.addSubview(quantityLabel)
        contentView.addSubview(contentsLabel)
        constrain(quantityLabel, contentsLabel) { quantityLabel, contentsLabel in
            quantityLabel.left == quantityLabel.superview!.left + 12
            quantityLabel.top == quantityLabel.superview!.top + 12
            quantityLabel.height == Self.QUANTITY_LABEL_LENGTH
            quantityLabel.width == Self.QUANTITY_LABEL_LENGTH

            contentsLabel.left == quantityLabel.right + 16
            contentsLabel.right == contentsLabel.superview!.right - 12
            contentsLabel.top == contentsLabel.superview!.top + 12
            contentsLabel.height >= Self.QUANTITY_LABEL_LENGTH + 12 * 2
            contentsLabel.bottom == contentsLabel.superview!.bottom - 12
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
