package live.dittolive.skyservice.models

import live.ditto.DittoDocument

data class MenuItemOption(val document: DittoDocument) {

    var id: String = document.id.toString()
    var label: String = document["label"].stringValue
    var menuItemId = document["menuItemId"].stringValue
    var type = MenuItemOptionType.valueOf(document["type"].stringValue)
    var isRequired: Boolean = document["isRequired"].booleanValue
    var allowedValues = document["allowedValues"].listValue.map { it as? String ?: "" }
    var deleted = document["deleted"].booleanValue

    companion object {
        enum class MenuItemOptionType constructor(val value: String) {
            single("single"),
            multiple("multiple"),
            text("text");

            val formTitle: String
                get() {
                    when (this) {
                        single -> return "Single Option"
                        multiple -> return "Multiple Option"
                        text -> return "Free Text"
                    }
                }
        }
    }
}
