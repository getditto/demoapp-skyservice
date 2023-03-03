package live.dittolive.skyservice.activities

import android.content.Context
import android.graphics.Color
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Observable
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.functions.Function3
import live.dittolive.skyservice.DataService
import live.dittolive.skyservice.R
import live.dittolive.skyservice.models.*
import org.joda.time.format.DateTimeFormat
import java.util.*

class OrdersActivity: AppCompatActivity() {

    lateinit var disposables: CompositeDisposable

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_orders)
        title = "Orders"
        val recyclerView = findViewById<RecyclerView>(R.id.order_recycler_view)
        val adapter = RecyclerAdapter(this)
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        disposables = CompositeDisposable()
        val menuItems = DataService.menuItems()
        DataService.orders().observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }.subscribe { orders ->
            val ids = orders.map { it.id }
            Observable.combineLatest(Observable.just(orders), menuItems,
                DataService.cartLineItems(ids),
                Function3<List<Order>, List<MenuItem>, List<CartLineItem>, List<SectionOfOrderItems>> { ordersOriginal, menuItemsOriginal, cartsOriginal ->
                    val orderSections = mutableListOf<SectionOfOrderItems>()
                    ordersOriginal.map { order ->
                        val cartLineItemWithMenuItems = cartsOriginal.filter { it.orderId == order.id }.map { cartLineItem ->
                            val menuItem = menuItemsOriginal.first { it.id == cartLineItem.menuItemId }
                            CartLineItemWithMenuItem(cartLineItem, menuItem)
                        }
                        orderSections.add(SectionOfOrderItems(SectionOfOrderItems.Type.HEADER, order))
                        cartLineItemWithMenuItems.map { orderSections.add(SectionOfOrderItems(SectionOfOrderItems.Type.ITEM, order, it)) }
                        //order.orderItems.map { orderSections.add(SectionOfOrderItems(SectionOfOrderItems.Type.ITEM, order, cartLineItemWithMenuItems)) }
                        orderSections.add(SectionOfOrderItems(SectionOfOrderItems.Type.FOOTER, order))
                    }
                    orderSections
                })
                .observeOn(AndroidSchedulers.mainThread())
                .doOnSubscribe { disposables.add(it) }
                .subscribe { items ->
                    adapter.set(items)
                }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disposables.clear()
    }
}

