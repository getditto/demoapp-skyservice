package live.dittolive.skyservice.activities

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.core.widget.doOnTextChanged
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.switchmaterial.SwitchMaterial
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.disposables.CompositeDisposable
import kotlinx.coroutines.launch
import live.dittolive.skyservice.*
import live.dittolive.skyservice.models.SectionOfSettingItems
import java.util.*


interface ListAction {
    fun saveData(name: String, seat: String)
    fun showLogout()
    fun goToSettings()
}

class SettingsActivity: AppCompatActivity(), ListAction {

    lateinit var disposables: CompositeDisposable
    lateinit var recyclerView: RecyclerView
    lateinit var adapter: SettingsRecyclerAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        title = getString(R.string.action_settings)
        recyclerView = findViewById(R.id.settings_recycler_view)
        adapter = SettingsRecyclerAdapter(this, SectionOfSettingItems.buildSettingsData(this))
        adapter.delegate = this
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = adapter
        disposables = CompositeDisposable()
        DataService.me()
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }
            .subscribe {
                it?.let { user ->
                    adapter.setData(user.name, user.seat!!)
                }
            }

        DataService.canOrder()
            .observeOn(AndroidSchedulers.mainThread())
            .doOnSubscribe { disposables.add(it) }
            .subscribe {
                adapter.orderEnabled(it ?: true)
            }
    }

    override fun onStop() {
        super.onStop()
        disposables.clear()
    }

    override fun saveData(name: String, seat: String) {
        name.filter { !it.isWhitespace() }
        seat.filter { !it.isWhitespace() }.toUpperCase(
            Locale.ROOT
        )

        if (name.isValidName() || seat.isValidSeatFormat()) {
            lifecycleScope.launch {
                DataService.setMyUser(name, seat)
            }
            finish()
        }
    }

    override fun showLogout() {
        val builder = MaterialAlertDialogBuilder(this)
        builder.apply {
            setTitle("Logout?")
            setPositiveButton("Yes, Logout.",
                { dialog, id ->
                    logout()
                })
            setNegativeButton("No",
                { dialog, id ->

                })
        }
        builder.create()
        builder.show()
    }

    override fun goToSettings() {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + BuildConfig.APPLICATION_ID)
            )
        )
    }

    fun logout() {
        DataService.clearSession()
        // DataService.evictAllData() // WORKAROUND: Comment-out because it causes crash by "io.reactivex.rxjava3.exceptions.OnErrorNotImplementedException: The exception was not handled due to missing onError handler in the subscribe() method call."
        val intent = Intent(this, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
    }
}

