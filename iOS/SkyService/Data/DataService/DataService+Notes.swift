import Foundation
import RxSwift

extension DataService {

    func noteById$(_ id: String?) -> Observable<Note?> {
        guard let id = id else { return Observable.just(nil) }

        let users$ = workspaceId$.flatMapLatest { [weak self] (workspaceId) -> Observable<[User]> in
            guard let `self` = self else { return .empty() }
            return self.users
                .documents$()
                .mapToDittoModel(type: User.self)
        }
        let note$: Observable<Note?> = self.notes.findByID(id).document$().mapToDittoModel(type: Note.self)

        return Observable.combineLatest(users$, note$) { users, note in
            var noteCopy = note;
            noteCopy?.user = users.first(where: { $0.id == note?.userId })
            return noteCopy
        }
    }

    func notes$() -> Observable<[Note]> {
        let justNotes$ = workspaceId$
            .flatMapLatest { [weak self] (workspaceId) -> Observable<[Note]> in
                guard let `self` = self else { return .empty() }
                return self.notes
                    .find("workspaceId == '\(workspaceId)'")
                    .sort("ordinal", direction: .ascending)
                    .documents$()
                    .mapToDittoModel(type: Note.self)
            }
        let users$ = workspaceId$.flatMapLatest { [weak self] (workspaceId) -> Observable<[User]> in
            guard let `self` = self else { return .empty() }
            return self.users
                .documents$()
                .mapToDittoModel(type: User.self)
        }
        return Observable.combineLatest(justNotes$, users$) { notes, users in
            return notes.map({ note in
                var mutableNote = note;
                mutableNote.user = users.first(where: { $0.id == note.userId })
                return mutableNote
            })
        }
    }

    func setNoteCompletion(id: String, isCompleted: Bool) {
        notes.findByID(id).update { (m) in
            m?["isCompleted"].set(isCompleted)
        }
    }

    @discardableResult
    func setNote(id: String?, body: String, isCompleted: Bool, isShared: Bool) -> Result<String, WorkspaceIdError> {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            return Result.failure(WorkspaceIdError.unavailable)
        }
        var noteId: String!
        ditto.store.write { (txn) in
            if let id = id {
                noteId = id
                txn["notes"].findByID(id).update({ (m) in
                    m?["body"].set(body)
                    m?["editedOn"].set(Date().isoDateString)
                    m?["isCompleted"].set(isCompleted)
                    m?["userId"].set(self.userId)
                })
            } else {
                let currentNotes = txn["notes"].find("workspaceId == '\(workspaceId)'").exec()
                let ordinal: Float = {
                    guard let ordinal = currentNotes.last?["ordinal"].float else { return  Float.random(min: 0, max: 1) }
                    return ordinal + 1
                }()
                noteId = try! txn["notes"].upsert([
                    "isCompleted": false,
                    "body": body,
                    "ordinal": ordinal,
                    "userId": self.userId,
                    "createdOn": Date().isoDateString,
                    "editedOn": Date().isoDateString,
                    "isShared": isShared,
                    "workspaceId": workspaceId
                ]).toString()
            }
        }
        return .success(noteId)
    }

    func changeNoteOrdinal(id: String, newOrdinal: Float) {
        self.notes.findByID(id).update { (mutableDoc) in
            mutableDoc?["ordinal"].set(newOrdinal)
        }
    }

    func deleteNoteById(_ id: String) -> Observable<Bool> {
        let deleted = self.notes.findByID(id).remove()
        return Observable.just(deleted)
    }

    func deletePersonalNotes() -> Observable<Void> {
        return workspaceId$
            .flatMapLatest { (workspaceId) -> Observable<Void> in
                self.notes.find("workspaceId == '\(workspaceId)' && userId == '\(DataService.shared.userId)' && isShared == false").remove()
                return Observable.just(())
            }
    }

    func deleteAllNotes() -> Observable<Void> {
        return workspaceId$
            .flatMapLatest { (workspaceId) -> Observable<Void> in
                self.notes.find("workspaceId == '\(workspaceId)'").remove()
                return Observable.just(())
            }
    }

}
