package live.dittolive.skyservice.models
//OrderSection(order: order, user: user, cartLineItemsWithMenuItems: cartLineItemWithMenuItems)
data class SectionOfOrderItems(val itemType: Type, val order: Order, val cartLineItemsWithMenuItems: CartLineItemWithMenuItem? = null) {
    enum class Type {
        HEADER,
        ITEM,
        FOOTER
    }
}
