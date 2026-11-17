package lab.telegramconcept.multiswipe

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.SimpleItemAnimator

class MainActivity : Activity(), ChatRowView.Listener {

    private lateinit var adapter: ChatAdapter
    private lateinit var list: RecyclerView
    private lateinit var undoBar: LinearLayout
    private lateinit var undoText: TextView
    private var undoChat: Chat? = null
    private var openRow: ChatRowView? = null
    private val hideUndo = Runnable { undoBar.animate().translationY(undoBar.height * 1.5f).alpha(0f).setDuration(180).start() }

    private fun dp(v: Float) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }

        // header
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16f), dp(8f), dp(4f), dp(8f))
        }
        val titles = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        titles.addView(TextView(this).apply {
            text = getString(R.string.header_title)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(ContextCompat.getColor(context, R.color.text_primary))
            ViewCompat.setAccessibilityHeading(this, true)
        })
        titles.addView(TextView(this).apply {
            text = getString(R.string.header_mock_label)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(ContextCompat.getColor(context, R.color.action_pin))
        })
        titles.addView(TextView(this).apply {
            text = getString(R.string.header_hint)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(ContextCompat.getColor(context, R.color.text_secondary))
        })
        header.addView(titles, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
        header.addView(ImageButton(this).apply {
            setImageResource(R.drawable.ic_tune)
            background = null
            contentDescription = getString(R.string.settings_button)
            setOnClickListener { startActivity(android.content.Intent(context, SettingsActivity::class.java)) }
        }, LinearLayout.LayoutParams(dp(48f), dp(48f)))
        root.addView(header, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))

        // list
        adapter = ChatAdapter(this)
        list = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(context)
            adapter = this@MainActivity.adapter
            overScrollMode = View.OVER_SCROLL_NEVER
            (itemAnimator as SimpleItemAnimator).supportsChangeAnimations = false
            addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrollStateChanged(rv: RecyclerView, newState: Int) {
                    if (newState == RecyclerView.SCROLL_STATE_DRAGGING) closeOpenRow()
                }
            })
        }
        root.addView(list, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))

        undoBar = buildUndoBar()

        // overlay the undo bar on top of the list
        val frame = android.widget.FrameLayout(this)
        frame.addView(root, MATCH_PARENT, MATCH_PARENT)
        frame.addView(undoBar, android.widget.FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM).apply {
            setMargins(dp(12f), 0, dp(12f), dp(12f))
        })
        setContentView(frame)

        ViewCompat.setOnApplyWindowInsetsListener(frame) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            root.setPadding(bars.left, bars.top, bars.right, 0)
            list.setPadding(0, 0, 0, bars.bottom)
            list.clipToPadding = false
            (undoBar.layoutParams as android.widget.FrameLayout.LayoutParams).bottomMargin = dp(12f) + bars.bottom
            insets
        }

        adapter.submitList(ChatStore.visible())
    }

    override fun onResume() {
        super.onResume()
        // Settings may have changed: rebind so rows pick up new actions/accessibility actions.
        closeOpenRow()
        adapter.notifyItemRangeChanged(0, adapter.itemCount)
    }

    private fun buildUndoBar(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16f), dp(4f), dp(8f), dp(4f))
            background = GradientDrawable().apply {
                setColor(ContextCompat.getColor(context, R.color.undo_bg)); cornerRadius = dp(12f).toFloat()
            }
            elevation = dp(6f).toFloat()
            alpha = 0f
            visibility = View.INVISIBLE
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        undoText = TextView(this).apply {
            setTextColor(ContextCompat.getColor(context, R.color.undo_text))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        }
        bar.addView(undoText, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
        bar.addView(Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = getString(R.string.undo)
            isAllCaps = true
            minimumHeight = dp(48f)
            setTextColor(ContextCompat.getColor(context, R.color.undo_action))
            setOnClickListener {
                undoChat?.let { ChatStore.restore(it) }
                undoChat = null
                adapter.submitList(ChatStore.visible())
                undoBar.removeCallbacks(hideUndo)
                hideUndo.run()
            }
        }, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        return bar
    }

    private fun showUndo(message: String, previous: Chat) {
        undoChat = previous
        undoText.text = message
        undoBar.removeCallbacks(hideUndo)
        undoBar.visibility = View.VISIBLE
        undoBar.translationY = dp(24f).toFloat()
        undoBar.animate().translationY(0f).alpha(1f).setDuration(220).start()
        undoBar.postDelayed(hideUndo, 5000)
    }

    private fun closeOpenRow() {
        openRow?.closeAnimated()
        openRow = null
    }

    // ---- ChatRowView.Listener ----------------------------------------------------------------------------------------

    override fun onTouchDown(row: ChatRowView) {
        if (openRow != null && openRow !== row) closeOpenRow()
    }

    override fun onDragStart(row: ChatRowView) {
        if (openRow !== row) closeOpenRow()
        openRow = row
    }

    override fun onSettledOpen(row: ChatRowView) {
        openRow = row
    }

    override fun onAction(chat: Chat, action: SwipeAction) {
        val previous = ChatStore.find(chat.id) ?: return
        ChatStore.apply(action, chat.id)
        adapter.submitList(ChatStore.visible())
        val name = previous.name
        val msg = when (action) {
            SwipeAction.PIN -> getString(if (previous.pinned) R.string.done_unpinned else R.string.done_pinned, name)
            SwipeAction.READ -> getString(if (previous.showUnread) R.string.done_read else R.string.done_unread, name)
            SwipeAction.MUTE -> getString(if (previous.muted) R.string.done_unmuted else R.string.done_muted, name)
            SwipeAction.ARCHIVE -> getString(R.string.done_archived, name)
            SwipeAction.DELETE -> getString(R.string.done_deleted, name)
        }
        if (openRow != null && action.removesRow) openRow = null
        showUndo(msg, previous)
    }

    override fun onOpenChat(chat: Chat) {
        Toast.makeText(this, getString(R.string.open_chat_stub, chat.name), Toast.LENGTH_SHORT).show()
    }

    /** Non-gesture alternative: every enabled action in one menu. */
    override fun onLongPress(chat: Chat) {
        val actions = (SwipeConfig.visible(Side.LEADING) + SwipeConfig.visible(Side.TRAILING)).distinct()
        if (actions.isEmpty()) return
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.actions_menu_title, chat.name))
            .setItems(actions.map { it.label(this, chat) }.toTypedArray()) { _, i -> onAction(chat, actions[i]) }
            .show()
    }
}
