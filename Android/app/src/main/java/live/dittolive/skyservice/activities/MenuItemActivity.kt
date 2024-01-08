package live.dittolive.skyservice.activities

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.appcompat.widget.AppCompatImageButton
import androidx.core.widget.doOnTextChanged
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Observable
import io.reactivex.rxjava3.disposables.CompositeDisposable
import io.reactivex.rxjava3.functions.BiFunction
import kotlinx.coroutines.launch
import live.dittolive.skyservice.DataService
import live.dittolive.skyservice.R
import live.dittolive.skyservice.models.*
import java.util.Optional

interface AddToCart {
    fun addItemsToCart(menuItem: MenuItem, rowOfCartItems: List<RowOfCartItem>, quantity: Int)
}

class MenuItemActivity: AppCompatActivity(), AddToCart {

    lateinit var menuItemId: String
    lateinit var userId: String
    lateinit var disposables: CompositeDisposable

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_menu_item)
        menuItemId = intent.getStringExtra("menuItemId").toString()
        userId = intent.getStringExtra("userId").toString()

        val recyclerView = findViewById<RecyclerView>(R.id.menu_item_recycler_view)
        val adapter = MenuItemRecyclerAdapter(this)
        adapter.delegate = this
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter

        val menuItem = DataService.menuItemById(menuItemId)
        val options = DataService.menuItemOptions(menuItemId)

        disposables = CompositeDisposable()
        Observable.combineLatest(menuItem, options, BiFunction<Optional<MenuItem>, List<MenuItemOption>, Pair<Optional<MenuItem>, List<RowOfCartItem>>> { menuItemOriginal, menuItemOptions ->
            menuItemOriginal?.let {
                val sectionOfCartItems = SectionOfMenuDetailItems(menuItemOriginal.get(), menuItemOptions)
                return@BiFunction Pair(menuItemOriginal, sectionOfCartItems.buildData())
            }

            return@BiFunction Pair(Optional.empty(), emptyList())
        })
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }
            .subscribe { (menuItem, cartItems) ->
                this.title = menuItem.get().name
                adapter.set(menuItem.get(), cartItems.toMutableList())
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        disposables.clear()
    }

    override fun addItemsToCart(menuItem: MenuItem, rowOfCartItems: List<RowOfCartItem>, quantity: Int) {
        val options = combineOptions(rowOfCartItems)
        lifecycleScope.launch {
            DataService.setCartLineItem(userId, menuItemId, quantity, options)
        }
        finish()
    }

    fun combineOptions(rowOfCartItems: List<RowOfCartItem>): List<String> {
        val freeText = rowOfCartItems.filter { it.freeText.isNotEmpty() }.map { it.freeText }
        val selection = rowOfCartItems.filter {
            (it.type == RowOfCartItem.Type.SINGLE_SELECTION ||
                    it.type == RowOfCartItem.Type.MULTIPLE_SELECTION)
                    && it.checked == true }.map { it.text }

        return freeText + selection
    }
}

