package live.dittolive.skyservice.models

import live.ditto.DittoDocument
import live.ditto.DittoDocumentId

data class User(
    val document: DittoDocument
) {
    val id: DittoDocumentId = document.id
    val name: String = document["name"].stringValue
    val seat: String? = document["seat"].string
    var deleted = document["deleted"].booleanValue
}
