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

data class CalendarWidgetThemeOption(
    val id: String,
    val name: String,
    val bgRgb: Int,
    val primary: Int,
    val textPrimary: Int,
    val textSecondary: Int
)

/**
 * Dialog-style activity launched from the calendar widget's settings button.
 * Lets the user pick a readable color theme and adjust only the widget
 * background alpha. The selection is stored in the `home_widget`
 * SharedPreferences and then an explicit widget update is triggered so the
 * change takes effect immediately.
 */
class CalendarWidgetSettingsActivity : Activity() {

    companion object {
        const val PREF_KEY_BG_ARGB = "widgetBgArgb"
        const val PREF_KEY_THEME_ID = "widgetCalendarThemeId"
        private const val STATE_SELECTED_THEME_ID = "selectedThemeId"
        private const val STATE_SELECTED_ALPHA = "selectedAlpha"

        val THEMES = arrayOf(
            CalendarWidgetThemeOption(
                id = "blush",
                name = "러브",
                bgRgb = 0xFFFFF5F8.toInt(),
                primary = 0xFFE91E63.toInt(),
                textPrimary = 0xFF424242.toInt(),
                textSecondary = 0xFF8E6B75.toInt()
            ),
            CalendarWidgetThemeOption(
                id = "clean",
                name = "화이트",
                bgRgb = 0xFFFFFFFF.toInt(),
                primary = 0xFFE91E63.toInt(),
                textPrimary = 0xFF303030.toInt(),
                textSecondary = 0xFF757575.toInt()
            ),
            CalendarWidgetThemeOption(
                id = "charcoal",
                name = "차콜",
                bgRgb = 0xFF242124.toInt(),
                primary = 0xFFFF7AA8.toInt(),
                textPrimary = 0xFFFFF7FA.toInt(),
                textSecondary = 0xFFE9B8C8.toInt()
            ),
            CalendarWidgetThemeOption(
                id = "mint",
                name = "민트",
                bgRgb = 0xFFF0FFF8.toInt(),
                primary = 0xFF00856F.toInt(),
                textPrimary = 0xFF20302B.toInt(),
                textSecondary = 0xFF53766B.toInt()
            ),
            CalendarWidgetThemeOption(
                id = "sky",
                name = "스카이",
                bgRgb = 0xFFF3FAFF.toInt(),
                primary = 0xFF1D6FD6.toInt(),
                textPrimary = 0xFF25313D.toInt(),
                textSecondary = 0xFF5D728A.toInt()
            ),
            CalendarWidgetThemeOption(
                id = "mono",
                name = "모노",
                bgRgb = 0xFFF6F6F6.toInt(),
                primary = 0xFF555555.toInt(),
                textPrimary = 0xFF252525.toInt(),
                textSecondary = 0xFF6D6D6D.toInt()
            )
        )

        fun themeFor(id: String?): CalendarWidgetThemeOption =
            THEMES.firstOrNull { it.id == id } ?: THEMES.first()
    }

