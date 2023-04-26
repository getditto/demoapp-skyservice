import UIKit
import RxCocoa
import RxSwift


// This is ported from https://github.com/RxSwiftCommunity/RxAlert
// It doesn't support Swift Package Manager, so it's directly pasted here.


// MARK: - AlertAction

struct AlertAction {
    let title: String
    let type: Int
    let textField: UITextField?
    let style: UIAlertAction.Style

    init(title: String = "",
                type: Int = 0,
                textField: UITextField? = nil,
                placeholder: String? = nil,
                style: UIAlertAction.Style = .default)
    {
        self.title = title
        self.type = type
        self.textField = textField
        if self.textField != nil,
           placeholder != nil
        {
            self.textField?.placeholder = placeholder
        }
        self.style = style
    }
}


// MARK: - OutputAction

struct OutputAction {
    var index: Int
    var textFields: [UITextField]?
    var alertAction: UIAlertAction
}


// MARK: - UIAlertController Extension

extension Reactive where Base: UIAlertController {
    func addActions(_ actions: [AlertAction]) -> Observable<OutputAction> {
        let alert = base
        return Observable.create { [weak alert] observer in
            guard let alert = alert else { return Disposables.create() }
            actions.forEach { action in
                if let textField = action.textField {
                    alert.addTextField { text in
                        text.config(textField)
                    }
                } else {
                    alert.addAction(UIAlertAction(title: action.title, style: action.style, handler: { [unowned alert] alertAction in
                        observer.on(.next(OutputAction(index: action.type,
                                                       textFields: alert.textFields,
                                                       alertAction: alertAction)))
                        observer.on(.completed)
                    }))
                }
            }
            return Disposables.create { alert.dismiss(animated: true) }
        }
    }
}

// MARK: - UIViewController

extension Reactive where Base: UIViewController {
    func alert(title: String?,
               message: String? = nil,
               actions: [AlertAction] = [AlertAction(title: "OK")],
               preferredStyle: UIAlertController.Style = .alert,
               vc: UIViewController? = nil,
               tintColor: UIColor? = nil,
               animated: Bool = true,
               completion: (() -> Void)? = nil) -> Observable<OutputAction>
    {
        Observable.create { observer in
            let alertController = UIAlertController(title: title,
                                                    message: message,
                                                    preferredStyle: preferredStyle)
            alertController.view.tintColor = tintColor
            actions.forEach { [weak alertController] action in
                if let textField = action.textField {
                    alertController?.addTextField { text in
                        text.config(textField)
                    }
                } else {
                    alertController?.addAction(UIAlertAction(title: action.title, style: action.style, handler: {[weak alertController] alertAction in
                        observer.on(.next(OutputAction(index: action.type,
                                                       textFields: alertController?.textFields,
                                                       alertAction: alertAction)))
                        observer.on(.completed)
                    }))
                }
            }
            base.present(alertController, animated: animated, completion: completion)
            return Disposables.create()
        }
    }
}

// MARK: - UITextField

private extension UITextField {
    func config(_ textField: UITextField) {
        text = textField.text
        placeholder = textField.placeholder
        tag = textField.tag
        isSecureTextEntry = textField.isSecureTextEntry
        tintColor = textField.tintColor
        textColor = textField.textColor
        textAlignment = textField.textAlignment
        borderStyle = textField.borderStyle
        leftView = textField.leftView
        leftViewMode = textField.leftViewMode
        rightView = textField.rightView
        rightViewMode = textField.rightViewMode
        background = textField.background
        disabledBackground = textField.disabledBackground
        clearButtonMode = textField.clearButtonMode
        inputView = textField.inputView
        inputAccessoryView = textField.inputAccessoryView
        clearsOnInsertion = textField.clearsOnInsertion
        keyboardType = textField.keyboardType
        returnKeyType = textField.returnKeyType
        spellCheckingType = textField.spellCheckingType
        autocapitalizationType = textField.autocapitalizationType
        autocorrectionType = textField.autocorrectionType
        keyboardAppearance = textField.keyboardAppearance
        enablesReturnKeyAutomatically = textField.enablesReturnKeyAutomatically
        delegate = textField.delegate
        clearsOnBeginEditing = textField.clearsOnBeginEditing
        adjustsFontSizeToFitWidth = textField.adjustsFontSizeToFitWidth
        minimumFontSize = textField.minimumFontSize

        if #available(iOS 11.0, *) {
            self.textContentType = textField.textContentType
        }

        if #available(iOS 11.0, *) {
            self.smartQuotesType = textField.smartQuotesType
            self.smartDashesType = textField.smartDashesType
            self.smartInsertDeleteType = textField.smartInsertDeleteType
        }

        if #available(iOS 12.0, *) {
            self.passwordRules = textField.passwordRules
        }
    }
}

