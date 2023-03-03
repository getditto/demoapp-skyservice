import Eureka
import Cartography
import RxCocoa
import RxSwift

final class UpdateCartButtonRowCell: Cell<String>, CellType {

    let primaryButton: UIButton = {
        let b = UIButton()
        b.layer.cornerRadius = 8
        b.layer.masksToBounds = true
        b.backgroundColor = .primaryColor
        return b
    }()

    override func setup() {
        super.setup()
        height = { 80 }
        contentView.addSubview(primaryButton)
        constrain(primaryButton) { primaryButton in
            primaryButton.left == primaryButton.superview!.left + 12
            primaryButton.right == primaryButton.superview!.right - 12
            primaryButton.top == primaryButton.superview!.top + 8
            primaryButton.bottom == primaryButton.superview!.bottom - 8
        }
        primaryButton.setTitle(row.title ?? "", for: .normal)
        backgroundColor = .clear
        selectionStyle = .none
        textLabel?.isHidden = true
        detailTextLabel?.isHidden = true
        primaryButton.addTarget(self, action: #selector(primaryButtonDidClick), for: .touchUpInside)
    }

    @objc func primaryButtonDidClick() {
        guard let row = row as? UpdateCartButtonRow, let callback = row.tapCallback else { return }
        callback(self, row)
    }

    override func update() {
        super.update()
        primaryButton.setTitle(row.title ?? "", for: .normal)
    }

}

typealias UpdateCartButtonCallback = (_ cell: UpdateCartButtonRowCell, _ row: UpdateCartButtonRow) -> Void;

final class UpdateCartButtonRow: Row<UpdateCartButtonRowCell>, RowType {

    var tapCallback: UpdateCartButtonCallback?

    required init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<UpdateCartButtonRowCell>()
    }

    func onTap(_ callback: @escaping UpdateCartButtonCallback) -> Self {
        tapCallback = callback;
        return self
    }

}
