package live.dittolive.skyservice.activities

import android.content.Intent
import android.os.Bundle
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.widget.AppCompatButton
import io.reactivex.rxjava3.disposables.CompositeDisposable
import live.ditto.*
import live.ditto.transports.DittoSyncPermissions
import live.ditto.transports.DittoTransportConfig
import live.dittolive.skyservice.*
import live.dittolive.skyservice.R
import live.dittolive.skyservice.models.WorkspaceId
import org.joda.time.format.DateTimeFormat
import java.util.*


open class LoginActivity : AppCompatActivity(), DateSelection, FlightSelection {

    lateinit var editTextName: EditText
    lateinit var editTextSeat: EditText
    lateinit var editTextDepartureDate: EditText
    lateinit var editTextFlightNumber: EditText
    lateinit var buttonLogin: AppCompatButton
    lateinit var departureSelection: AppCompatButton

    var departureDate: Date = Date()
    lateinit var ditto: Ditto
    lateinit var disposables: CompositeDisposable
    var recentFlights = mutableListOf<Map<String, String>>()
    var chosenFlight: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        setContentView(R.layout.activity_login)
        title = getString(R.string.toolbar_name)
        if (DataService.workspaceId != null) {
            val intent = Intent(this, MenuActivity::class.java);
            startActivity(intent)
            return
        }
        checkLocationPermission()
        configureDitto()
        disposables = CompositeDisposable()

        editTextName = findViewById(R.id.edit_text_name)
        editTextSeat = findViewById(R.id.edit_text_seat)
        editTextFlightNumber = findViewById(R.id.edit_text_flight_number)
        editTextDepartureDate = findViewById(R.id.edit_text_flight_departure)
        buttonLogin = findViewById(R.id.button_login)
        departureSelection = findViewById(R.id.selectionButton)
        editTextName.validate(getString(R.string.name_validation)) { s -> s.isValidName()}
        editTextSeat.validate(getString(R.string.seat_validation)) { s -> s.isValidSeatFormat()}
        editTextFlightNumber.validate("Flight number too short") { s -> s.isValidFlightNumber() }

        editTextFlightNumber.setText("DIT101")
        editTextName.setText("John")

        departureSelection.setOnClickListener {
            val pickerFragment = DatePickerFragment()
            pickerFragment.dateDelegate = this
            pickerFragment.show(supportFragmentManager, "datePicker")
        }

        buttonLogin.setOnClickListener {
            saveData()
        }
    }

    open fun saveData() {
        val name: String = editTextName.text.toString().filter { !it.isWhitespace() }
        val seat: String = editTextSeat.text.toString().filter { !it.isWhitespace() }.toUpperCase(Locale.ROOT)
        val flightNumber: String = editTextFlightNumber.text.toString().filter { !it.isWhitespace() }
        if (name.isValidName() && seat.isValidSeatFormat() && flightNumber.isValidFlightNumber()) {
            val workspaceId = WorkspaceId(flightNumber, departureDate)
            val userId = UUID.randomUUID()
            DataService.workspaceId = workspaceId.description
            DataService.userId = userId.toString()
            DataService.cachedDepartureDate = departureDate.time
            DataService.setMyUser(name, seat);
            //24 hours from now
            val expiration = Date().time + (3600000 * 24)
            DataService.sessionExpiration = expiration
            val intent = Intent(this, MenuActivity::class.java);
            startActivity(intent)
        }
    }

    private fun setDate() {
        val fmt = DateTimeFormat.forPattern("MMMM dd, yyyy").withLocale(Locale.ENGLISH);
        editTextDepartureDate.setText(fmt.print(departureDate.time))
    }

    override fun didSelectionDate(date: Date) {
        departureDate = date
        setDate()
    }

    fun setDate(str: String) {
        val fmt1 = DateTimeFormat.forPattern("MM-dd-yyyy").withLocale(Locale.ENGLISH)
        val fmt2 = DateTimeFormat.forPattern("MMMM dd, yyyy").withLocale(Locale.ENGLISH)
        departureDate = fmt1.parseDateTime(str).toDate()
        editTextDepartureDate.setText(fmt2.print(departureDate.time))
    }

    private fun configureDitto() {
         SkyServiceApplication.ditto?.let {
             ditto = it
            val transportConfig = DittoTransportConfig()
             transportConfig.enableAllPeerToPeer()
             ditto.transportConfig = transportConfig
            ditto.startSync()
            DataService.resetWorkspaces()
        }
    }

    override fun didSelectionItem(index: Int) {
        chosenFlight = recentFlights[index]
        chosenFlight?.let {
            it.get("date")?.let { dateStr ->
                val number = it.get("number")
                editTextFlightNumber.setText(number)
                setDate(dateStr)
            }
        }
    }

    private fun checkLocationPermission() {
        val missing = DittoSyncPermissions(this).missingPermissions()
        if (missing.isNotEmpty()) {
            this.requestPermissions(missing, 0)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Regardless of the outcome, tell DittoKit that permissions maybe changed
        SkyServiceApplication.ditto?.refreshPermissions()
    }
}
