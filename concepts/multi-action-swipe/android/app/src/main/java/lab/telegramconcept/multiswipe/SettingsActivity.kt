package lab.telegramconcept.multiswipe

import android.app.Activity
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

/** Lets the user choose, order and limit the actions behind each swipe direction. */
class SettingsActivity : Activity() {

    private lateinit var content: LinearLayout

    private fun dp(v: Float) = (v * resources.displayMetrics.density).toInt()
    private fun color(res: Int) = ContextCompat.getColor(this, res)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16f), dp(8f), dp(16f), dp(24f))
        }
        val scroll = ScrollView(this).apply {
            clipToPadding = false
            addView(content, MATCH_PARENT, WRAP_CONTENT)
        }
        setContentView(scroll)
        ViewCompat.setOnApplyWindowInsetsListener(scroll) { v, insets ->
            val b = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            v.setPadding(b.left, b.top, b.right, b.bottom)
            insets
        }
        render()
    }

    private fun render() {
        content.removeAllViews()

        val bar = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        bar.addView(TextView(this).apply {
            text = "←"
            gravity = Gravity.CENTER
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            setTextColor(color(R.color.text_primary))
            contentDescription = getString(R.string.back)
            setOnClickListener { finish() }
        }, LinearLayout.LayoutParams(dp(48f), dp(48f)))
        bar.addView(heading(getString(R.string.settings_title), 22f), LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
        content.addView(bar)

        content.addView(note(getString(R.string.side_help, SwipeConfig.MAX_PER_SIDE)))
        for (side in Side.entries) addSide(side)

        content.addView(Switch(this).apply {
            text = getString(R.string.haptics)
            isChecked = SwipeConfig.haptics
            minHeight = dp(56f)
            setTextColor(color(R.color.text_primary))
            setOnCheckedChangeListener { _, on -> SwipeConfig.setHaptics(on) }
        }, topMargin(16f))
        content.addView(note(getString(R.string.haptics_help)))

        content.addView(Button(this).apply {
            text = getString(R.string.restore_mock)
            setOnClickListener {
                ChatStore.reset()
                Toast.makeText(context, R.string.restore_done, Toast.LENGTH_SHORT).show()
            }
        }, topMargin(16f))
    }

    private fun addSide(side: Side) {
        content.addView(
            heading(getString(if (side == Side.LEADING) R.string.side_leading else R.string.side_trailing), 16f),
            topMargin(20f),
        )
        for (action in SwipeConfig.order(side)) {
            val row = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
            row.addView(CheckBox(this).apply {
                text = getString(action.poolLabel)
                isChecked = SwipeConfig.isEnabled(side, action)
                minHeight = dp(48f)
                setTextColor(color(R.color.text_primary))
                setOnCheckedChangeListener { _, on ->
                    if (!SwipeConfig.setEnabled(side, action, on)) {
                        Toast.makeText(context, getString(R.string.max_actions, SwipeConfig.MAX_PER_SIDE), Toast.LENGTH_SHORT).show()
                    }
                    render()
                }
            }, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
            val name = getString(action.poolLabel)
            row.addView(arrow("↑", getString(R.string.move_up, name)) { SwipeConfig.move(side, action, -1); render() })
            row.addView(arrow("↓", getString(R.string.move_down, name)) { SwipeConfig.move(side, action, 1); render() })
            content.addView(row)
        }
        val full = SwipeConfig.fullSwipe(side)
        content.addView(
            note(
                if (full == null) getString(R.string.full_swipe_none)
                else getString(R.string.full_swipe_is, getString(full.poolLabel)),
            ),
        )
    }

    private fun arrow(glyph: String, description: String, onClick: () -> Unit) = TextView(this).apply {
        text = glyph
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
        setTextColor(color(R.color.accent))
        contentDescription = description
        minimumWidth = dp(48f)
        minimumHeight = dp(48f)
        setOnClickListener { onClick() }
    }

    private fun heading(text: String, size: Float) = TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        typeface = Typeface.DEFAULT_BOLD
        setTextColor(color(R.color.text_primary))
        ViewCompat.setAccessibilityHeading(this, true)
    }

    private fun note(text: String) = TextView(this).apply {
        this.text = text
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        setTextColor(color(R.color.text_secondary))
        setPadding(0, dp(4f), 0, dp(4f))
    }

    private fun topMargin(v: Float) = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(v) }
}