class SettingsRecyclerAdapter(
    val context: Context,
    var sectionSettingsItems: List<SectionOfSettingItems>
): RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    lateinit var delegate: ListAction

    companion object {
        private const val HEADER_TYPE = 0
        private const val LABELED_DETAIL_TYPE = 1
        private const val DETAIL_TYPE = 2
        private const val EDIT_ITEM_TYPE = 3
        private const val SWITCH_ITEM_TYPE = 4
        private const val BUTTON_ITEM_TYPE = 5

        private const val SWITCH_FIELD = 3
        private const val NAME_FIELD = 5
        private const val SEAT_FIELD = 6

        private const val SAVE_BUTTON = 7
        private const val SETTINGS_BUTTON = 12
        private const val LOGOUT_BUTTON = 13
    }

    inner class HeaderViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.header_text_view)
    }

    inner class LabeledViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.text_view)
        val itemDetailTextView = itemView.findViewById<TextView>(R.id.detail_text_view)
    }

    inner class DetailViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.text_view)
    }

    open inner class EditViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.text_view)
        val itemEditTextView = itemView.findViewById<EditText>(R.id.edit_text).apply { imeOptions = EditorInfo.IME_ACTION_DONE }
    }

    inner class SwitchViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemTextView = itemView.findViewById<TextView>(R.id.text_view)
        val itemSwitchView = itemView.findViewById<SwitchMaterial>(R.id.ordering_enabled_switch)
    }

    inner class ButtonViewHolder(listItemView: View) : RecyclerView.ViewHolder(listItemView) {
        val itemButton = itemView.findViewById<AppCompatButton>(R.id.button)
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val sectionOrderItem = sectionSettingsItems[position]
        val viewType = getItemViewType(position)
        when(viewType){
            HEADER_TYPE -> {
                (holder as HeaderViewHolder).itemTextView.setText(sectionOrderItem.text)
            }
            EDIT_ITEM_TYPE -> {
                (holder as EditViewHolder).itemTextView.setText(sectionOrderItem.text)
                (holder as EditViewHolder).itemTextView.imeOptions = EditorInfo.IME_ACTION_DONE
                holder.itemEditTextView.doOnTextChanged { text, start, before, count ->
                    sectionOrderItem.data = text.toString()
                }
                sectionOrderItem.data?.let {
                    holder.itemEditTextView.setText(it)
                }
                if (viewType == EDIT_ITEM_TYPE) {
                    holder.itemEditTextView.validate(context.getString(R.string.name_validation)) { s -> s.isValidName() }
                } else {
                    holder.itemEditTextView.validate(context.getString(R.string.seat_validation)) { s -> s.isValidSeatFormat()}
                }
            }
            SWITCH_ITEM_TYPE -> {
                (holder as SwitchViewHolder).itemTextView.setText(sectionOrderItem.text)
                holder.itemSwitchView.isChecked = sectionSettingsItems[SWITCH_FIELD].state
            }
            LABELED_DETAIL_TYPE -> {
                (holder as LabeledViewHolder).itemTextView.setText(sectionOrderItem.text)
                holder.itemDetailTextView.setText(sectionOrderItem.data)
            }
            DETAIL_TYPE -> {
                (holder as DetailViewHolder).itemTextView.setText(sectionOrderItem.data)
            }
            else -> {
                (holder as ButtonViewHolder).itemButton.setText(sectionOrderItem.text)
                if (position == LOGOUT_BUTTON) {
                    holder.itemButton.setTextColor(Color.RED)
                } else {
                    holder.itemButton.setTextColor(context.getColor(R.color.primary_200))
                }

                holder.itemButton.setOnClickListener {
                    when(position) {
                        SAVE_BUTTON -> delegate.saveData(
                            sectionSettingsItems[NAME_FIELD].data ?: "",
                            sectionSettingsItems[SEAT_FIELD].data ?: ""
                        )
                        SETTINGS_BUTTON -> delegate.goToSettings()
                        LOGOUT_BUTTON -> delegate.showLogout()
                    }
                }
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val context = parent.context
        val inflater = LayoutInflater.from(context)
        when(viewType){
            HEADER_TYPE -> {
                val constraintView = inflater.inflate(
                    R.layout.settings_header_item_constraint_layout,
                    parent,
                    false
                )
                return HeaderViewHolder(constraintView)
            }
            EDIT_ITEM_TYPE -> {
                val constraintView = inflater.inflate(
                    R.layout.settings_edit_item_constraint_layout,
                    parent,
                    false
                )
                return EditViewHolder(constraintView)
            }
            SWITCH_ITEM_TYPE -> {
                val constraintView = inflater.inflate(
                    R.layout.settings_switch_item_constraint_layout,
                    parent,
                    false
                )
                return SwitchViewHolder(constraintView)
            }
            LABELED_DETAIL_TYPE -> {
                val constraintView = inflater.inflate(
                    R.layout.settings_labeled_detail_item_constraint_layout,
                    parent,
                    false
                )
                return LabeledViewHolder(constraintView)
            }
            DETAIL_TYPE -> {
                val constraintView = inflater.inflate(
                    R.layout.settings_detail_item_constraint_layout,
                    parent,
                    false
                )
                return DetailViewHolder(constraintView)
            }
            else -> {
                val constraintView = inflater.inflate(
                    R.layout.button_item_constraint_layout,
                    parent,
                    false
                )
                return ButtonViewHolder(constraintView)
            }
        }
    }

    override fun getItemCount(): Int {
        return sectionSettingsItems.size
    }

    override fun getItemViewType(position: Int): Int {
        val sectionSettingItem = sectionSettingsItems[position]
        when (sectionSettingItem.itemType) {
            SectionOfSettingItems.Type.HEADER -> return HEADER_TYPE
            SectionOfSettingItems.Type.EDIT_ITEM -> return EDIT_ITEM_TYPE
            SectionOfSettingItems.Type.SWITCH_ITEM -> return SWITCH_ITEM_TYPE
            SectionOfSettingItems.Type.LABELED_DETAIL -> return LABELED_DETAIL_TYPE
            SectionOfSettingItems.Type.DETAILED -> return DETAIL_TYPE
            else -> return BUTTON_ITEM_TYPE
        }
    }

    fun setData(name: String, seat: String) {
        sectionSettingsItems[NAME_FIELD].data = name
        sectionSettingsItems[SEAT_FIELD].data = seat
        notifyItemChanged(NAME_FIELD)
        notifyItemChanged(SEAT_FIELD)
    }

    fun orderEnabled(on: Boolean) {
        sectionSettingsItems[SWITCH_FIELD].state = on
        notifyItemChanged(SWITCH_FIELD)
    }
}
