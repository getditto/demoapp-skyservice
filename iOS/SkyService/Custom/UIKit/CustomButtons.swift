import UIKit

class PrimaryButton: UIButton {

    init() {
        super.init(frame: .zero)
        self.backgroundColor = UIColor.primaryColor
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: UIFont.Weight.heavy)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func changeEnabled(_ isEnabled: Bool) {
        self.backgroundColor = isEnabled ? .primaryColor : .lightGray
        self.isEnabled = isEnabled
    }
}

final class WelcomeMessageButton: UIButton {

    init(isCrew: Bool) {
        super.init(frame: .zero)
        titleEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        backgroundColor = .clear
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.numberOfLines = 0
        titleLabel?.textAlignment = .center
        setTitleColor(isCrew ? .white: .darkText, for: .normal)
        isUserInteractionEnabled = isCrew

        if isCrew {
            layer.cornerRadius = 6
            layer.borderWidth = 1
            layer.borderColor = UIColor.gray.cgColor
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var marginWidth: CGFloat {
        return titleEdgeInsets.left + titleEdgeInsets.right + 14*2
    }

    override var intrinsicContentSize: CGSize {
        let superviewWidth = superview?.frame.width ?? 0
        let width = superviewWidth - marginWidth
        let fits = titleLabel?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = (fits?.height ?? frame.size.height) + titleEdgeInsets.top + titleEdgeInsets.bottom
        return CGSize(width: width, height: height)
    }
}
