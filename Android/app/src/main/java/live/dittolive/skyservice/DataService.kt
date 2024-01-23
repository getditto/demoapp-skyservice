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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import live.ditto.DittoLiveQueryEvent
import live.ditto.DittoQueryResultItem
import live.ditto.DittoSubscription
import live.dittolive.skyservice.SkyServiceApplication.Companion.context
import live.dittolive.skyservice.SkyServiceApplication.Companion.ditto
import live.dittolive.skyservice.models.*
import org.joda.time.DateTime
import java.lang.Exception
import java.util.Optional
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
        ditto!!.sync.registerSubscription("SELECT * FROM orders WHERE workspaceId = :workspaceId AND deleted = false", arguments = mapOf("workspaceId" to workspaceId))
        ditto!!.sync.registerSubscription("SELECT * FROM menuItems WHERE workspaceId = :workspaceId AND deleted = false", arguments = mapOf("workspaceId" to workspaceId))
        ditto!!.sync.registerSubscription("SELECT * FROM categories WHERE workspaceId = :workspaceId AND deleted = false", arguments = mapOf("workspaceId" to workspaceId))

        observeOrders()
    }

    private var seenOrders = mutableListOf<DittoQueryResultItem>()
    private fun populateSeenItems(workspaceId: String) {
        val dataScope: CoroutineScope = CoroutineScope(Job() + Dispatchers.Main)
        dataScope.launch {

            seenOrders = (ditto?.store?.execute(
                "SELECT * FROM orders WHERE deleted = false AND workspaceId = :workspaceId",
                mapOf("workspaceId" to workspaceId)
            )?.items
                ?: emptyList()).toMutableList()
        }

        dataScope.cancel()
    }

    @SuppressLint("MissingPermission")
    private fun observeOrders() {
        val disposable = CompositeDisposable()
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return
        
        ditto?.let { ditto ->
            context?.let { context ->

                ditto.resultItems("SELECT * FROM orders WHERE workspaceId = :workspaceId AND userId = :userId AND deleted = false", mapOf("workspaceId" to workspaceId, "userId" to userId))
                    .map { resultItems ->
                        resultItems.forEach { item ->
                            val itemId = item.value["_id"] as? String

                            if (itemId != null) {
                                val prevStatus = this.seenOrders
                                    .mapNotNull { seenItem ->
                                        if (seenItem.value["_id"] as? String == itemId) {
                                            return@mapNotNull seenItem.value["status"] as? Int
                                        } else {
                                            return@mapNotNull null
                                        }
                                    }
                                    .firstOrNull()

                                val newStatus = item.value["status"] as? Int

                                if (prevStatus != newStatus) {
                                    val order = Order(item.value)
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

            ditto?.resultItems("SELECT * FROM menuItems WHERE workspaceId = :workspaceId AND deleted = false", mapOf("workspaceId" to workspaceId))
                ?.map { docs ->
                    docs.map { MenuItem(it.value) }
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

     suspend fun resetWorkspaces() {
         ditto!!.store.execute(query = "EVICT FROM workspaces")
    }

    fun welcomeMessage(): Observable<String> {
        val defaultMessage = "Welcome to SkyService!"
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.resultWithOptional("SELECT * FROM workspaces WHERE _id = :id", mapOf("id" to workspaceId))
            ?.map { optional ->
                if (optional.isPresent) {
                    val document = optional.get()
                    return@map document.value["welcomeMessage"] as String? ?: defaultMessage
                }
                return@map defaultMessage
            } ?: Observable.empty()
    }

    fun observeNearFlights(): Observable<List<Map<String, String>>> {

        return ditto?.resultItems("SELECT * FROM workspaces")?.map { docs ->
            val nearbyFlights = mutableListOf<Map<String, String>>()
            val ids = docs.map { it.value["_id"].toString().split("::") }
            ids.map {
                val map = mutableMapOf<String, String>()
                map.put("date", it[0])
                map.put("number", it[1])
                nearbyFlights.add(map)
            }
            nearbyFlights
        } ?: Observable.just(emptyList())

    }

    fun orders(): Observable<List<Order>> {
        val workspaceId = workspaceId ?: return Observable.empty()
        val userId = this.userId ?: return Observable.empty()

        return ditto?.resultItems("SELECT * FROM orders WHERE workspaceId = :workspaceId AND userId = :userId AND deleted = false", mapOf("workspaceId" to workspaceId, "userId" to userId))
            ?.map { items ->
                return@map items.map { Order(it.value) }.sortedByDescending { it.createdOn }
            } ?: Observable.just(emptyList())
    }

    fun categories(): Observable<List<Category>> {
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.resultItems("SELECT * FROM categories WHERE workspaceId =:workspaceId AND deleted = false", mapOf("workspaceId" to workspaceId))
            ?.map { docs -> docs.map { Category(it.value) }.sortedBy { it.ordinal }
            } ?: Observable.empty()
    }

    fun canOrder(): Observable<Boolean> {
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.resultWithOptional("SELECT * FROM workspaces WHERE _id = :id", mapOf("id" to workspaceId))
            ?.map { optional ->
                if (optional.isPresent) {
                    val document = optional.get()
                    return@map document.value["isOrderingEnabled"] as Boolean
                }
                return@map true
            } ?: Observable.empty()
    }

    fun me(): Observable<User> {

        return ditto?.resultItems("SELECT * FROM users WHERE _id = :id", mapOf("id" to this.userId as Any))
            ?.map { document ->
                User(document.first().value)
            } ?: Observable.empty()
    }

    /**
     * This is only the passenger application
     * This will only set the name and the seat. The seat is non optional
     */
    suspend fun setMyUser(name: String, seat: String) {
        val workspaceId = workspaceId ?: return
            try {
                if (this.userId != null && ditto!!.store.execute(
                        "SELECT * FROM users WHERE _id = :id",
                        arguments = mapOf("id" to this.userId)
                    ).items.isNotEmpty()
                ) {
                    val query =
                        "UPDATE users SET name = :name, seat = :seat, workspaceId = :workspaceId WHERE _id = :id"
                    val args = mapOf(
                        "id" to this.userId!!,
                        "name" to name,
                        "seat" to seat,
                        "workspaceId" to workspaceId,
                    )
                    ditto!!.store.execute(query = query, arguments = args)
                } else {
                    var query = "INSERT INTO users DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
                    var newDoc = mapOf(
                        "_id" to this.userId!!,
                        "name" to name,
                        "seat" to seat,
                        "workspaceId" to workspaceId,
                        "deleted" to false
                    )
                    ditto!!.store.execute(query = query, arguments = mapOf("newDoc" to newDoc))
                }

            } catch (e: Exception) {
                println("Error: $e")
            }



        with(sharedPref.edit()) {
            putString("name", name);
            putString("seat", seat)
            apply()
        }
    }

    suspend fun createOrder() {
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return

        try {
            var query = "INSERT INTO orders DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
            var newDoc = mapOf (
                "createdOn" to DateTime().toISOString(),
                "userId" to userId,
                "status" to Order.Status.OPEN.value,
                "workspaceId" to workspaceId,
                "total" to 0,
                "deleted" to false
            )

            var resultId = ditto?.store?.execute(query= query, arguments = mapOf("newDoc" to newDoc))
                ?.mutatedDocumentIds()

            query = "UPDATE cartLineItems SET orderId = :orderId WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL"
            var args = mapOf(
                "orderId" to (resultId?.first() ?: ""),
                "workspaceId" to workspaceId,
                "userId" to userId
            )

            ditto?.store?.execute(query= query, arguments = args)

        } catch (e: Exception) {
            println("Error: $e")
        }
    }

    fun menuItemOptions(): Observable<List<MenuItemOption>> {
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.resultItems(
            "SELECT * FROM menuItemOptions WHERE workspaceId = :workspaceId AND deleted = false",
            mapOf("workspaceId" to workspaceId)
        )
            ?.map { docs ->
                docs.map { MenuItemOption(it.value) }
            } ?: Observable.empty()
    }

    fun menuItemOptions(menuItemId: String): Observable<List<MenuItemOption>> {

        return ditto?.resultItems(
            "SELECT * FROM menuItemOptions WHERE menuItemId = :menuItemId AND deleted = false",
            mapOf("menuItemId" to menuItemId)
        )
            ?.map { docs ->
                docs.map { MenuItemOption(it.value) }


            } ?: Observable.empty()
    }

    fun menuItems(): Observable<List<MenuItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.resultItems("SELECT * FROM menuItems WHERE workspaceId = :workspaceId AND deleted = false", mapOf("workspaceId" to workspaceId))
            ?.map { docs ->
                docs.map { MenuItem(it.value) }
            } ?: Observable.empty()
    }

    fun menuItemById(id: String): Observable<Optional<MenuItem>> {

        val menuItems: Observable<Optional<MenuItem>> =
            ditto?.resultWithOptional("SELECT * FROM menuItems WHERE _id = :id", mapOf("id" to id))
                ?.map { optional ->
                    if (optional.isPresent) {
                        val document = optional.get()
                        return@map Optional.of(MenuItem(document.value))
                    }
                    return@map Optional.empty()
                } ?: Observable.empty()

        val categories = categories()
        return Observable.combineLatest(menuItems, categories, BiFunction<Optional<MenuItem>, List<Category>, Optional<MenuItem>> { menuItemOriginal, categoriesOriginal ->
               menuItemOriginal?.let { item ->
                   item.get().category = categoriesOriginal.firstOrNull { it.id == item.get().categoryId }
                   return@BiFunction item
               }

                return@BiFunction Optional.empty()
        })
    }

    /**
    These are all the cart line items for the user
    This is a Ditto collection that is just for the local device and is _not_ synced across the mesh.
     */
    fun cartLineItems(userId: String): Observable<List<CartLineItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()

        return ditto?.observeLocalDocuments("SELECT * FROM cartLineItems WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL AND deleted = false", mapOf("workspaceId" to workspaceId, "userId" to userId))
            ?.map { docs ->
                docs.map { CartLineItem(it.value) }
            } ?: Observable.empty()

    }

    fun cartLineItems(orderIds: List<String>): Observable<List<CartLineItem>> {
        val workspaceId = workspaceId ?: return Observable.empty()

        val containsPredicate: List<String> = orderIds.map { it }

        val query = "SELECT * FROM cartLineItems WHERE workspaceId = :workspaceId AND deleted = false AND array_contains(:containsPredicate, orderId)"

        val args = mapOf("workspaceId" to workspaceId, "containsPredicate" to containsPredicate)

        return ditto?.observeLocalDocuments(query, args)?.map { docs ->
            docs.map { CartLineItem(it.value) }
        } ?: Observable.empty()

    }

    suspend fun setCartLineItem(userId: String, menuItemId: String, quantity: Int, options: List<String>) {
        val workspaceId = workspaceId ?: return

        try {
            var query = "INSERT INTO cartLineItems DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE"
            var newDoc = mapOf (
                "quantity" to quantity,
                "options" to options,
                "menuItemId" to menuItemId,
                "userId" to userId,
                "workspaceId" to workspaceId,
                "orderId" to null,
                "deleted" to false
            )

            ditto?.store?.execute(query = query, arguments = mapOf("newDoc" to newDoc))

        } catch (e:Exception) {
            println("Error: $e")
        }
    }

    suspend fun clearCartLineItems() {
        val workspaceId = workspaceId ?: return
        val userId = this.userId ?: return

        var query = "UPDATE cartLineItems SET deleted = :deleted WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL"
        var args = mapOf (
            "workspaceId" to workspaceId,
            "userId" to userId,
            "deleted" to true
        )

        ditto?.store?.execute(query = query, arguments = args)
    }

    suspend fun removeCartLineItem(id: String) {
        var query = "UPDATE cartLineItems SET deleted = :deleted WHERE workspaceId = :workspaceId AND userId = :userId AND orderId IS NULL"
        var args = mapOf (
            "workspaceId" to workspaceId,
            "userId" to userId,
            "deleted" to true
        )
        ditto?.store?.execute(query = query, arguments = args)
    }

    suspend fun evictAllData() {
        ditto!!.store.collectionNames().forEach {
            ditto!!.store.execute("EVICT FROM $it")
        }
    }
}
