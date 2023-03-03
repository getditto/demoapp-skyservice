import UIKit
import Cartography

class NameCollectionViewCell: UICollectionViewCell {

    var label: UILabel = UILabel()

    func commonInit() {
        addSubview(label)
        constrain(label) { label in
            label.left == label.superview!.left + 20
            label.right == label.superview!.right - 16
            label.top == label.superview!.top
            label.bottom == label.superview!.bottom
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var text: NSAttributedString? {
        didSet {
            self.label.attributedText = self.text
        }
    }
}
