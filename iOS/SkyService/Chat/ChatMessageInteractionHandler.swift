import UIKit
import Chatto
import ChattoAdditions

class ChatMessageInteractionHandler: BaseMessageInteractionHandlerProtocol {
    func userDidDoubleTapOnBubble(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidTapOnFailIcon(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel, failIconView: UIView) {

    }

    func userDidTapOnAvatar(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidTapOnBubble(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidBeginLongPressOnBubble(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidEndLongPressOnBubble(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidSelectMessage(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    func userDidDeselectMessage(message: ChatTextMessageModel, viewModel: ChatTextMessageViewModel) {

    }

    typealias MessageType = ChatTextMessageModel

    typealias ViewModelType = ChatTextMessageViewModel
}
