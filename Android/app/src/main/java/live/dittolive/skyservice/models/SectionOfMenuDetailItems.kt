package live.dittolive.skyservice.models

class SectionOfMenuDetailItems(val menuItem: MenuItem, val options: List<MenuItemOption>) {

    fun buildData(): List<RowOfCartItem> {
        val list = mutableListOf<RowOfCartItem>()
        list.add(RowOfCartItem(RowOfCartItem.Type.HEADER,"DETAILS"))
        list.add(RowOfCartItem(RowOfCartItem.Type.DESCRIPTION, menuItem.details))

        for (option in options) {
            list.addAll(RowOfCartItem.setMenuItemOption(option))
        }

        list.add(RowOfCartItem(RowOfCartItem.Type.ACTION_ITEM))
        return list
    }
}

data class RowOfCartItem(val type: Type, val text: String = "", val menuOption: MenuItemOption? = null, var freeText: String = "") {

    var isRequired = false
    var checked: Boolean = false

    enum class Type {
        HEADER,
        DESCRIPTION,
        SINGLE_SELECTION,
        MULTIPLE_SELECTION,
        FREE_TEXT,
        ACTION_ITEM,
    }

    companion object {
        fun setMenuItemOption(option: MenuItemOption): List<RowOfCartItem> {
            val list = mutableListOf<RowOfCartItem>()
            val type = getOptionType(option.type)
            if (type == Type.FREE_TEXT) {
                list.add(RowOfCartItem(Type.HEADER, ""))
                val item = RowOfCartItem(type, option.label, option)
                item.isRequired = option.isRequired
                list.add(item)
            } else {
                list.add(RowOfCartItem(Type.HEADER, option.label))
                for (value in option.allowedValues) {
                    val item = RowOfCartItem(type, value, option)
                    item.isRequired = option.isRequired
                    list.add(item)
                }
            }
            return list
        }

        fun getOptionType(type: MenuItemOption.Companion.MenuItemOptionType): Type {
            when (type) {
                MenuItemOption.Companion.MenuItemOptionType.single -> return Type.SINGLE_SELECTION
                MenuItemOption.Companion.MenuItemOptionType.multiple -> return Type.MULTIPLE_SELECTION
                MenuItemOption.Companion.MenuItemOptionType.text -> return Type.FREE_TEXT
            }
        }
    }
}
