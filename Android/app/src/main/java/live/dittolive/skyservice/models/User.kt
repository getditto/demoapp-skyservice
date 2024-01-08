package live.dittolive.skyservice.models

import live.ditto.DittoDocument
import live.ditto.DittoDocumentId

data class User(
    val resultItem: Map<String, Any?>
) {
    val id: String = resultItem["_id"] as String
    val name: String = resultItem["name"] as String
    val seat: String? = resultItem["seat"] as String
    var deleted = resultItem["deleted"] as Boolean

}
