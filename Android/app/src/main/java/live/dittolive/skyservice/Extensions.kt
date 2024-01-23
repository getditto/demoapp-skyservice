package live.dittolive.skyservice


import android.widget.EditText
import androidx.core.widget.doAfterTextChanged
import com.beust.klaxon.Converter
import com.beust.klaxon.JsonValue
import io.reactivex.rxjava3.core.Observable
import live.ditto.*
import org.joda.time.DateTime
import org.joda.time.format.DateTimeFormat
import org.joda.time.format.ISODateTimeFormat
import java.util.*

fun Ditto.resultItems(query: String, args: Map<String, Any>? = null): Observable<List<DittoQueryResultItem>> {
    return Observable.create { observer ->
        try {
            val subs: DittoSyncSubscription
            val handler: DittoStoreObserver

            if (args == null) {
                subs = sync.registerSubscription(query)
                handler = store.registerObserver(query) { result ->
                    observer.onNext(result.items)
                }
            } else {
                subs = sync.registerSubscription(query, args)
                handler = store.registerObserver(query, args) { result ->
                    observer.onNext(result.items)
                }
            }

            observer.setCancellable() {
                subs.close()
                handler.close()
            }
        } catch (e: Exception) {
            println("Error $e")
        }
    }
}

fun Ditto.observeLocalDocuments(query: String, args: Map<String, Any>? = null): Observable<List<DittoQueryResultItem>> {
    return Observable.create { observer ->

        val handler: DittoStoreObserver = if (args == null) {
            this.store.registerObserver(query) { result ->
                observer.onNext(result.items)
            }
        } else {
            this.store.registerObserver(query, args) { result ->
                observer.onNext(result.items)
            }
        }

        observer.setCancellable {
            handler.close()
        }
    }
}

fun String.toDittoID(): DittoDocumentId {
    return DittoDocumentId(this)
}

fun DittoCollection.findByID(id: String): DittoPendingIdSpecificOperation {
    return findById(id)
}

fun Ditto.resultWithOptional(query: String, args: Map<String, Any>? = null): Observable<Optional<DittoQueryResultItem>> {
    return Observable.create { observer ->
        try {
            val subs: DittoSyncSubscription
            val handler: DittoStoreObserver

            if (args == null) {
                subs = sync.registerSubscription(query)
                handler = store.registerObserver(query) { result ->
                    if (result.items.isEmpty()) {
                        observer.onNext(Optional.empty())
                    } else {
                        observer.onNext(Optional.of(result.items.first()))
                    }
                }
            } else {
                subs = sync.registerSubscription(query, args)
                handler = store.registerObserver(query, args) { result ->
                    if (result.items.isEmpty()) {
                        observer.onNext(Optional.empty())
                    } else {
                        observer.onNext(Optional.of(result.items.first()))
                    }
                }
            }

            observer.setCancellable() {
                subs.close()
                handler.close()
            }
        } catch (e: Exception) {
            println("Error $e")
        }
    }
}

fun String.toISODate(): DateTime {
    val format = DateTimeFormat.forPattern("yyyy-MM-dd'T'HH:mm:ssZ")
    return format.parseDateTime(this) ?: DateTime.now()
}

fun DateTime.toISOString(): String {
    return toString(ISODateTimeFormat.dateTimeNoMillis()) ?: run {
        val format = DateTimeFormat.forPattern("yyyy-MM-dd'T'HH:mm:ssZ")
        this.toString(format)
    }
}

fun EditText.validate(message: String, validator: (String) -> Boolean) {
    this.doAfterTextChanged {
        this.error = if (validator(it.toString())) null else message
    }
    this.error = null
}

fun String.isValidName(): Boolean
        = this.length >= 3

fun String.isValidSeatFormat(): Boolean {
    if (length < 2) { return false }
    try {
        val num = dropLast(this.length - 1).toInt()
        val lastChar = last().toUpperCase()
        return lastChar.isLetter() && (lastChar >= 'A' && lastChar <= 'Z') && (num >= 1 && num <= 200)
    } catch (e: NumberFormatException) {
        return false
    }
}

fun String.isValidFlightNumber(): Boolean {
    return length >= 4
//    if (length != 6) { return false }
//    val prefix = dropLast(4)
//    if (prefix != "EY") { return false }
//    val num = takeLast(4).toIntOrNull()
//    return num != null
}


// Klaxon
@Target(AnnotationTarget.FIELD)
annotation class KlaxonDate

val dateConverter = object: Converter {
    override fun canConvert(cls: Class<*>)
            = cls == DateTime::class.java

    override fun fromJson(jv: JsonValue) =
        jv.string?.toISODate() ?: DateTime.now()

    override fun toJson(o: Any)
            = (o as DateTime).toISOString()
}