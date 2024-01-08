package live.dittolive.skyservice.models

import live.ditto.DittoDocument
import live.dittolive.skyservice.R
import live.dittolive.skyservice.toISODate
import org.joda.time.DateTime
import java.util.*

data class Order(val resultItem: Map<String, Any?>) {
    enum class Status(val value: Int) {
        OPEN(0),
        PREPARING(1),
        FULFILLED(2),
        CANCELED(3);

        val humanReadable: String?
            get() {
                when (this) {
                    OPEN -> return "placed"
                    FULFILLED -> return "delivered"
                    CANCELED -> return "cancelled"
                    PREPARING -> return "preparing"
                }
            }

        val color: Int
            get() {
            when (this) {
                OPEN -> return android.R.color.darker_gray
                FULFILLED -> return android.R.color.holo_green_light
                CANCELED -> return android.R.color.holo_red_light
                PREPARING -> return android.R.color.holo_blue_dark
            }
        }

        val textColor: Int
            get() {
                when (this) {
                    OPEN -> return android.R.color.black
                    FULFILLED -> return android.R.color.white
                    CANCELED -> return android.R.color.white
                    PREPARING -> return android.R.color.white
                }
            }

        companion object  {
            fun fromInt(value: Int) = Status.values().find{ it.value == value }
        }
    }

    var id: String = resultItem["_id"] as String
    val createdOn: DateTime = (resultItem["createdOn"] as String).toISODate()
    val status: Status = Status.fromInt(resultItem["status"] as Int) ?: Status.OPEN
    var deleted = resultItem["deleted"] as Boolean
}
