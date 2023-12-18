import UIKit
import DittoSwift
import RxSwift
import RxCocoa
import SwiftHEXColors
import Cartography

extension UserDefaults {
    
    var lastTabIndex: Int {
        get {
            return self.integer(forKey: "lastTabIndex")
        } set(val) {
            self.setValue(val, forKey: "lastTabIndex")
        }
    }
    
    var workspaceId: WorkspaceId?  {
        get {
            guard let v = self.string(forKey: "workspaceId") else { return nil }
            return WorkspaceId(stringLiteral: v)
        } set(val) {
            self.setValue(val?.description, forKey: "workspaceId")
        }
    }
    
    var cachedPassword: String? {
        get {
            return self.string(forKey: "cachedPassword")
        } set(val) {
            self.setValue(val, forKey: "cachedPassword")
        }
    }
    
    var cachedFlightNumber: String? {
        get {
            return self.string(forKey: "cachedFlightNumber")
        } set(val) {
            self.setValue(val, forKey: "cachedFlightNumber")
        }
    }
    
    var cachedDepartureDate: Date? {
        get {
            guard let val = self.string(forKey: "cachedFlightNumber") else { return nil }
            return WorkspaceId.dateFormatter.date(from: val)
        } set(val) {
            guard let val = val else {
                self.setValue(nil, forKey: "cachedFlightNumber")
                return 
            }
            self.setValue(WorkspaceId.dateFormatter.string(from: val), forKey: "cachedFlightNumber")
        }
    }
    
    var cachedName: String? {
        get {
            return self.string(forKey: "cachedName")
        } set(val) {
            self.setValue(val, forKey: "cachedName")
        }
    }
    
    var cachedSeat: String? {
        get {
            return self.string(forKey: "cachedSeat")
        } set(val) {
            self.setValue(val, forKey: "cachedSeat")
        }
    }
    
    var askedForNotificationPermission: Bool {
        get {
            return self.bool(forKey: "askedForNotificationPermission")
        } set(val) {
            self.setValue(val, forKey: "askedForNotificationPermission")
        }
    }
    
    var localNotes: String? {
        get {
            return self.string(forKey: "localNotes")
        } set(val) {
            self.setValue(val, forKey: "localNotes")
        }
    }

    var currentAppVersion: String? {
        get {
            return self.string(forKey: "currentAppVersion")
        } set(val) {
            self.setValue(val, forKey: "currentAppVersion")
        }
    }
}

extension Bundle {
    var isCrew: Bool {
        return self.bundleIdentifier?.split(separator: ".").last?.lowercased() == "crew"
    }
    
    var releaseVersionNumber: String? {
        return self.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    var buildVersionNumber: String? {
        return self.infoDictionary?["CFBundleVersion"] as? String
    }
}

extension Float {
    /// Random float between 0 and n-1.
    ///
    /// - Parameter n:  Interval max
    /// - Returns:      Returns a random float point number between 0 and n max
    static func random(min: Float, max: Float) -> Float {
        return Float.random(in: min..<max)
    }
}

extension UIColor {
    static var primaryColor: UIColor {
        return UIColor(hexString: "#0074D9")!
    }
}

extension Date {
    var isoDateString: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
    
    init(dateString: String) {
        let formatter = ISO8601DateFormatter()
        self = formatter.date(from: dateString) ?? Date()
    }
}

extension String {
    func toDittoID() -> DittoDocumentID {
        return DittoDocumentID(value: self)
    }
}

extension UInt64 {
    
    static var random: UInt64 {
        
        let hex = UUID().uuidString
            .components(separatedBy: "-")
            .suffix(2)
            .joined()
        
        return UInt64(hex, radix: 0x10)!
    }
}

extension DittoCollection {
    
    func documents$() -> Observable<[DittoDocument]> {
        return self.findAll().documents$()
    }

    func findByID(_ id: String) -> DittoPendingIDSpecificOperation {
        return findByID(id.toDittoID())
    }
}

struct DocumentsWithEventInfo {
    var documents: [DittoDocument]
    var liveQueryEvent: DittoLiveQueryEvent

    var insertedDocuments: [DittoDocument] {
        if case let .update(updateInfo) = self.liveQueryEvent {
            return updateInfo.insertions.map({ index in self.documents[index] })
        }
        return []
    }
    var updatedDocuments: [DittoDocument] {
        if case let .update(updateInfo) = self.liveQueryEvent {
            return updateInfo.updates.map({ index in self.documents[index] })
        }
        return []
    }
    var removedDocuments: [DittoDocument] {
        if case let .update(updateInfo) = self.liveQueryEvent {
            return updateInfo.deletions.map({ index in updateInfo.oldDocuments[index] })
        }
        return []
    }
}

extension Ditto {
    
