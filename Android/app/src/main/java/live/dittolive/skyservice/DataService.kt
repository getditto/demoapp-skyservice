package live.dittolive.skyservice


import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Observable
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.functions.BiFunction
import io.reactivex.rxjava3.functions.Function5
import live.ditto.DittoLiveQueryEvent
import live.ditto.DittoCounter
import live.ditto.DittoSubscription
import live.dittolive.skyservice.SkyServiceApplication.Companion.context
import live.dittolive.skyservice.SkyServiceApplication.Companion.ditto
import live.dittolive.skyservice.models.*
import org.joda.time.DateTime
import kotlin.collections.ArrayList


object DataService {

    private val sharedPref = context?.getSharedPreferences(
        (R.string.preference_file_key.toString()),
        Context.MODE_PRIVATE
    )!!

    private var dittoSubscriptions = mutableListOf<DittoSubscription>()

    var userId: String?
        get() {
            return sharedPref.getString("userId", null)
        }
        set(value) = sharedPref.edit().putString("userId", value).apply()

    var name: String?
        get() {
            return sharedPref.getString("name", null)
        }
        set(value) = sharedPref.edit().putString("name", value).apply()

    var seat: String?
        get() {
            return sharedPref.getString("seat", null)
        }
        set(value) = sharedPref.edit().putString("seat", value).apply()

    var workspaceId: String?
        get() {
            return sharedPref.getString("workspaceId", null)
        }
        set(value) = sharedPref.edit().putString("workspaceId", value).apply()

    var cachedDepartureDate: Long
        get() {
            return sharedPref.getLong("cachedDepartureDate", 0)
        }
        set(value) = sharedPref.edit().putLong("cachedDepartureDate", value).apply()

    var sessionExpiration: Long
        get() {
            return sharedPref.getLong("sessionExpiration", 0)
        }
        set(value) = sharedPref.edit().putLong("sessionExpiration", value).apply()

    /**
     * Start listening to orders and menu items
     */
    fun setupSubscriptions(workspaceId: String) {
        dittoSubscriptions.add(ditto!!.store.collection("orders").find("workspaceId == '${workspaceId}' && deleted == false").subscribe())
        dittoSubscriptions.add(ditto!!.store.collection("menuItems").find("workspaceId == '${workspaceId}' && deleted == false").subscribe())
        dittoSubscriptions.add(ditto!!.store.collection("categories").find("workspaceId == '${workspaceId}' && deleted == false").subscribe())
        observeOrders()
    }

    @SuppressLint("MissingPermission")
    private fun observeOrders() {
        val disposable = CompositeDisposable()
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return

        ditto?.let { ditto ->
            context?.let { context ->
                ditto.store.collection("orders")
                    .find("workspaceId == '${workspaceId}' && userId == '${userId}' && deleted == false")
                    .documentsWithEventInfo()
                    .map { info ->
                        when (info.liveQueryEvent) {
                            is DittoLiveQueryEvent.Update -> {
                                for (i in info.liveQueryEvent.updates) {
                                    val order = Order(info.documents[i])
                                    val title = "Order Status Update"
                                    val body = "Your order has been ${order.status.humanReadable}"
                                    val builder =
                                        NotificationCompat.Builder(context, "ditto.live.skyservice")
                                            .setSmallIcon(R.drawable.ic_stat_icon)
                                            .setContentTitle(title)
                                            .setContentText(body)
                                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                                    with(NotificationManagerCompat.from(context)) {
                                        notify(10001, builder.build())
                                    }
                                }
                            }

                            else -> {}
                        }
                    }
                    .doOnSubscribe { disposable.add(it) }
                    .observeOn(AndroidSchedulers.mainThread())
                    .subscribe()

            } ?: Log.e("ERROR", "context is null")
        } ?: Log.e("ERROR", "ditto is null")
    }

    fun clearSession() {
        name = null
        seat = null
        workspaceId = null
    }

