import Chatto
import RxSwift

class ChatDataSource: ChatDataSourceProtocol {

    var disposeBag = DisposeBag()

    var hasMoreNext: Bool = false

    var hasMorePrevious: Bool = false

    var chatItems: [ChatItemProtocol] = []

    var delegate: ChatDataSourceDelegateProtocol?

    var isInitial: Bool = true

    func loadNext() {

    }

    func loadPrevious() {

    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion: (Bool) -> Void) {

    }

    init() {
        DataService.shared.chatMessages$()
            .subscribeNext { [weak self] (chatMessages) in
                guard let `self` = self else { return }
                self.chatItems = chatMessages.map({ ChatTextMessageModel(chatMessage: $0) })
                self.delegate?.chatDataSourceDidUpdate(self)
                self.delegate?.chatDataSourceDidUpdate(self, updateType: self.isInitial ? .firstLoad : .normal)
                self.isInitial = true
            }
            .disposed(by: disposeBag)
    }

    deinit {
        disposeBag = DisposeBag()
    }

}
