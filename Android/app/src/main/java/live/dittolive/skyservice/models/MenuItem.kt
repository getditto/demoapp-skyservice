package live.dittolive.skyservice.models

import live.ditto.DittoDocument
import live.dittolive.skyservice.toISODate
import org.joda.time.DateTime
import java.util.*
import kotlin.random.Random

data class MenuItem(val document: DittoDocument) {
    val id: String = document.id.toString()
    val name: String = document["name"].stringValue
    val details: String = document["details"].stringValue
    val categoryId: String? = document["categoryId"].string
    var totalCount: Int? = document["totalCount"].int
    var usedCount: Int? = document["usedCount"].int
    var isCrewOnly: Boolean = document["isCrewOnly"].booleanValue

    var ordinal: Float? = null

    var category: Category? = null
    var cartLineItems: List<CartLineItem>? = null
    var options: List<MenuItemOption>? = null

    init {
        document["ordinal"].float?.also {
            this.ordinal = it
        } ?: run {
            this.ordinal = Random.nextDouble(0.0, 0.5).toFloat()
        }
    }

    val remainsCount: Int?
    get() {
        totalCount?.let { total ->
            val used = usedCount ?: 0
            return total - used
        }

        return null
    }
}
