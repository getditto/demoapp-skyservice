import UIKit
import RxSwift
import Chatto
import ChattoAdditions
import Cartography
import RSKPlaceholderTextView


class ChatViewController: BaseChatViewController {

    var dataSource: ChatDataSource! {
        didSet {
            self.chatDataSource = self.dataSource
        }
    }

    var disposeBag = DisposeBag()
    var chatInputView: ChatInputView!

    init() {
        super.init(nibName: nil, bundle: nil)
        self.tabBarItem.title = "Chat"
        self.tabBarItem.image = UIImage(named: "chat")
        self.navigationItem.title = "Crew Chat"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        self.dataSource = ChatDataSource()
        chatInputView = ChatInputView()
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground
        self.collectionView?.backgroundColor = UIColor.systemBackground
        self.chatItemsDecorator = ChatMessageDecorator()
        chatInputView.sendButton.addTarget(self, action: #selector(sendButtonDidClick), for: .touchUpInside)
        self.dataSource.delegate?.chatDataSourceDidUpdate(self.dataSource)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: self, action: #selector(clearChatMessages))

        DataService.shared
            .workspaceId$
            .map { WorkspaceId(stringLiteral: $0 )}
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)
    }

    override func createChatInputView() -> UIView {
        return chatInputView
    }

    func createTextMessageViewModelBuilder() -> ChatTextMessageViewModelBuilder {
        return ChatTextMessageViewModelBuilder()
    }

    override func createPresenterBuilders() -> [ChatItemType : [ChatItemPresenterBuilderProtocol]] {
        let textMessagePresenter = TextMessagePresenterBuilder(
            viewModelBuilder: self.createTextMessageViewModelBuilder(),
            interactionHandler: ChatMessageInteractionHandler()
        )
        let baseStyle = BaseChatCellStyle()
        textMessagePresenter.baseMessageStyle = BaseChatCellStyle()
        textMessagePresenter.textCellStyle = BaseChatTextStyle(baseStyle: baseStyle)

        return [
            ChatMessage.chatItemType: [textMessagePresenter],
            NameModel.chatItemType: [NamePresenterBuilder()],
            TimeSeparatorModel.chatItemType: [TimeSeparatorPresenterBuilder()]
        ]
    }

    @objc func sendButtonDidClick() {
        guard let text = chatInputView.textView.text, text.count > 0 else { return }
        chatInputView.textView.text = ""
        Task {
            await DataService.shared.sendChatMessage(body: text)
        }
    }

    @objc func clearChatMessages(barButtonItem: UIBarButtonItem) {
        let alert = UIAlertController(title: "Delete?", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Yes, Delete all messages", style: .destructive, handler: { (_) in
            Task {
                await DataService.shared.deleteAllChatMessages()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if UIDevice.current.userInterfaceIdiom == .pad {
            alert.modalPresentationStyle = .popover
            alert.popoverPresentationController?.barButtonItem = barButtonItem
        }
        present(alert, animated: true, completion: nil)
    }

}