class MenuItemRecyclerAdapter(val context: Context): RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    var sectionMenuItems = mutableListOf<RowOfCartItem>()
    lateinit var menuItem: MenuItem
    var quantity = 1
    lateinit var delegate: AddToCart

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)

        when (viewType) {
            RowOfCartItem.Type.SINGLE_SELECTION.ordinal -> return SingleSelectionHolder(inflater, parent)
            RowOfCartItem.Type.MULTIPLE_SELECTION.ordinal -> return MultipleSelectionHolder(inflater, parent)
            RowOfCartItem.Type.DESCRIPTION.ordinal -> return DescriptionHolder(inflater, parent)
            RowOfCartItem.Type.FREE_TEXT.ordinal -> return FreeTextHolder(inflater, parent)
            RowOfCartItem.Type.ACTION_ITEM.ordinal -> return ActionHolder(inflater, parent)
            else -> return HeaderHolder(inflater, parent)
        }
    }

    inner class FreeTextHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_edittext_constraint_layout,
            parent,
            false
        )
    ) {
        var textView: TextView
        var editText: EditText

        init {
            textView = itemView.findViewById(R.id.text_view)
            editText = itemView.findViewById(R.id.edit_text)
            editText.imeOptions = EditorInfo.IME_ACTION_DONE
        }

        fun bind(item: RowOfCartItem) {
            textView.text = item.text
            editText.doOnTextChanged { text, start, before, count -> item.freeText = text.toString() }
        }
    }

    inner class ActionHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_cart_control_constraint_layout,
            parent,
            false
        )
    ) {
        var countTextView: TextView
        var cartButton: AppCompatButton
        var increaseButton: AppCompatImageButton
        var decreaseButton: AppCompatImageButton

        init {
            countTextView = itemView.findViewById(R.id.item_count)
            cartButton = itemView.findViewById(R.id.add_cart_button)
            increaseButton = itemView.findViewById(R.id.menu_item_add)
            decreaseButton = itemView.findViewById(R.id.menu_item_sub)
        }

        fun bind(item: RowOfCartItem) {
            increaseButton.setOnClickListener {
                quantity += 1
                countTextView.text = quantity.toString()
            }
            decreaseButton.setOnClickListener {
                if (quantity > 1) {
                    quantity -= 1
                    countTextView.text = quantity.toString()
                }
            }
            cartButton.setOnClickListener {
                delegate.addItemsToCart(menuItem, sectionMenuItems, quantity)
            }
        }
    }

    inner class HeaderHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_header_constraint_layout,
            parent,
            false
        )
    ) {
        var textView: TextView

        init {
            textView = itemView.findViewById(R.id.menu_header_text_view)
        }

        fun bind(item: RowOfCartItem) {
            textView.text = item.text
        }
    }


    inner class SingleSelectionHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_selection_constraint_layout,
            parent,
            false
        )
    ) {
        var textView: TextView
        var imageView: ImageView

        init {
            textView = itemView.findViewById(R.id.text_view)
            imageView = itemView.findViewById(R.id.image_view)
        }

        fun bind(item: RowOfCartItem) {
            textView.text = item.text
            imageView.visibility = if (item.checked) View.VISIBLE else View.GONE
            itemView.setOnClickListener {
                clearChecked(item.menuOption)
                item.checked = !item.checked
                imageView.visibility = if (item.checked) View.VISIBLE else View.GONE
            }
        }
    }

    inner class MultipleSelectionHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_selection_constraint_layout,
            parent,
            false
        )
    ) {
        var textView: TextView
        var imageView: ImageView

        init {
            textView = itemView.findViewById(R.id.text_view)
            imageView = itemView.findViewById(R.id.image_view)
        }

        fun bind(item: RowOfCartItem) {
            textView.text = item.text
            imageView.visibility = if (item.checked) View.VISIBLE else View.GONE
            itemView.setOnClickListener {
                item.checked = !item.checked
                imageView.visibility = if (item.checked) View.VISIBLE else View.GONE
            }
        }
    }

    fun clearChecked(option: MenuItemOption?) {
        sectionMenuItems.filter { it.menuOption?.id == option?.id }.map { it.checked = false }
        notifyDataSetChanged()
    }

    inner class DescriptionHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.menu_item_details_constraint_layout,
            parent,
            false
        )
    ) {
        var textView: TextView

        init {
            textView = itemView.findViewById(R.id.text_view)
        }

        fun bind(item: RowOfCartItem) {
            textView.text = item.text
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val rowItem = sectionMenuItems[position]
        when(getItemViewType(position)) {
            RowOfCartItem.Type.HEADER.ordinal -> {
                (holder as HeaderHolder).bind(rowItem)
            }
            RowOfCartItem.Type.DESCRIPTION.ordinal -> {
                (holder as DescriptionHolder).bind(rowItem)
            }
            RowOfCartItem.Type.SINGLE_SELECTION.ordinal -> {
                (holder as SingleSelectionHolder).bind(rowItem)
            }
            RowOfCartItem.Type.MULTIPLE_SELECTION.ordinal -> {
                (holder as MultipleSelectionHolder).bind(rowItem)
            }
            RowOfCartItem.Type.FREE_TEXT.ordinal -> {
                (holder as FreeTextHolder).bind(rowItem)
            }
            RowOfCartItem.Type.ACTION_ITEM.ordinal -> {
                (holder as ActionHolder).bind(rowItem)
            }
        }
    }

    override fun getItemViewType(position: Int): Int {
        return sectionMenuItems[position].type.ordinal
    }

    override fun getItemCount(): Int {
        return sectionMenuItems.size
    }

    fun set(menuItem: MenuItem, sectionOrderItems: List<RowOfCartItem>) {
        this.sectionMenuItems.clear()
        this.sectionMenuItems.addAll(sectionOrderItems)
        this.menuItem = menuItem
        notifyDataSetChanged()
    }
}
