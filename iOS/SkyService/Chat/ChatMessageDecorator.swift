import Chatto
import ChattoAdditions

class ChatMessageDecorator: ChatItemsDecoratorProtocol {

    struct Constants {
        static let shortSeparation: CGFloat = 3
        static let normalSeparation: CGFloat = 10
        static let timeIntervalThresholdToIncreaseSeparation: TimeInterval = 120
    }

    func decorateItems(_ chatItems: [ChatItemProtocol]) -> [DecoratedChatItem] {
        var decoratedChatItems = [DecoratedChatItem]()
        let calendar = Calendar.current

        for (index, chatItem) in chatItems.enumerated() {
            let next: ChatItemProtocol? = (index + 1 < chatItems.count) ? chatItems[index + 1] : nil
            let prev: ChatItemProtocol? = (index > 0) ? chatItems[index - 1] : nil

            let bottomMargin = self.separationAfterItem(chatItem, next: next)
            var showsTail = false
            var additionalItems =  [DecoratedChatItem]()
            var addTimeSeparator = false
            var isSelected = false
            var isShowingSelectionIndicator = false
            var showName = false

            if let currentMessage = chatItem as? MessageModelProtocol {
                if let nextMessage = next as? MessageModelProtocol {
                    showsTail = currentMessage.senderId != nextMessage.senderId
                    showName = currentMessage.senderId != nextMessage.senderId
                } else {
                    showsTail = true
                    showName = true
                }

                if currentMessage.senderId == DataService.shared.userId {
                    showName = false
                }

                if let previousMessage = prev as? MessageModelProtocol {
                    addTimeSeparator = !calendar.isDate(currentMessage.date, inSameDayAs: previousMessage.date)
                } else {
                    addTimeSeparator = true
                }

                if addTimeSeparator {
                    let dateTimeStamp = DecoratedChatItem(chatItem: TimeSeparatorModel(uid: "\(currentMessage.uid)-time-separator", date: currentMessage.date.toWeekDayAndDateString()), decorationAttributes: nil)
                    decoratedChatItems.append(dateTimeStamp)
                }

                if showName {
                    var username: String = ""
                    if let model = currentMessage as? TextMessageModel<ChatMessage>, let chatMessage = model.messageModel as? ChatMessage {
                        username = chatMessage.user?.name ?? ""
                    }

                    additionalItems.append(
                        DecoratedChatItem(
                            chatItem: NameModel(uid: "\(currentMessage.uid)-name", username: username),
                            decorationAttributes: nil)
                    )
                }
            }

            let messageDecorationAttributes = BaseMessageDecorationAttributes(
                canShowFailedIcon: true,
                isShowingTail: showsTail,
                isShowingAvatar: showsTail,
                isShowingSelectionIndicator: isShowingSelectionIndicator,
                isSelected: isSelected
            )


            decoratedChatItems.append(
                DecoratedChatItem(
                    chatItem: chatItem,
                    decorationAttributes: ChatItemDecorationAttributes(bottomMargin: bottomMargin, messageDecorationAttributes: messageDecorationAttributes)
                )
            )

            decoratedChatItems.append(contentsOf: additionalItems)
        }

        return decoratedChatItems
    }

    private func separationAfterItem(_ current: ChatItemProtocol?, next: ChatItemProtocol?) -> CGFloat {
        guard let nexItem = next else { return 0 }
        guard let currentMessage = current as? MessageModelProtocol else { return Constants.normalSeparation }
        guard let nextMessage = nexItem as? MessageModelProtocol else { return Constants.normalSeparation }

        if self.showsStatusForMessage(currentMessage) {
            return 0
        } else if currentMessage.senderId != nextMessage.senderId {
            return 0
        } else {
            return Constants.shortSeparation
        }
    }

    private func showsStatusForMessage(_ message: MessageModelProtocol) -> Bool {
        return message.status == .failed || message.status == .sending
    }

}
