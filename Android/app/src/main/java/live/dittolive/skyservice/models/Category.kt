package live.dittolive.skyservice.models

import live.ditto.DittoDocument

data class Category(val document: DittoDocument) {
    val id: String = document.id.toString()
    val name: String = document["name"].stringValue
    val ordinal: Float = document["ordinal"].floatValue
    val isCrewOnly: Boolean = document["isCrewOnly"].booleanValue
}
