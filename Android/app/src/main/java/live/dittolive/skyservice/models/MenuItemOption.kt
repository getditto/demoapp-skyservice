package live.dittolive.skyservice.models

import live.ditto.DittoDocument

data class MenuItemOption(val resultItem: Map<String, Any?>) {

    var id: String = resultItem["_id"] as String
    var label: String = resultItem["label"] as String
    var menuItemId = resultItem["menuItemId"] as String
    var type = MenuItemOptionType.valueOf(resultItem["type"] as String)
    var isRequired: Boolean = resultItem["isRequired"] as Boolean
    var allowedValues = listOf(resultItem["allowedValues"] as String)
    var deleted = resultItem["deleted"] as String

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