    fun menuItemsAndAllCategories(): Observable<Pair<List<SectionOfMenuItems>, Boolean>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        val userId = this.userId ?: return Observable.empty()
        val cartLineItems = cartLineItems(userId)
        val menuItemOptions = menuItemOptions()
        val menuItemsObs: Observable<List<MenuItem>> =
            ditto!!.store.collection("menuItems").find("workspaceId == '${workspaceId}' && deleted == false").documents().map { docs ->
                docs.map { MenuItem(it) }
            } ?: Observable.empty()
        val categories = categories()
        val canOrder = canOrder()
        return Observable.combineLatest(
            cartLineItems,
            menuItemsObs,
            categories,
            menuItemOptions,
            canOrder,
            Function5<List<CartLineItem>, List<MenuItem>, List<Category>, List<MenuItemOption>, Boolean, Pair<List<SectionOfMenuItems>, Boolean>> { cartLineItemsOriginal, menuItemsOriginal, categoriesOriginal, menuItemsOptionsOriginal, canOrder ->
                var menuItems = ArrayList<MenuItem>()
                menuItemsOriginal.toMutableList().forEach { menuItem ->

                    if (menuItem.isCrewOnly) {
                        return@forEach
                    }

                    menuItem.remainsCount?.let { remains ->
                        if (remains <= 0) return@forEach
                    }

                    menuItem.category = categoriesOriginal.firstOrNull { it.id == menuItem.categoryId }
                    menuItem.cartLineItems = cartLineItemsOriginal.filter { it.menuItemId == menuItem.id }
                    menuItem.options = menuItemsOptionsOriginal.filter { it.menuItemId == menuItem.id }
                    menuItems.add(menuItem)
                }

                val sectionOfMenuItems = ArrayList<SectionOfMenuItems>()
                for (category in categoriesOriginal.sortedBy { it.ordinal }) {
                    if (!category.isCrewOnly) {
                        val menuItems = menuItems.filter{ it.categoryId == category.id }.sortedBy { it.ordinal }
                        sectionOfMenuItems.add(SectionOfMenuItems(menuItems, category))
                    }
                }

                val uncatMenuItems = menuItems.filter{ it.category == null }.sortedBy { it.ordinal }
                if (uncatMenuItems.isNotEmpty()) {
                    sectionOfMenuItems.add(SectionOfMenuItems(uncatMenuItems, null))
                }

                Pair(sectionOfMenuItems, canOrder)
            })
    }

     fun resetWorkspaces() {
        ditto!!.store.collection("workspaces").findAll().evict()
    }

    fun welcomeMessage(): Observable<String> {
        val defaultMessage = "Welcome to SkyService!"
        val workspaceId = workspaceId ?: return Observable.empty()
        return ditto!!.store.collection("workspaces").findByID(workspaceId).documentWithOptional().map { optional ->
            if (optional.isPresent) {
                val document = optional.get()
                return@map document["welcomeMessage"].string ?: defaultMessage
            }
            return@map defaultMessage
        }
    }

    fun observeNearFlights(): Observable<List<Map<String, String>>> {
        return ditto!!.store.collection("workspaces").findAll()
            .documents().map { docs ->
                val nearbyFlights = mutableListOf<Map<String, String>>()
                val ids = docs.map { it.id.toString().split("::") }
                ids.map {
                    val map = mutableMapOf<String, String>()
                    map.put("date", it[0])
                    map.put("number", it[1])
                    nearbyFlights.add(map)
                }
                nearbyFlights
            }
    }

    fun orders(): Observable<List<Order>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        val userId = this.userId ?: return Observable.empty()
        return ditto!!.store.collection("orders").find("workspaceId == '${workspaceId}' && userId == '${userId}' && deleted == false")
            .documentsWithEventInfo()
            .map { info ->
                return@map info.documents.map { Order(it) }.sortedByDescending { it.createdOn }
            }
    }

    fun categories(): Observable<List<Category>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        return ditto!!.store.collection("categories").find("workspaceId == '${workspaceId}' && deleted == false")
            .documents().map { docs -> docs.map { Category(it) }.sortedBy { it.ordinal }
            }
    }

    fun canOrder(): Observable<Boolean> {
        val workspaceId = workspaceId ?: return Observable.empty()
        return ditto!!.store.collection("workspaces").findByID(workspaceId).documentWithOptional().map { optional ->
            if (optional.isPresent) {
                val document = optional.get()
                return@map document["isOrderingEnabled"].booleanValue
            }
            return@map true
        }
    }

    fun me(): Observable<User> {
        return ditto!!.store.collection("users").findByID(this.userId!!).document()
            .map { document ->
                User(document)
            }
    }

    /**
     * This is only the passenger application
     * This will only set the name and the seat. The seat is non optional
     */
    fun setMyUser(name: String, seat: String) {
        val workspaceId = workspaceId ?: return
        ditto!!.store.write { txn ->
            txn["users"].findById(this.userId!!.toDittoID()).exec()?.let { doc ->
                txn["users"].findById(this.userId!!.toDittoID()).update { mutable ->
                    val mutableDoc = mutable.let { it } ?: return@update
                    mutableDoc["name"].set(name)
                    mutableDoc["seat"].set(seat)
                    mutableDoc["workspaceId"].set(workspaceId)
                }
            } ?: run {
                txn["users"].upsert(mapOf(
                    "_id" to this.userId!!,
                    "name" to name,
                    "seat" to seat,
                    "workspaceId" to workspaceId,
                    "deleted" to false
                ))
            }
        }
        with(sharedPref.edit()) {
            putString("name", name);
            putString("seat", seat)
            apply()
        }
    }

    fun createOrder() {
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return
        ditto!!.store.write { txn ->
            val insertedOrderId = txn["orders"].upsert(mapOf(
                "createdOn" to DateTime().toISOString(),
                "userId" to userId,
                "status" to Order.Status.OPEN.value,
                "workspaceId" to workspaceId,
                "total" to 0,
                "usedCount" to DittoCounter(),
                "deleted" to false

            ))
            var usedItems = mutableListOf<Map<String, Any>>()
            txn["cartLineItems"].find("workspaceId == '${workspaceId}' && userId == '${userId}' && orderId == null").update { mutableDocs ->
                for (mutableDoc in mutableDocs) {
                    mutableDoc["orderId"].set(insertedOrderId)
                    usedItems.add(mapOf("menuItemId" to mutableDoc["menuItemId"].stringValue, "quantity" to mutableDoc["quantity"].doubleValue))
                }
            }
            usedItems.forEach { used ->
                val id = used["menuItemId"] as String
                val quantity = used["quantity"] as Double
                txn["menuItems"].findById(id.toDittoID()).update { mutableDoc ->
                    mutableDoc?.let {
                        it["usedCount"].counter?.increment(quantity)
                    }
                }
            }
        }
    }

    fun menuItemOptions(): Observable<List<MenuItemOption>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        return ditto!!.store.collection("menuItemOptions").find("workspaceId == '${workspaceId}' && deleted == false")
            .documents().map { docs -> docs.map { MenuItemOption(it) }
            }
    }

    fun menuItemOptions(menuItemId: String): Observable<List<MenuItemOption>> {
        return ditto!!.store.collection("menuItemOptions").find("menuItemId == '${menuItemId}' && deleted == false")
            .documents().map { docs -> docs.map { MenuItemOption(it) }
            }
    }

    fun menuItems(): Observable<List<MenuItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        return ditto!!.store.collection("menuItems")
            .find("workspaceId == '${workspaceId}' && deleted == false").documents().map { docs ->
                docs.map { MenuItem(it) }
            }
    }

    fun menuItemById(id: String): Observable<MenuItem> {
        val menuItems: Observable<MenuItem?> = ditto!!.store.collection("menuItems")
            .findByID(id).documentWithOptional().map { optional ->
                if (optional.isPresent) {
                    val document = optional.get()
                    return@map MenuItem(document)
                }
                return@map null
        }

        val categories = categories()
        return Observable.combineLatest(menuItems, categories, BiFunction<MenuItem?, List<Category>, MenuItem?> { menuItemOriginal, categoriesOriginal ->
               menuItemOriginal?.let { item ->
                   item.category = categoriesOriginal.firstOrNull { it.id == item.categoryId }
                   return@BiFunction item
               }

                return@BiFunction null
        })
    }

    /**
    These are all the cart line items for the user
    This is a Ditto collection that is just for the local device and is _not_ synced across the mesh.
     */
    fun cartLineItems(userId: String): Observable<List<CartLineItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        val query = "workspaceId == '${workspaceId}' && userId == '${userId}' && orderId == null && deleted == false"
        return ditto!!.store.collection("cartLineItems").find(query)
            .observeLocalDocuments().map { docs ->
                docs.map { CartLineItem(it) }
            }
    }

    fun cartLineItems(orderIds: List<String>): Observable<List<CartLineItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        val containsPredicate: String = orderIds.joinToString { "'${it}'" }
        val query = "workspaceId == '${workspaceId}' && contains([${containsPredicate}], orderId) &&  deleted == false"
        return ditto!!.store.collection("cartLineItems").find(query)
            .observeLocalDocuments().map { docs ->
                docs.map { CartLineItem(it) }
            }
    }

    fun setCartLineItem(userId: String, menuItemId: String, quantity: Int, options: List<String>) {
        val workspaceId = workspaceId ?: return
        ditto!!.store.write { txn ->
            txn["cartLineItems"].upsert(mapOf(
                "quantity" to quantity,
                "options" to options,
                "menuItemId" to menuItemId,
                "userId" to userId,
                "workspaceId" to workspaceId,
                "orderId" to null,
                "deleted" to false
            ))
        }
    }

    fun clearCartLineItems() {
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return
        val query = "workspaceId == '${workspaceId}' && userId == '${userId}' && orderId == null"
        ditto!!.store.collection("cartLineItems").find(query).update { mutableDocs ->
            for (mutableDoc in mutableDocs) {
                mutableDoc["deleted"].set(true)
            }
        }
    }

    fun removeCartLineItem(id: String) {
        ditto!!.store.collection("cartLineItems").findByID(id).update { mutable ->
            val mutableDoc = mutable.let { it } ?: return@update
            mutableDoc["deleted"].set(true)
        }
    }

    fun evictAllData() {
        ditto!!.store.collectionNames().forEach {
            ditto!!.store.collection(it).findAll().evict()
        }
    }
}
