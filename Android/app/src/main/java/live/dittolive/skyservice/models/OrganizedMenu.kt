package live.dittolive.skyservice.models

data class OrganizedMenu(var itemType: Type, val category: Category? = null, val item: MenuItem? = null) {
    enum class Type {
        WELCOME_TYPE,
        HEADER_TYPE,
        ITEM_TYPE,
    }
}

data class OrganizedMenuList(val data: List<SectionOfMenuItems>, val canOrder: Boolean, val message: String)
