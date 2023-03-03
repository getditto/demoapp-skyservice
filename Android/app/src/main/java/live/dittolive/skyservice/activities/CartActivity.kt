package live.dittolive.skyservice.activities

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.Menu
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Observable
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.functions.BiFunction
import live.dittolive.skyservice.DataService
import live.dittolive.skyservice.R
import live.dittolive.skyservice.models.CartLineItem
import live.dittolive.skyservice.models.MenuItem
import live.dittolive.skyservice.models.SectionOfCartMenuItems

class CartActivity: AppCompatActivity() {

    lateinit var disposables: CompositeDisposable

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_cart)
        val userId = intent.getStringExtra("userId").toString()

        val checkoutButton = findViewById<AppCompatButton>(R.id.button_checkout)
        checkoutButton.setOnClickListener {
            DataService.createOrder()
            val intent = Intent(this, OrdersActivity::class.java)
            startActivity(intent)
            finish()
        }


        val recyclerView = findViewById<RecyclerView>(R.id.cart_recycler_view)
        val adapter = CartRecyclerAdapter()
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        val swipeHandler = object : SwipeToDeleteCallback(this) {
            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                val item = adapter.sectionOfCartMenuItems[viewHolder.adapterPosition]
                val id = item.cartLineItem.id
                DataService.removeCartLineItem(id)
            }
        }

        val itemTouchHelper = ItemTouchHelper(swipeHandler)
        itemTouchHelper.attachToRecyclerView(recyclerView)

        val menuItems = DataService.menuItems()
        val cartLineItems = DataService.cartLineItems(userId)
        disposables = CompositeDisposable()
        Observable.combineLatest(menuItems, cartLineItems, BiFunction<List<MenuItem>, List<CartLineItem>, List<SectionOfCartMenuItems>> { menuItemsOriginal, cartItemsOriginal ->
            val finalItems = mutableListOf<SectionOfCartMenuItems>()
            for (c in cartItemsOriginal) {
                val menuItem = menuItemsOriginal.filter { it.id == c.menuItemId }.first()
                finalItems.add(SectionOfCartMenuItems(c, menuItem))
            }

            finalItems
        })
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe{ disposables.add(it) }
            .subscribe { sectionOfCartMenuItems ->
                adapter.setData(sectionOfCartMenuItems.toMutableList())
            }

        DataService.canOrder()
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }
            .subscribe { canOrder ->
                checkoutButton.isEnabled = canOrder
                checkoutButton.alpha = if (canOrder) 1f else 0.3f
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        disposables.clear()
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.menu_cart, menu);
        return super.onCreateOptionsMenu(menu)
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        val id = item.itemId
        if (id == R.id.action_clear) {
            val builder = MaterialAlertDialogBuilder(this)
            builder.apply {
                setTitle(getString(R.string.clear_cart))
                setNegativeButton(getString(R.string.clear_yes)
                ) { dialog, id ->
                    DataService.clearCartLineItems()
                    finish()
                }

                setNeutralButton(getString(R.string.cancel)
                ) { dialog, id ->

                }
            }
            builder.create()
            builder.show()
        }
        return super.onOptionsItemSelected(item)
    }
}

class CartRecyclerAdapter: RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    var sectionOfCartMenuItems = mutableListOf<SectionOfCartMenuItems>()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return ViewHolder(inflater, parent)
    }

    inner class ViewHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.cart_item_constraint_layout,
            parent,
            false
        )
    ) {
        val countTextView = itemView.findViewById<TextView>(R.id.count_text_view)
        val headerTextView = itemView.findViewById<TextView>(R.id.text_view)
        val detailTextView = itemView.findViewById<TextView>(R.id.detail_text_view)

        fun bind(item: SectionOfCartMenuItems) {
            countTextView.text = item.cartLineItem.quantity.toString()
            headerTextView.text = item.menuItem.name
            detailTextView.text = item.cartLineItem.options.map { it.replaceRange(0, 0, "• ") }.joinToString { it }.replace(",", "\n")
        }
    }

    override fun onBindViewHolder(viewHolder: RecyclerView.ViewHolder, position: Int) {
        val holder = (viewHolder as ViewHolder)
        holder.bind(sectionOfCartMenuItems[position])
    }

    override fun getItemCount(): Int {
        return sectionOfCartMenuItems.count()
    }

    fun setData(items: MutableList<SectionOfCartMenuItems>) {
        this.sectionOfCartMenuItems = items
        this.notifyDataSetChanged()
    }
}

// Swipe to delete based on https://medium.com/@kitek/recyclerview-swipe-to-delete-easier-than-you-thought-cff67ff5e5f6
abstract class SwipeToDeleteCallback(context: Context) : ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.LEFT) {

    private val deleteIcon = ContextCompat.getDrawable(context, android.R.drawable.ic_menu_delete)
    private val intrinsicWidth = deleteIcon!!.intrinsicWidth
    private val intrinsicHeight = deleteIcon!!.intrinsicHeight
    private val background = ColorDrawable()
    private val backgroundColor = Color.parseColor("#f44336")
    private val clearPaint = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR) }


    override fun onMove(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder, target: RecyclerView.ViewHolder): Boolean {
        return false
    }

    override fun onChildDraw(
        c: Canvas, recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder,
        dX: Float, dY: Float, actionState: Int, isCurrentlyActive: Boolean
    ) {

        val itemView = viewHolder.itemView
        val itemHeight = itemView.bottom - itemView.top
        val isCanceled = dX == 0f && !isCurrentlyActive

        if (isCanceled) {
            clearCanvas(c, itemView.right + dX, itemView.top.toFloat(), itemView.right.toFloat(), itemView.bottom.toFloat())
            super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive)
            return
        }

        // Draw the red delete background
        background.color = backgroundColor
        background.setBounds(itemView.right + dX.toInt(), itemView.top, itemView.right, itemView.bottom)
        background.draw(c)

        // Calculate position of delete icon
        val deleteIconTop = itemView.top + (itemHeight - intrinsicHeight) / 2
        val deleteIconMargin = (itemHeight - intrinsicHeight) / 2
        val deleteIconLeft = itemView.right - deleteIconMargin - intrinsicWidth
        val deleteIconRight = itemView.right - deleteIconMargin
        val deleteIconBottom = deleteIconTop + intrinsicHeight

        // Draw the delete icon
        deleteIcon!!.setBounds(deleteIconLeft, deleteIconTop, deleteIconRight, deleteIconBottom)
        deleteIcon.setTint(Color.parseColor("#ffffff"))
        deleteIcon.draw(c)

        super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive)
    }

    private fun clearCanvas(c: Canvas?, left: Float, top: Float, right: Float, bottom: Float) {
        c?.drawRect(left, top, right, bottom, clearPaint)
    }
}
