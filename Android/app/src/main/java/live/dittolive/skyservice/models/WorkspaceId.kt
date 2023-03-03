package live.dittolive.skyservice.models

import org.joda.time.format.DateTimeFormat
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.*

class WorkspaceId {

    var id: String
    var departureDate: Date? = null
    var flightNumber: String? = null

    val description: String?
        get() {
            if (departureDate != null) {
                return "${dateFormatter.print(departureDate!!.time)}::${flightNumber}"
            }

            return null
        }

    companion object {
        private val delimiter: String = "::"
        private val dateFormatter = DateTimeFormat.forPattern("MM-dd-yyyy").withLocale(Locale.ENGLISH);
    }

    constructor(value: String) {
        id = value
        val parts = value.split(delimiter)
        departureDate = dateFormatter.parseDateTime(parts[0]).toDate()
        flightNumber = parts[1]
    }
    constructor(flightNumber: String, departureDate: Date) {
        id = "${dateFormatter.print(departureDate.time)}${delimiter}${flightNumber}"
        this.departureDate = departureDate
        this.flightNumber = flightNumber
    }
}