class RecyclerAdapter(val context: Context): RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    companion object {
        private const val HEADER_TYPE = 0
        private const val ITEM_TYPE = 1
        private const val FOOTER_TYPE = 2
    }

    var sectionOrderItems = mutableListOf<SectionOfOrderItems>();

    inner class ViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.cart_item_text_view)
        val detailTextView = itemView.findViewById<TextView>(R.id.cart_item_detail_text_view)
    }

    inner class HeaderHolder(headerView: View) : RecyclerView.ViewHolder(headerView) {
        val statusTextView = itemView.findViewById<TextView>(R.id.order_status_header_text_view)
        val createdTextView = itemView.findViewById<TextView>(R.id.order_created_header_text_view)
        val controlContainerView = itemView.findViewById<ConstraintLayout>(R.id.order_segment_container)
        val placedButton = controlContainerView.findViewById<AppCompatButton>(R.id.placed_button)
        val preparingButton = controlContainerView.findViewById<AppCompatButton>(R.id.preparing_button)
        val deliveredButton = controlContainerView.findViewById<AppCompatButton>(R.id.delivered_button)
        val canceledButton = controlContainerView.findViewById<AppCompatButton>(R.id.canceled_button)
    }

    inner class FooterHolder(headerView: View) : RecyclerView.ViewHolder(headerView) {
        val statusTextView = itemView.findViewById<TextView>(R.id.order_status_footer_text_view)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val context = parent.context
        val inflater = LayoutInflater.from(context)
        if (viewType == HEADER_TYPE) {
            val constraintView = inflater.inflate(R.layout.order_header_constraint_layout, parent, false)
            return HeaderHolder(constraintView)
        } else if (viewType == FOOTER_TYPE) {
            val constraintView = inflater.inflate(R.layout.order_footer_constraint_layout, parent, false)
            return FooterHolder(constraintView)
        }

        val constraintView = inflater.inflate(R.layout.order_item_constraint_layout, parent, false)
        return ViewHolder(constraintView)
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val sectionOrderItem = sectionOrderItems[position]
        if (getItemViewType(position) == HEADER_TYPE) {
            val dt = sectionOrderItem.order.createdOn
            val fmt = DateTimeFormat.forPattern("h:mm a").withLocale(Locale.ENGLISH);
            val str: String = fmt.print(dt)
            val status = sectionOrderItem.order.status
            (holder as HeaderHolder).statusTextView.text = context.getString(R.string.order_status, status.humanReadable)
            holder.statusTextView.setTextColor(context.getColor(status.color))
            holder.createdTextView.text = context.getString(R.string.created_order, str)
            updateControlStatus(status, holder)
        } else if (getItemViewType(position) == FOOTER_TYPE) {

            val status = sectionOrderItem.order.status
            (holder as FooterHolder).statusTextView.text = context.getString(R.string.order_status_long, status.humanReadable)
            holder.statusTextView.setTextColor(context.getColor(status.color))
        } else {
            sectionOrderItem.cartLineItemsWithMenuItems?.let {
                val itemHolder = holder as ViewHolder
                itemHolder.itemTextView.text = "${it.cartLineItem.quantity} ${it.menuItem.name}"
                itemHolder.detailTextView.text = it.menuItem.details
            }
        }
    }

    fun updateControlStatus(status: Order.Status, holder: HeaderHolder) {
        holder.placedButton.background.setColorFilter(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY)
        holder.preparingButton.background.setColorFilter(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY)
        holder.deliveredButton.background.setColorFilter(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY)
        holder.canceledButton.background.setColorFilter(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY)

        holder.placedButton.setTextColor(Color.DKGRAY)
        holder.preparingButton.setTextColor(Color.DKGRAY)
        holder.deliveredButton.setTextColor(Color.DKGRAY)
        holder.canceledButton.setTextColor(Color.DKGRAY)

        val color = context.getColor(status.color)
        val textColor = context.getColor(status.textColor)
        when (status) {
            Order.Status.OPEN -> {
                holder.placedButton.setTextColor(textColor)
                holder.placedButton.background.setColorFilter(color, PorterDuff.Mode.MULTIPLY)
            }
            Order.Status.FULFILLED -> {
                holder.deliveredButton.setTextColor(textColor)
                holder.deliveredButton.background.setColorFilter(color, PorterDuff.Mode.MULTIPLY)
            }
            Order.Status.CANCELED -> {
                holder.canceledButton.setTextColor(textColor)
                holder.canceledButton.background.setColorFilter(color, PorterDuff.Mode.MULTIPLY)
            }
            Order.Status.PREPARING -> {
                holder.preparingButton.setTextColor(textColor)
                holder.preparingButton.background.setColorFilter(color, PorterDuff.Mode.MULTIPLY)
            }
        }
    }

    override fun getItemViewType(position: Int): Int {
        val sectionOrderItem = sectionOrderItems[position]
        if (sectionOrderItem.itemType == SectionOfOrderItems.Type.HEADER) {
            return HEADER_TYPE
        } else if (sectionOrderItem.itemType == SectionOfOrderItems.Type.FOOTER) {
            return FOOTER_TYPE
        }
        return ITEM_TYPE
    }

    override fun getItemCount(): Int {
        return sectionOrderItems.size
    }

    fun set(sectionOrderItems: List<SectionOfOrderItems>) {
        this.sectionOrderItems.clear()
        this.sectionOrderItems.addAll(sectionOrderItems)
        notifyDataSetChanged()
    }
}


