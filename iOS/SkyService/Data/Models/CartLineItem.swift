import Foundation
import DittoSwift

struct CartLineItem: DittoModel, Equatable {
    var id: String
    var menuItemId: String
    var quantity: Int
    var userId: String
    // these were the selected string values.
    var options: [String]
    var deleted: Bool

    /**
     If the orderId is nil, then it's in the cart
     If the orderId has a value then it's already an open order
     */
    var orderId: String?

    init(document: DittoDocument) {
        self.id = document.id.toString()
        self.menuItemId = document["menuItemId"].stringValue
        self.quantity = document["quantity"].intValue
        self.userId = document["userId"].stringValue
        self.options = document["options"].register?.arrayValue.compactMap({ $0 as? String }) ?? []
        self.orderId = document["orderId"].string
        self.deleted = document["deleted"].boolValue
    }
}

/**
 This extension is just to help creating orders
 */
extension CartLineItem {

    init(from dictionary: [String: Any]) throws {
        self.id = dictionary["id"] as! String
        self.menuItemId = dictionary["menuItemId"] as! String
        self.quantity = dictionary["quantity"] as! Int
        self.userId = dictionary["userId"] as! String
        self.options = dictionary["options"] as! [String]
        self.deleted = dictionary["deleted"] as! Bool
    }

    var asDictionary: [String: Any] {
        return [
            "id": id,
            "menuItemId": menuItemId,
            "quantity": quantity,
            "userId": userId,
            "options": options,
            "deleted": deleted
        ]
    }

}
