import Foundation
import DittoSwift

protocol DittoModel {
    init(document: DittoDocument)
    init(resultItem: [String: Any?])
}

//Needed until DQL supports counters
//Error not triggered if structs implement at least one init
//extension DittoModel {
//    init(document: DittoDocument) {
//        fatalError("Must implement either init(document:) or init(resultItem:)")
//    }
//
//    init(resultItem: [String: Any?]) {
//        fatalError("Must implement either init(document:) or init(resultItem:)")
//    }
//}

