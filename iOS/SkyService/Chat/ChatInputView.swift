import UIKit
import RSKPlaceholderTextView
import Cartography

class ChatInputView: UIView, UITextViewDelegate {

    let textView : RSKPlaceholderTextView = {
        let textView = RSKPlaceholderTextView()
        textView.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 40)
        textView.isScrollEnabled = false
        textView.layer.cornerRadius = 36 / 2
        textView.layer.masksToBounds = true
        textView.placeholder = "Your message..."
        textView.placeholderColor = UIColor.secondaryLabel
        textView.backgroundColor = UIColor.systemGroupedBackground
        return textView
    }()

    lazy var sendButton : UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 28 / 2
        button.layer.masksToBounds = true
        button.backgroundColor = UIColor.primaryColor
        let image = UIImage(named: "arrow_up")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.imageView?.tintColor = .white
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.alpha = 0
        return button
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        addSubview(sendButton)
        textView.delegate = self
        self.backgroundColor = .secondarySystemBackground
        constrain(textView, sendButton) { textView, sendButton in
            textView.left == textView.superview!.left + 16
            textView.right == textView.superview!.right - 16
            textView.top == textView.superview!.top + 8
            textView.bottom == textView.superview!.bottom - 12 ~ LayoutPriority(750)
            textView.height >= 37

            sendButton.width == 28
            sendButton.height == 28
            sendButton.bottom == textView.bottom - 5
            sendButton.right == sendButton.superview!.right - 20
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        self.updateConstraints() // Interface rotation or size class changes will reset constraints as defined in interface builder -> constraintsForVisibleTextView will be activated
        super.layoutSubviews()
    }

    func textViewDidChange(_ textView: UITextView) {
        let shouldHide = textView.text == nil || textView.text.count == 0
        UIView.animate(withDuration: 0.1, animations: {
            self.sendButton.alpha = shouldHide ? 0 : 1
            self.sendButton.transform = shouldHide ? CGAffineTransform(scaleX: 0.25, y: 0.25) : CGAffineTransform.identity
        })
    }
}
