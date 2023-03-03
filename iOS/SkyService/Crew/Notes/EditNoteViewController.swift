import RxCocoa
import RxSwift
import RxUIAlert
import Cartography
import RSKPlaceholderTextView
import IQKeyboardManagerSwift

class EditNoteViewController: UIViewController {

    var disposeBag = DisposeBag()
    let noteId: String
    var isShared$ = BehaviorRelay<Bool>(value: false)

    lazy var textView: RSKPlaceholderTextView = {
        let t = RSKPlaceholderTextView()
        t.placeholder = "Your note here.."
        t.placeholderColor = .secondaryLabel
        t.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        t.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return t
    }()

    var isCompleted$ = BehaviorRelay<Bool>(value: false)

    init(noteId: String) {
        self.noteId = noteId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        IQKeyboardManager.shared.enable = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Edit Note"
        self.view.addSubview(textView)
        constrain(textView) { textView in
            textView.top == textView.superview!.safeAreaLayoutGuide.top
            textView.right == textView.superview!.safeAreaLayoutGuide.right
            textView.left == textView.superview!.safeAreaLayoutGuide.left
            textView.bottom == textView.superview!.safeAreaLayoutGuide.bottom
        }
        let trashBarButtonItem = UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: nil, action: nil)
        let completedBarButtonItem = UIBarButtonItem(image: UIImage(named: "square"), style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItems = [
            trashBarButtonItem,
            completedBarButtonItem
        ]

        trashBarButtonItem
            .rx
            .tap
            .flatMapLatest({ _ in
                            return self.rx.alert(title: "Delete this note?", actions: [
                                AlertAction(title: "Yes, Delete", style: .destructive),
                                AlertAction(title: "Cancel", style: .cancel)
                            ]) })
            .filter({ $0.alertAction.style == .destructive })
            .flatMapLatest { [unowned self] _ in
                return DataService.shared.deleteNoteById(self.noteId)
            }
            .bind { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)

        isCompleted$
            .map { $0 ? UIImage(named: "check_square") : UIImage(named: "square") }
            .bind { image in
                completedBarButtonItem.image = image
            }
            .disposed(by: disposeBag)

        completedBarButtonItem
            .rx
            .tap
            .bind { [unowned self] in
                let value = self.isCompleted$.value
                self.isCompleted$.accept(!value)
                self.saveNote()
            }
            .disposed(by: disposeBag)

        textView.rx.didChange.subscribe(onNext: { [weak self] in
            guard let self = self else { return }
            self.saveNote()
        }).disposed(by: disposeBag)

        let note$ = DataService.shared
            .noteById$(noteId).share(replay: 1, scope: .forever)


        note$
            .map({ $0?.isShared ?? false })
            .bind(to: self.isShared$)
            .disposed(by: disposeBag)

        note$
            .map({ $0?.body ?? "" })
            .bind(to: self.textView.rx.text)
            .disposed(by: disposeBag)

        note$
            .map({ $0?.isCompleted ?? false })
            .distinctUntilChanged()
            .bind(to: self.isCompleted$)
            .disposed(by: disposeBag)

    }

    func saveNote() {
        DataService.shared.setNote(id: noteId, body: textView.text, isCompleted: isCompleted$.value, isShared: isShared$.value)
    }

}

