import Cartography
import RxSwift
import RxCocoa
import RxUIAlert


class NotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    enum NotesType {
        case personal
        case shared

        var title: String {
            switch self {
            case .personal:
                return "Personal notes"
            case .shared:
                return "Shared notes"
            }
        }
    }

    let tableView = UITableView()
    let notesType: NotesType
    var disposeBag = DisposeBag()

    var notes: [Note] = []

    init(notesType: NotesType){
        self.notesType = notesType
        super.init(nibName: nil, bundle: nil)
        self.title = notesType.title
        self.tabBarItem.title = notesType.title
        self.tabBarItem.image = UIImage(named: "notes")
    }

    required init?(coder: NSCoder) {
        fatalError("Not yet implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        view.addSubview(tableView)
        constrain(tableView) { tableView in
            tableView.fillToSuperView()
        }

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil),
            UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: nil, action: nil),
        ]

        navigationItem.rightBarButtonItems![0]
            .rx
            .tap
            .bind { [weak self] _ in
                guard let `self` = self else { return }
                let isShared = self.notesType == NotesType.shared
                guard case .success(let noteId) = DataService.shared.setNote(id: nil, body: "", isCompleted: false, isShared: isShared) else { return }
                self.navigationController?.pushViewController(EditNoteViewController(noteId: noteId), animated: true)
            }
            .disposed(by: disposeBag)

        navigationItem.rightBarButtonItems![1]
            .rx
            .tap
            .flatMapLatest({
                self
                    .rx
                    .alert(
                        title: "Delete all notes?",
                        message: "Are you sure you want to delete all notes?",
                        actions: [
                            AlertAction(title: "Delete notes?", type: 0, style: UIAlertAction.Style.destructive),
                            AlertAction(title: "Cancel", style: UIAlertAction.Style.cancel),
                        ]
                    )
            })
            .flatMapLatest({ [unowned self] action -> Observable<Void> in
                switch self.notesType {
                case .personal:
                    return DataService.shared.deletePersonalNotes()
                case .shared:
                    return DataService.shared.deleteAllNotes()
                }
            })
            .bind { }
            .disposed(by: disposeBag)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true

        DataService.shared.notes$()
            .bind { [weak self] notes in
                guard let `self` = self else { return }

                switch self.notesType {
                case .personal:
                    self.notes = notes.filter({ $0.isShared == false && $0.userId == DataService.shared.userId })
                case .shared:
                    self.notes = notes.filter({ $0.isShared == true })
                }
                self.tableView.reloadData()
            }
            .disposed(by: disposeBag)

        DataService.shared
            .workspaceId$
            .map { WorkspaceId(stringLiteral: $0 )}
            .bind(to: navigationItem.rx.workspaceIdTitleView)
            .disposed(by: disposeBag)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let note = self.notes[indexPath.row]
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.textLabel?.lineBreakMode = .byTruncatingTail

        let onTap = IndexPathTapGestureRecognizer(target: self, action: #selector(checkDidTap(sender:)))
        onTap.numberOfTouchesRequired = 1
        onTap.numberOfTapsRequired = 1
        onTap.indexPath = indexPath

        cell.imageView?.gestureRecognizers?.removeAll()
        cell.imageView?.isUserInteractionEnabled = true
        cell.imageView?.addGestureRecognizer(onTap)

        cell.imageView?.image = note.isCompleted ? UIImage(named: "check_square") : UIImage(named: "square")
        cell.textLabel?.text = note.body
        cell.detailTextLabel?.text = {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .short
            let userName: String = note.user?.name ?? "";
            guard let editedOn = note.editedOn else {
                return "Created: \(dateFormatter.string(from: note.createdOn)) by \(userName)"
            }
            return "Edited on \(dateFormatter.string(from: editedOn)) by \(userName)"
        }()
        return cell
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }
        let noteId = notes[sourceIndexPath.row].id
        let sourceIndex: Int = sourceIndexPath.row
        let destinationIndex: Int = destinationIndexPath.row
        let differentSection = (sourceIndexPath.section != destinationIndexPath.section)
        let newOrdinal = calculateOrdinal(sourceIndex: sourceIndex, destinationIndex: destinationIndex, items: notes, differentSection: differentSection)
        DataService.shared.changeNoteOrdinal(id: noteId, newOrdinal: newOrdinal)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = notes[indexPath.row]
        navigationController?.pushViewController(EditNoteViewController(noteId: note.id), animated: true)
    }

    @objc func checkDidTap(sender: IndexPathTapGestureRecognizer) {
        guard let indexPath = sender.indexPath else { return }
        let note = notes[indexPath.row]
        DataService.shared.setNoteCompletion(id: note.id, isCompleted: !note.isCompleted)
    }

}
