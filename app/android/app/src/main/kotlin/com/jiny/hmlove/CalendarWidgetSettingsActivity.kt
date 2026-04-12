package com.jiny.hmlove

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.Button
import android.widget.SeekBar
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Dialog-style activity launched from the calendar widget's settings button.
 * Lets the user pick a preset background color and adjust the widget's
 * background alpha. The selection is stored in the `home_widget` SharedPreferences
 * under keys `widgetBgArgb` (Int, ARGB), and then an explicit widget update is
 * triggered so the change takes effect immediately.
 */
class CalendarWidgetSettingsActivity : Activity() {

    companion object {
        const val PREF_KEY_BG_ARGB = "widgetBgArgb"
        private const val STATE_SELECTED_RGB = "selectedRgb"
        private const val STATE_SELECTED_ALPHA = "selectedAlpha"

        // Preset palette — order mirrors swatch_0..swatch_11 in the layout.
        // Alpha channel here is ignored at selection time; the SeekBar controls alpha.
        private val PRESET_COLORS = intArrayOf(
            0xFFFFFFFF.toInt(), // white
            0xFFFFE4EC.toInt(), // soft pink (default-ish)
            0xFFE91E63.toInt(), // pink
            0xFFF44336.toInt(), // red
            0xFFFF9800.toInt(), // orange
            0xFFFFEB3B.toInt(), // yellow
            0xFF4CAF50.toInt(), // green
            0xFF2196F3.toInt(), // blue
            0xFF673AB7.toInt(), // purple
            0xFF795548.toInt(), // brown
            0xFF9E9E9E.toInt(), // gray
            0xFF212121.toInt()  // near-black
        )
    }

    private var selectedRgb: Int = 0xFFFFFFFF.toInt()
    private var selectedAlpha: Int = 255 // 0..255

    private lateinit var swatchViews: Array<View>
    private lateinit var alphaSeekBar: SeekBar
    private lateinit var alphaValueText: TextView
    private lateinit var previewBox: View

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_settings)

        val prefs = HomeWidgetPlugin.getData(this)

        // Restore in-progress selection if this is a recreated instance (e.g. rotation),
        // otherwise seed UI from the saved preference (or defaults).
        if (savedInstanceState != null) {
            selectedRgb = savedInstanceState.getInt(STATE_SELECTED_RGB, 0xFFFFFFFF.toInt())
            selectedAlpha = savedInstanceState.getInt(STATE_SELECTED_ALPHA, 255)
        } else if (prefs.contains(PREF_KEY_BG_ARGB)) {
            val argb = prefs.getInt(PREF_KEY_BG_ARGB, 0xFFFFFFFF.toInt())
            selectedAlpha = Color.alpha(argb)
            selectedRgb = (argb and 0x00FFFFFF) or 0xFF000000.toInt()
        }

        // Bind swatches
        swatchViews = arrayOf(
            findViewById(R.id.swatch_0),
            findViewById(R.id.swatch_1),
            findViewById(R.id.swatch_2),
            findViewById(R.id.swatch_3),
            findViewById(R.id.swatch_4),
            findViewById(R.id.swatch_5),
            findViewById(R.id.swatch_6),
            findViewById(R.id.swatch_7),
            findViewById(R.id.swatch_8),
            findViewById(R.id.swatch_9),
            findViewById(R.id.swatch_10),
            findViewById(R.id.swatch_11)
        )
        for ((i, v) in swatchViews.withIndex()) {
            val color = PRESET_COLORS[i]
            v.background = makeSwatchDrawable(color, selected = false)
            v.setOnClickListener {
                selectedRgb = PRESET_COLORS[i]
                refreshSwatchSelection()
                updatePreview()
            }
        }
        refreshSwatchSelection()

        // Bind seekbar. SeekBar.max = 255 so progress IS the alpha value directly;
        // this avoids rounding loss on open → save → reopen cycles.
        alphaSeekBar = findViewById(R.id.alpha_seekbar)
        alphaValueText = findViewById(R.id.alpha_value_text)
        alphaSeekBar.progress = selectedAlpha.coerceIn(0, 255)
        alphaValueText.text = "${alphaPercent(selectedAlpha)}%"
        alphaSeekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                selectedAlpha = progress.coerceIn(0, 255)
                alphaValueText.text = "${alphaPercent(selectedAlpha)}%"
                updatePreview()
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        // Preview
        previewBox = findViewById(R.id.preview_box)
        updatePreview()

        // Buttons
        findViewById<Button>(R.id.btn_apply).setOnClickListener {
            val argb = (selectedAlpha shl 24) or (selectedRgb and 0x00FFFFFF)
            prefs.edit().putInt(PREF_KEY_BG_ARGB, argb).apply()
            triggerWidgetUpdate()
            finish()
        }
        findViewById<Button>(R.id.btn_cancel).setOnClickListener {
            finish()
        }
        findViewById<Button>(R.id.btn_reset).setOnClickListener {
            prefs.edit().remove(PREF_KEY_BG_ARGB).apply()
            triggerWidgetUpdate()
            finish()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(STATE_SELECTED_RGB, selectedRgb)
        outState.putInt(STATE_SELECTED_ALPHA, selectedAlpha)
    }

    private fun alphaPercent(alpha: Int): Int =
        ((alpha.coerceIn(0, 255) * 100 + 127) / 255)

    private fun refreshSwatchSelection() {
        for ((i, v) in swatchViews.withIndex()) {
            val color = PRESET_COLORS[i]
            val selected = color == selectedRgb
            v.background = makeSwatchDrawable(color, selected)
        }
    }

    private fun makeSwatchDrawable(color: Int, selected: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
            val strokeWidth = dpToPx(if (selected) 3f else 1f)
            val strokeColor = if (selected) 0xFFE91E63.toInt() else 0xFFBDBDBD.toInt()
            setStroke(strokeWidth, strokeColor)
        }
    }

    private fun updatePreview() {
        val argb = (selectedAlpha shl 24) or (selectedRgb and 0x00FFFFFF)
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(argb)
            cornerRadius = dpToPx(10f).toFloat()
        }
        previewBox.background = bg
    }

    private fun triggerWidgetUpdate() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val component = ComponentName(this, HMLoveCalendarWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(component)
        if (ids.isNotEmpty()) {
            val intent = Intent(this, HMLoveCalendarWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(intent)
        }
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp, resources.displayMetrics
        ).toInt()
    }
}
