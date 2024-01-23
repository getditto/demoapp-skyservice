package live.dittolive.skyservice.models

import live.ditto.DittoDocument
import live.dittolive.skyservice.toISODate
import org.joda.time.DateTime
import java.util.*
import kotlin.random.Random

data class MenuItem(val resultItem: Map<String, Any?>) {
    val id: String = resultItem["_id"] as String
    val name: String = resultItem["name"] as String
    val details: String = resultItem["details"] as String
    val categoryId: String? = resultItem["categoryId"] as String
    var isCrewOnly: Boolean = resultItem["isCrewOnly"] as Boolean? ?: false
    var deleted = resultItem["deleted"] as Boolean


    var ordinal: Float? = null

    var category: Category? = null
    var cartLineItems: List<CartLineItem>? = null
    var options: List<MenuItemOption>? = null

    init {
        resultItem["ordinal"] as? Float ?: run {
            this.ordinal = 0.0.toFloat()
        }
    }
}
