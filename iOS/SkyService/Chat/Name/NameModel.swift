import UIKit
import Chatto
import ChattoAdditions

class NameModel: ChatItemProtocol {
    let uid: String
    static var chatItemType: ChatItemType {
        return "NameModel"
    }

    var type: String { return NameModel.chatItemType }
    let username: String

    init (uid: String, username: String) {
        self.uid = uid
        self.username = username
    }
}

public class NamePresenterBuilder: ChatItemPresenterBuilderProtocol {

    public func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem is NameModel ? true : false
    }

    public func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        assert(self.canHandleChatItem(chatItem))
        return NamePresenter(
            nameModel: chatItem as! NameModel
        )
    }

    public var presenterType: ChatItemPresenterProtocol.Type {
        return NamePresenter.self
    }
}

class NamePresenter: ChatItemPresenterProtocol {
    let isItemUpdateSupported = false

    func update(with chatItem: ChatItemProtocol) {
        // empty on purpose, just to satisfy compiler
    }

    let nameModel: NameModel
    init (nameModel: NameModel) {
        self.nameModel = nameModel
    }

    static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(NameCollectionViewCell.self, forCellWithReuseIdentifier: "NameCollectionViewCell")
    }

    func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NameCollectionViewCell", for: indexPath)
        return cell
    }

    func configureCell(_ cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        guard let statusCell = cell as? NameCollectionViewCell else {
            assert(false, "expecting status cell")
            return
        }

        let attrs = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12.0),
            NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel,
            NSAttributedString.Key.paragraphStyle: {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = self.nameModel.uid != DataService.shared.userId ? .left : .right
                return paragraph
            }()
        ]
        statusCell.text = NSAttributedString(
            string: self.nameModel.username,
            attributes: attrs)
    }

    var canCalculateHeightInBackground: Bool {
        return true
    }

    func heightForCell(maximumWidth width: CGFloat, decorationAttributes: ChatItemDecorationAttributesProtocol?) -> CGFloat {
        return 30
    }
}
