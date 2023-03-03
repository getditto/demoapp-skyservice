package live.dittolive.skyservice

import android.app.Dialog
import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.ViewGroup
import android.view.Window
import android.widget.TextView
import androidx.appcompat.widget.AppCompatButton
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import live.dittolive.skyservice.models.MenuItem
import live.dittolive.skyservice.models.SectionOfCartMenuItems

interface FlightSelection {
    fun didSelectionItem(index: Int)
}

class FlightDialog(context: Context, flightList: List<String>) : Dialog(context), FlightSelection {

    lateinit var delegate: FlightSelection
    var flightList = mutableListOf<String>()

    init {
        setCancelable(true)
        this.flightList.addAll(flightList)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setContentView(R.layout.dialog_flight_selection)

        val headerTextView = findViewById<TextView>(R.id.header_text_view)
        val subheaderTextView = findViewById<TextView>(R.id.subheader_text_view)
        val recyclerView = findViewById<RecyclerView>(R.id.flights_recycler_view)
        findViewById<AppCompatButton>(R.id.bottom_button).setOnClickListener {
            this.dismiss()
        }

        headerTextView.text = if (flightList.size > 0) context.getString(R.string.flight_dialog_header) else context.getString(R.string.no_nearby_flights)
        subheaderTextView.text = if (flightList.size > 0) context.getString(R.string.flight_dialog_subheader) else context.getString(R.string.no_nearby_flights_detail)

        val adapter = FlightRecyclerAdapter(flightList)
        adapter.delegate = this
        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = adapter
    }

    override fun didSelectionItem(index: Int) {
        delegate.didSelectionItem(index)
        dismiss()
    }
}

class FlightRecyclerAdapter(flightList: List<String>): RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    lateinit var delegate: FlightSelection
    val flightList = mutableListOf<String>()

    init {
        this.flightList.clear()
        this.flightList.addAll(flightList)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return ViewHolder(inflater, parent)
    }

    inner class ViewHolder(inflater: LayoutInflater, parent: ViewGroup): RecyclerView.ViewHolder(
        inflater.inflate(
            R.layout.flight_selection_item_constraint_layout,
            parent,
            false
        )
    ) {
        val textView = itemView.findViewById<TextView>(R.id.text_view)

        fun bind(str: String) {
            textView.text = str

        }
    }

    override fun onBindViewHolder(viewHolder: RecyclerView.ViewHolder, position: Int) {
        (viewHolder as ViewHolder).bind(flightList[position])
        viewHolder.itemView.setOnClickListener {
            delegate.didSelectionItem(position)
        }
    }

    override fun getItemCount(): Int {
        return flightList.size
    }
}