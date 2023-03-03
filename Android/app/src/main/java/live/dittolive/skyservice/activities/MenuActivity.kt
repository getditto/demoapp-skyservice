package live.dittolive.skyservice.activities

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.Menu
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.appcompat.widget.AppCompatImageButton
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Observable
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.functions.BiFunction
import live.dittolive.skyservice.DataService
import live.dittolive.skyservice.SkyServiceApplication
import live.dittolive.skyservice.SkyServiceApplication.Companion.ditto
import live.dittolive.skyservice.R
import live.dittolive.skyservice.models.*
import java.util.*
import kotlin.collections.ArrayList


interface ItemSelection {
    fun didSelectionItem(menuItem: MenuItem)
}

class MenuActivity : AppCompatActivity(), ItemSelection {

    lateinit var disposables: CompositeDisposable
    private var canOrder = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_menu)
        title = getString(R.string.action_menu)
        SkyServiceApplication.startSyncing()
        val recyclerView = findViewById<RecyclerView>(R.id.menu_recycler_view)
        val adapter = MenuRecyclerAdapter(this)
        adapter.delegate = this
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        val checkoutButton = findViewById<AppCompatButton>(R.id.button_checkout)
        checkoutButton.setOnClickListener {
            val intent = Intent(this, CartActivity::class.java)
            intent.putExtra("userId", DataService.userId)
            startActivity(intent)
        }

        disposables = CompositeDisposable()
        DataService.userId?.let { userId ->
            DataService.cartLineItems(userId)
                .observeOn(AndroidSchedulers.mainThread())
                .doOnSubscribe{ disposables.add(it) }
                .subscribe { cartLineItems ->
                    checkoutButton.visibility = if (cartLineItems.size > 0) View.VISIBLE else View.GONE
                }
        }

        val menuItemsCategories = DataService.menuItemsAndAllCategories()
        val welcomeMessage = DataService.welcomeMessage()

        Observable.combineLatest(menuItemsCategories, welcomeMessage, BiFunction<Pair<List<SectionOfMenuItems>, Boolean>, String, OrganizedMenuList> { (sections, canOrder), message ->
            OrganizedMenuList(sections, canOrder, message)
        })
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }
            .subscribe { organizedMenuList ->
                this.canOrder = organizedMenuList.canOrder
                val organizedMenu = ArrayList<OrganizedMenu>()
                organizedMenu.add(OrganizedMenu(OrganizedMenu.Type.WELCOME_TYPE))
                organizedMenuList.data.map { section ->
                    organizedMenu.add(OrganizedMenu(OrganizedMenu.Type.HEADER_TYPE, section.category))
                    organizedMenuList.data.filter {
                        it.category?.id == section.category?.id
                    }.map {
                        it.items.map { organizedMenu.add(OrganizedMenu(OrganizedMenu.Type.ITEM_TYPE, it.category, it)) }
                    }
                }
                adapter.setData(organizedMenu.toMutableList(), organizedMenuList.message)
            }
    }

    fun checkSession() {
        if (Date().time > DataService.sessionExpiration) {
            DataService.clearSession()
            val intent = Intent(this, LoginActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            startActivity(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        checkSession()
    }

    override fun onDestroy() {
        super.onDestroy()
        disposables.clear()
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.menu_main, menu);
        return super.onCreateOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        val id = item.itemId

        if (id == R.id.action_orders) {
            val intent = Intent(this, OrdersActivity::class.java);
            startActivity(intent)
        }
        if (id == R.id.action_settings) {
            val intent = Intent(this, SettingsActivity::class.java);
            startActivity(intent)
        }
        return super.onOptionsItemSelected(item)
    }

    override fun didSelectionItem(menuItem: MenuItem) {
        val intent = Intent(this, MenuItemActivity::class.java)
        intent.putExtra("menuItemId", menuItem.id)
        intent.putExtra("userId", DataService.userId)
        startActivity(intent)
    }
}

class MenuRecyclerAdapter(val context: Context): RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    lateinit var delegate: ItemSelection
    var welcomeMessage = ""

    companion object {
        private const val HEADER_TYPE = 0
        private const val ITEM_TYPE = 1
        private const val WELCOME_TYPE = 2
    }

    var menuItems: MutableList<OrganizedMenu> = mutableListOf();

    fun setData(menuItems: MutableList<OrganizedMenu>, welcomeMessage: String) {
        this.menuItems = menuItems
        this.welcomeMessage = welcomeMessage
        this.notifyDataSetChanged()
    }

    inner class HeaderHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_header_constraint_layout,
            parent,
            false
        )
    ) {
        val headerTextView = itemView.findViewById<TextView>(R.id.menu_header_text_view)
    }

    inner class WelcomeHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_welcome_constraint_layout,
            parent,
            false
        )
    ) {
        val textView = itemView.findViewById<TextView>(R.id.text_view)
    }

    inner class MenuItemHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_constraint_layout,
            parent,
            false
        )
    ) {
        var nameTextView: TextView? = null
        var detailsTextView: TextView? = null
        var addButton: AppCompatImageButton? = null
        var menuItem: MenuItem? = null

        init {
            this.nameTextView = itemView.findViewById(R.id.menu_item_row_name_text_view)
            this.detailsTextView = itemView.findViewById(R.id.menu_item_row_details_text_view)
            this.addButton = itemView.findViewById(R.id.menu_item_row_add_button)
        }

        fun bind(organizedMenuItem: OrganizedMenu) {
            val menuItem = organizedMenuItem.item!!
            this.menuItem = menuItem
            this.nameTextView?.text = menuItem.name
            this.detailsTextView?.text = menuItem.details
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        if (viewType == WELCOME_TYPE) {
            return WelcomeHolder(inflater, parent)
        } else if (viewType == HEADER_TYPE) {
            return HeaderHolder(inflater, parent)
        }

        return MenuItemHolder(inflater, parent)
    }

    override fun onBindViewHolder(viewHolder: RecyclerView.ViewHolder, position: Int) {
        if (getItemViewType(position) == HEADER_TYPE) {
            val category = menuItems[position].category
            (viewHolder as HeaderHolder).headerTextView.text = category?.name ?: context.getString(R.string.uncategorized)
        }else if (getItemViewType(position) == WELCOME_TYPE) {
            (viewHolder as WelcomeHolder).textView.text = welcomeMessage
        } else {
            val menuItem = menuItems[position].item!!
            val holder = (viewHolder as MenuItemHolder)
            holder.bind(menuItems[position])
            holder.addButton?.setOnClickListener {
                delegate.didSelectionItem(menuItem)
            }
        }
    }

    override fun getItemViewType(position: Int): Int {
        val item = menuItems[position]
        if (item.itemType == OrganizedMenu.Type.WELCOME_TYPE) {
            return WELCOME_TYPE
        } else if (item.itemType == OrganizedMenu.Type.HEADER_TYPE) {
            return HEADER_TYPE
        }
        return ITEM_TYPE
    }

    override fun getItemCount(): Int {
        return menuItems.count()
    }

}

