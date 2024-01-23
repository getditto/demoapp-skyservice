package live.dittolive.skyservice.models

import live.ditto.DittoDocument

class CartLineItem(resultItem: Map<String, Any?>) {

    var id: String
    var menuItemId: String
    var quantity: Int
    var userId: String
    var options: List<String>
    var orderId: String? = ""
    var deleted: Boolean

    init {
        this.id = resultItem["_id"] as String
        this.menuItemId = resultItem["menuItemId"] as String
        this.userId = resultItem["userId"] as String
        this.quantity = resultItem["quantity"] as Int
        this.options = (resultItem["options"] as? Array<*>)?.filterIsInstance<String>() ?: emptyList()
        this.orderId = resultItem["orderId"] as String? ?: ""
        this.deleted = resultItem["deleted"] as Boolean
    }
}

data class CartLineItemWithMenuItem(val cartLineItem: CartLineItem, val menuItem: MenuItem)
