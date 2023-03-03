import Chatto
import ChattoAdditions

class ChatTextMessageModel: TextMessageModel<ChatMessage> {

    init(chatMessage: ChatMessage) {
        super.init(messageModel: chatMessage, text: chatMessage.body)
    }

    var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }
}

