import UIKit
import Chatto
import ChattoAdditions

class ChatTextMessageViewModel: TextMessageViewModel<ChatTextMessageModel> {

    override init(textMessage: ChatTextMessageModel, messageViewModel: MessageViewModelProtocol) {
        super.init(textMessage: textMessage, messageViewModel: messageViewModel)
    }

    var messageModel: MessageModelProtocol {
        return self.textMessage
    }

}

class ChatTextMessageViewModelBuilder: ViewModelBuilderProtocol {

    static let dateFormatter = DateFormatter()

    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is ChatTextMessageModel
    }

    func createViewModel(_ model: ChatTextMessageModel) -> ChatTextMessageViewModel {
        let messageViewModel = MessageViewModel(dateFormatter: Self.dateFormatter,
                                                messageModel: model,
                                                avatarImage: nil,
                                                decorationAttributes: BaseMessageDecorationAttributes())

        let textMessageViewModel = ChatTextMessageViewModel(textMessage: model, messageViewModel: messageViewModel)
        return textMessageViewModel

    }

    typealias ModelT = ChatTextMessageModel

    typealias ViewModelT = ChatTextMessageViewModel


}