    private var selectedThemeId: String = THEMES.first().id
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
            selectedAlpha = savedInstanceState.getInt(STATE_SELECTED_ALPHA, 255)
            selectedThemeId = savedInstanceState.getString(
                STATE_SELECTED_THEME_ID,
                THEMES.first().id
            ) ?: THEMES.first().id
        } else if (prefs.contains(PREF_KEY_BG_ARGB)) {
            val argb = prefs.getInt(PREF_KEY_BG_ARGB, 0xFFFFFFFF.toInt())
            selectedAlpha = Color.alpha(argb)
            selectedThemeId = prefs.getString(PREF_KEY_THEME_ID, null)
                ?: themeIdForLegacyColor(argb)
        } else {
            selectedThemeId = prefs.getString(PREF_KEY_THEME_ID, THEMES.first().id)
                ?: THEMES.first().id
        }

        // Bind theme swatches
        swatchViews = arrayOf(
            findViewById(R.id.swatch_0),
            findViewById(R.id.swatch_1),
            findViewById(R.id.swatch_2),
            findViewById(R.id.swatch_3),
            findViewById(R.id.swatch_4),
            findViewById(R.id.swatch_5)
        )
        for ((i, v) in swatchViews.withIndex()) {
            val theme = THEMES[i]
            if (v is TextView) {
                v.text = theme.name
                v.setTextColor(theme.textPrimary)
                v.contentDescription = "${theme.name} 테마"
            }
            v.background = makeSwatchDrawable(theme, selected = false)
            v.setOnClickListener {
                selectedThemeId = theme.id
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
            val theme = themeFor(selectedThemeId)
            val argb = (selectedAlpha shl 24) or (theme.bgRgb and 0x00FFFFFF)
            prefs.edit()
                .putString(PREF_KEY_THEME_ID, theme.id)
                .putInt(PREF_KEY_BG_ARGB, argb)
                .commit()
            triggerWidgetUpdate()
            finish()
        }
        findViewById<Button>(R.id.btn_cancel).setOnClickListener {
            finish()
        }
        findViewById<Button>(R.id.btn_reset).setOnClickListener {
            prefs.edit()
                .remove(PREF_KEY_THEME_ID)
                .remove(PREF_KEY_BG_ARGB)
                .commit()
            triggerWidgetUpdate()
            finish()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(STATE_SELECTED_THEME_ID, selectedThemeId)
        outState.putInt(STATE_SELECTED_ALPHA, selectedAlpha)
    }

    private fun alphaPercent(alpha: Int): Int =
        ((alpha.coerceIn(0, 255) * 100 + 127) / 255)

    private fun refreshSwatchSelection() {
        for ((i, v) in swatchViews.withIndex()) {
            val theme = THEMES[i]
            val selected = theme.id == selectedThemeId
            v.background = makeSwatchDrawable(theme, selected)
        }
    }

    private fun makeSwatchDrawable(theme: CalendarWidgetThemeOption, selected: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(theme.bgRgb)
            cornerRadius = dpToPx(8f).toFloat()
            val strokeWidth = dpToPx(if (selected) 3f else 1f)
            val strokeColor = if (selected) theme.primary else 0xFFBDBDBD.toInt()
            setStroke(strokeWidth, strokeColor)
        }
    }

    private fun updatePreview() {
        val theme = themeFor(selectedThemeId)
        val argb = (selectedAlpha shl 24) or (theme.bgRgb and 0x00FFFFFF)
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(argb)
            cornerRadius = dpToPx(10f).toFloat()
        }
        previewBox.background = bg

        findViewById<TextView>(R.id.preview_title).setTextColor(theme.primary)
        findViewById<TextView>(R.id.preview_month).setTextColor(theme.textPrimary)
        findViewById<TextView>(R.id.preview_day).setTextColor(theme.textSecondary)
    }

    private fun themeIdForLegacyColor(argb: Int): String {
        val rgb = (argb and 0x00FFFFFF) or 0xFF000000.toInt()
        return THEMES.minByOrNull { colorDistance(rgb, it.bgRgb) }?.id ?: THEMES.first().id
    }

    private fun colorDistance(a: Int, b: Int): Int {
        val dr = Color.red(a) - Color.red(b)
        val dg = Color.green(a) - Color.green(b)
        val db = Color.blue(a) - Color.blue(b)
        return dr * dr + dg * dg + db * db
    }

    private fun triggerWidgetUpdate() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val targets = listOf(
            HMLoveWidgetProvider::class.java to HMLoveWidgetProvider(),
            HMLoveSmallWidgetProvider::class.java to HMLoveSmallWidgetProvider(),
            HMLoveCalendarWidgetProvider::class.java to HMLoveCalendarWidgetProvider()
        )

        for ((providerClass, provider) in targets) {
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(this, providerClass))
            if (ids.isEmpty()) continue

            // Update immediately so the saved alpha/theme is reflected without
            // waiting for the launcher to dispatch the widget-update broadcast.
            provider.onUpdate(this, appWidgetManager, ids)

            val intent = Intent(this, providerClass).apply {
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
