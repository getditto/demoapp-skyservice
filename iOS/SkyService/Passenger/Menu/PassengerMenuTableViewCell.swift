import UIKit
import RxSwift

class PassengerMenuTableViewCell: UITableViewCell {

    static let REUSE_ID = "PassengerMenuTableViewCell"
    let addButton = AddToCartButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))

    var disposeBag = DisposeBag()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.accessoryView = addButton
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

}
