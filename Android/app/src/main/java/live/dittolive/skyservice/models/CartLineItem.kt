package live.dittolive.skyservice.models

import live.ditto.DittoDocument

class CartLineItem(document: DittoDocument) {

    var id: String
    var menuItemId: String
    var quantity: Int
    var userId: String
    var options: List<String>
    var orderId: String? = null
    var deleted: Boolean

    init {
        this.id = document.id.toString()
        this.menuItemId = document["menuItemId"].stringValue
        this.userId = document["userId"].stringValue
        this.quantity = document["quantity"].intValue
        this.userId = document["userId"].stringValue
        this.options = document["options"].listValue.map { it as? String? ?: "" }
        this.orderId = document["orderId"].string
        this.deleted = document["deleted"].booleanValue
    }
}

data class CartLineItemWithMenuItem(val cartLineItem: CartLineItem, val menuItem: MenuItem)
