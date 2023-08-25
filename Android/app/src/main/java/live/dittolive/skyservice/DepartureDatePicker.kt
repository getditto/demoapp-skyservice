package live.dittolive.skyservice

import android.app.DatePickerDialog
import android.app.Dialog
import android.os.Bundle
import android.widget.DatePicker
import androidx.fragment.app.DialogFragment
import java.util.*

interface DateSelection {
    fun didSelectionDate(date: Date)
}

class DatePickerFragment : DialogFragment(), DatePickerDialog.OnDateSetListener {
    lateinit var dateDelegate: DateSelection
    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val c = Calendar.getInstance()
        val year = c.get(Calendar.YEAR)
        val month = c.get(Calendar.MONTH)
        val day = c.get(Calendar.DAY_OF_MONTH)

        val dialog = DatePickerDialog(requireActivity(), R.style.DialogTheme, this, year, month, day)
        dialog.datePicker.minDate = System.currentTimeMillis() - 1000
        return dialog
    }

    override fun onDateSet(view: DatePicker, year: Int, month: Int, day: Int) {
        val c = Calendar.getInstance()
        c.set(year, month, day)
        dateDelegate.didSelectionDate(c.time)
    }
}