import Foundation
import RxSwift
import DittoSwift

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
                    .find("workspaceId == '\(workspaceId)' && deleted == false")
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

    func setNoteCompletion(id: String, isCompleted: Bool) async {
        do{
            let query = "UPDATE notes SET isCompleted = :isCompleted WHERE _id = :id"
            
            let args: [String:Any] = [
                "isCompleted": isCompleted,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
            
        } catch {
            print("Error \(error)")
        }
    }

    @discardableResult
    func setNote(id: String?, body: String, isCompleted: Bool, isShared: Bool) async -> Result<String, WorkspaceIdError> {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else {
            return Result.failure(WorkspaceIdError.unavailable)
        }
        var noteId: String!
        
        do{
            if let id = id {
                noteId = id

                let query = "UPDATE notes SET body = :body, editedOn = :editedOn, isCompleted = :isCompleted, userId = :userId WHERE _id = :id"
                
                let args: [String:Any] = [
                    "body": body,
                    "editedOn": Date().isoDateString,
                    "isCompleted": isCompleted,
                    "userId": self.userId,
                    "id": id
                ]
                
                try await self.ditto.store.execute(query: query, arguments: args)
                
            } else {
                let currentNotesResult = try await ditto.store.execute(query: "SELECT * FROM notes WHERE workspaceId = :workspaceId AND deleted = 'false'", arguments: ["workspaceId": workspaceId]).items
                
                let ordinal: Float = {
                    guard let lastOrdinal = currentNotesResult.last?.value["ordinal"] as? Float else {
                        return Float.random(min: 0, max: 1)
                    }
                    return lastOrdinal + 1
                }()
                
                let newDoc: [String:Any] = [
                    "isCompleted": false,
                    "body": body,
                    "ordinal": ordinal,
                    "userId": self.userId,
                    "createdOn": Date().isoDateString,
                    "editedOn": Date().isoDateString,
                    "isShared": isShared,
                    "workspaceId": workspaceId,
                    "deleted": false
                ]
                
                let noteResult = try await self.ditto.store.execute(query: "INSERT INTO notes DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
                noteId = noteResult.mutatedDocumentIDs().first?.stringValue

            }
        } catch {
            print("Error \(error)")
        }
        
        return .success(noteId)
    }

    func changeNoteOrdinal(id: String, newOrdinal: Float) async {        
        do{
            let query = "UPDATE notes SET ordinal = :ordinal WHERE _id = :id"
            
            let args: [String:Any] = [
                "ordinal": newOrdinal,
                "id": id
            ]
            
            try await self.ditto.store.execute(query: query, arguments: args)
        } catch {
          print("Error \(error)")
        }
    }

    func deleteNoteById(_ id: String) -> Observable<Bool> {
        return Observable.create { observer in
            Task {
                do {
                    let query = "UPDATE notes SET deleted = :deleted WHERE _id = :id"

                    let args: [String:Any] = [
                        "deleted": true,
                        "id": id
                    ]

                    try await self.ditto.store.execute(query: query, arguments: args)

                    let result = try await self.ditto.store.execute(query: "SELECT * FROM notes WHERE _id = id", arguments: ["id": id]).items.first?.value["deleted"] as? Bool ?? true
                    
                    DispatchQueue.main.async {
                        observer.onNext(result)
                        observer.onCompleted()
                    }
                } catch {
                    print("Error \(error)")

                    DispatchQueue.main.async {
                        observer.onError(error)
                    }
                }
            }

            return Disposables.create()
        }

    }

    func deletePersonalNotes() -> Observable<Void> {
        return workspaceId$
            .flatMapLatest { (workspaceId) -> Observable<Void> in
                
                Task {
                    do {
                        
                        let noteDocs = try await self.ditto.store.execute(query: "SELECT * FROM notes WHERE workspaceId = :workspaceId AND userId = :userId", arguments: ["workspaceId": workspaceId, "userId": DataService.shared.userId]).items
                        
                        for result in noteDocs {
                            let query = "UPDATE notes SET deleted = :deleted WHERE _id = :id"
                            
                            let args: [String:Any] = [
                                "deleted": true,
                                "id": result.value["_id"] as Any
                            ]
                            
                            try await self.ditto.store.execute(query: query, arguments: args)
                        }
                        
                    } catch {
                        print("Error \(error)")
                    }
                }
                
                return Observable.just(())
            }
    }

    func deleteAllNotes() -> Observable<Void> {
        return workspaceId$
            .flatMapLatest { (workspaceId) -> Observable<Void> in

                Task {
                    do {
                        
                        let noteDocs = try await self.ditto.store.execute(query: "SELECT * FROM notes WHERE workspaceId = :workspaceId AND isShared = :isShared", arguments: ["workspaceId": workspaceId, "isShared": true]).items
                        
                        for result in noteDocs {
                            let query = "UPDATE notes SET deleted = :deleted WHERE _id = :id"
                            
                            let args: [String:Any] = [
                                "deleted": true,
                                "id": result.value["_id"] as Any
                            ]
                            
                            try await self.ditto.store.execute(query: query, arguments: args)
                        }
                        
                    } catch {
                        print("Error \(error)")
                    }
                }
                
                return Observable.just(())
            }
    }

}