    func resultItems$(query: String, args: [String:Any?]? = nil) -> Observable<[DittoQueryResultItem]> {
        return Observable.create { (observer) -> Disposable in
            
            do {
                var subs: DittoSyncSubscription
                var handler: DittoStoreObserver
                
                if args == nil {
                    subs = try self.sync.registerSubscription(query: query)
                    
                    handler = try self.store.registerObserver(query: query) { [weak self] result in
                        guard let self = self else { return }
                        
                        observer.onNext(result.items)
                    }
                    
                } else {
                    subs = try self.sync.registerSubscription(query: query, arguments: args)
                    
                    handler = try self.store.registerObserver(query: query, arguments: args) { [weak self] result in
                        guard let self = self else { return }
                        
                        observer.onNext(result.items)
                    }
                }
                
                return Disposables.create {
                    subs.cancel()
                    handler.cancel()
                }
            } catch {
                print("Error \(error)")
                
                return Disposables.create {}
            }
        }
    }
}

//Needed until Counters are supported in DQL
extension DittoPendingCursorOperation {
    
    func documents$() -> Observable<[DittoDocument]> {
        return Observable.create { (observer) -> Disposable in
            
            let subs = self.subscribe()
            let handler = self.observeLocal { (docs, _) in
                observer.onNext(docs)
            }
            
            return Disposables.create {
                subs.cancel()
                handler.stop()
            }
        }
    }
    
    func documentsWithEventInfo$() -> Observable<DocumentsWithEventInfo> {
        return Observable.create { (observer) -> Disposable in
            
            let s = self.subscribe()
            let h = self.observeLocal { (docs, event) in
                observer.onNext(DocumentsWithEventInfo(documents: docs, liveQueryEvent: event))
            }
            
            return Disposables.create {
                h.stop()
                s.cancel()
            }
        }
    }
    
}

extension DittoScopedWriteTransaction {
    func findByID(_ id: String) -> DittoWriteTransactionPendingIDSpecificOperation {
        return findByID(id.toDittoID())
    }
}

extension DittoPendingIDSpecificOperation {
    func document$() -> Observable<DittoDocument?> {
        return Observable.create { (observer) -> Disposable in
            let handler = self.observeLocal { (docs, _) in
                observer.onNext(docs)
            }
            let s = self.subscribe()
            
            return Disposables.create {
                handler.stop()
                s.cancel()
            }
        }
    }
}

//Needed until DQL supports Counters
extension Observable where Element == Array<DittoDocument> {
    
    func mapToDittoModel<T: DittoModel>(type: T.Type) -> Observable<Array<T>> {
        return self.map({ $0.map { T(document: $0) } })
    }
}

extension Observable where Element == DittoDocument? {
    
    func mapToDittoModel<T: DittoModel>(type: T.Type) -> Observable<T?> {
        return self.map { doc in
            guard let doc = doc else { return nil }
            return T(document: doc)
        }
    }
}

extension Observable where Element == Array<DittoQueryResultItem> {
    
    func mapToDittoModel<T: DittoModel>(type: T.Type) -> Observable<Array<T>> {
        return self.map({ $0.map { T(resultItem: $0.value) } })
    }
}

extension Observable where Element == DittoQueryResultItem? {
    
    func mapToDittoModel<T: DittoModel>(type: T.Type) -> Observable<T?> {
        return self.map { resultItem in
            guard let resultItem = resultItem else { return nil }
            return T(resultItem: resultItem.value)
        }
    }
}

extension ViewProxy {
    
    func fillToSuperView() {
        self.left == self.superview!.left
        self.right == self.superview!.right
        self.top == self.superview!.top
        self.bottom == self.superview!.bottom
    }
    
}

extension Observable {
    
    func subscribeNext(_ callback: @escaping (Element) -> Void) -> Disposable  {
        return self.subscribe { (event) in
            switch event {
            case .next(let element):
                callback(element)
            case .error(_):
                break
            case .completed:
                break
            }
        }
    }
    
}


extension UIViewController {
    func showPermissionsMissing( _ messages: [String]) {
        var alertMessages = messages
        let alert = UIAlertController(title: "Missing Permission", message: alertMessages.first, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Enable Permission", style: .default, handler: {  _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            alertMessages.removeFirst()
            if alertMessages.count > 0 {
                self.showPermissionsMissing(alertMessages)
            }
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: {  _ in
            alertMessages.removeFirst()
            if alertMessages.count > 0 {
                self.showPermissionsMissing(alertMessages)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
}


extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        
        return self[index]
    }
}

extension Array where Element:Equatable {
    func removeDuplicates() -> [Element] {
        var result = [Element]()
        
        for value in self {
            if result.contains(value) == false {
                result.append(value)
            }
        }
        
        return result
    }
}

extension Reactive where Base: UINavigationItem {
    
    var workspaceIdTitleView: AnyObserver<WorkspaceId> {
        return AnyObserver { [weak weakControl = base] o in
            switch o {
            case .next(let workspaceId):
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                let dateString = dateFormatter.string(from: workspaceId.departureDate)
                weakControl?.titleView = setTitle(title: workspaceId.flightNumber, subtitle: dateString)
                break
            default:
                weakControl?.titleView = nil
                break
            }
        }
    }
    
}

extension UITextView {

  func addDoneButtonInKeyboard() {
    let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
    doneToolbar.barStyle = .default

    let flexSpaceBarButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let doneBarButton: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.doneButtonAction))

    let items = [flexSpaceBarButton, doneBarButton]
    doneToolbar.items = items
    doneToolbar.sizeToFit()

    self.inputAccessoryView = doneToolbar
  }

  @objc private func doneButtonAction() {
    self.resignFirstResponder()
  }
}
