package live.dittolive.skyservice.models

import live.ditto.DittoDocument

data class Category(val resultItem: Map<String, Any?>) {
    val id: String = resultItem["_id"] as String
    val name: String = resultItem["name"] as String
    val ordinal: Double = resultItem["ordinal"] as Double
    val isCrewOnly: Boolean = resultItem["isCrewOnly"] as Boolean
    var deleted = resultItem["deleted"] as Boolean
}
