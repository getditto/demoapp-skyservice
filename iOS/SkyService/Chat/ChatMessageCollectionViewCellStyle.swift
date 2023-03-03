import Chatto
import ChattoAdditions

class BaseChatCellStyle: BaseMessageCollectionViewCellDefaultStyle {

    init() {
        super.init(
            colors: Colors(incoming: .secondarySystemFill, outgoing: .primaryColor),
            replyIndicatorStyle: .init(
                image: UIImage(named: "reply-indicator")!,
                size: .init(width: 38, height: 38),
                maxOffsetToReplyIndicator: 48
            )
        )
    }

    override func avatarSize(viewModel: MessageViewModelProtocol) -> CGSize {
        // Display avatar for both incoming and outgoing messages for demo purpose
        return CGSize.zero
    }

}

class BaseChatTextStyle: TextMessageCollectionViewCellDefaultStyle {


    init(baseStyle: BaseChatCellStyle) {
        let textStyle = TextMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 16),
                    incomingColor: UIColor.white,
                    outgoingColor: UIColor.white,
                    incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
                    outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
                )
        super.init(textStyle: textStyle, baseStyle: baseStyle)
    }

}
