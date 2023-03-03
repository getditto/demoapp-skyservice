package live.dittolive.skyservice.models

import android.content.Context
import android.os.Build
import live.dittolive.skyservice.*
import org.joda.time.format.DateTimeFormat
import java.util.*

data class SectionOfSettingItems(val itemType: Type, val text: String, var data: String? = null, var state: Boolean = true) {
    enum class Type {
        HEADER,
        LABELED_DETAIL,
        DETAILED,
        EDIT_ITEM,
        SWITCH_ITEM,
        BUTTON_ITEM,
    }

    companion object {
        fun buildSettingsData(context: Context): List<SectionOfSettingItems> {
            val data = mutableListOf<SectionOfSettingItems>()

            //Current Flight Info
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.HEADER, context.getString(R.string.current_flight_info)))
            val fmt = DateTimeFormat.forPattern("MMMM dd, yyyy").withLocale(Locale.ENGLISH);
            val workspace = DataService.workspaceId?.let { WorkspaceId(it) }
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.LABELED_DETAIL, context.getString(
                R.string.login_departure_label_text),
                workspace?.departureDate?.let {
                    fmt.print(
                        it.time
                    )
                }))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.LABELED_DETAIL, context.getString(
                R.string.login_flight_label_text), workspace?.flightNumber))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.SWITCH_ITEM, context.getString(R.string.ordering_enabled)))

            //My Profile
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.HEADER, context.getString(R.string.my_profile)))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.EDIT_ITEM, context.getString(R.string.login_name_hint)))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.EDIT_ITEM, context.getString(R.string.login_seat_label_text)))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.BUTTON_ITEM, context.getString(R.string.save_profile)))

            //App Info
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.HEADER, context.getString(R.string.app_info)))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.LABELED_DETAIL, context.getString(
                R.string.build_label),context.getString(
                R.string.build_info,
                BuildConfig.VERSION_CODE.toString(),
                BuildConfig.VERSION_NAME
            )))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.LABELED_DETAIL, context.getString(
                R.string.android_label), Build.VERSION.RELEASE))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.LABELED_DETAIL, context.getString(
                R.string.version_label), SkyServiceApplication.ditto?.sdkVersion))
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.BUTTON_ITEM, context.getString(R.string.app_settings)))
            //Footer Button
            data.add(SectionOfSettingItems(SectionOfSettingItems.Type.BUTTON_ITEM, context.getString(R.string.logout)))

            return data
        }
    }
}
