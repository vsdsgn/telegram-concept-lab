package dev.telegramconceptlab.reactionwheel

import android.app.Dialog
import android.content.Context
import android.content.res.Configuration
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.provider.Settings
import android.view.*
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.graphics.ColorUtils
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import java.util.Locale
import kotlin.math.*

data class DemoMessage(val sender: String, val text: String, val time: String, val outgoing: Boolean, var reaction: Int? = null)

class MainActivity : AppCompatActivity() {
    private lateinit var root: FrameLayout
    private lateinit var list: LinearLayout
    private lateinit var scroll: ScrollView
    private lateinit var overlay: WheelOverlay
    private val messageViews = mutableListOf<MessageView>()
    private var reduceMotionOverride = false
    private var haptics = true
    private var debug = false
    private val messages = listOf(
        DemoMessage("Alex", "Are we still meeting by the river this weekend?", "10:32", false),
        DemoMessage("You", "Yes — Saturday around eleven works for me.", "10:34", true),
        DemoMessage("Sam", "I tested the release notes for our imaginary app. Everything reads clearly.", "10:38", false),
        DemoMessage("You", "Perfect. I’ll bring the lemon cake recipe too.", "10:39", true),
        DemoMessage("Robin", "The trick is a little cardamom and a lot of patience. This deliberately long mock message checks that a multi-line bubble remains comfortable and never becomes a tiny reaction target.", "10:41", false),
        DemoMessage("You", "🔥", "10:42", true),
        DemoMessage("Alex", "I can bring tea, cups, and a blanket.", "10:44", false),
        DemoMessage("Sam", "Forecast says clear skies after lunch.", "10:46", false),
        DemoMessage("You", "Let’s keep a backup plan in case it changes.", "10:47", true),
        DemoMessage("Robin", "The museum café is nearby.", "10:49", false),
        DemoMessage("Alex", "That sounds easy.", "10:51", false),
        DemoMessage("You", "Great, see everyone Saturday!", "10:52", true)
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        buildUi()
    }

    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(color(R.color.chat_bg)); fitsSystemWindows = false }
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(column, FrameLayout.LayoutParams(-1, -1))
        ViewCompat.setOnApplyWindowInsetsListener(column) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            v.setPadding(bars.left, bars.top, bars.right, bars.bottom); insets
        }
        column.addView(topBar())
        column.addView(infoRow(getString(R.string.demo_banner), true))
        column.addView(infoRow(getString(R.string.hint), false).apply { id = R.id.chat_hint })
        scroll = ScrollView(this).apply { id = R.id.chat_list; isFillViewport = true; contentDescription = getString(R.string.mock_label) }
        list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(10), dp(16), dp(24)) }
        scroll.addView(list, FrameLayout.LayoutParams(-1, -2)); column.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        messages.forEachIndexed { index, message ->
            val view = MessageView(this, message, index).also { messageViews += it }
            list.addView(view, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(if (index > 0 && messages[index-1].sender == message.sender) 4 else 10) })
        }
        overlay = WheelOverlay(this).apply { visibility = View.GONE }
        root.addView(overlay, FrameLayout.LayoutParams(-1, -1))
        setContentView(root)
        scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun topBar() = LinearLayout(this).apply {
        gravity = Gravity.CENTER_VERTICAL; setPadding(dp(16), 0, dp(4), 0); setBackgroundColor(color(R.color.chat_bg))
        addView(TextView(context).apply { text = getString(R.string.app_name); textSize = 20f; setTextColor(color(R.color.text_primary)); setTypeface(typeface, 1) }, LinearLayout.LayoutParams(0, dp(56), 1f).apply { gravity = Gravity.CENTER_VERTICAL })
        addView(ImageButton(context).apply { id = R.id.settings_open; setImageResource(R.drawable.ic_settings); contentDescription = getString(R.string.settings); background = theme.obtainStyledAttributes(intArrayOf(android.R.attr.selectableItemBackgroundBorderless)).let { a -> a.getDrawable(0).also { a.recycle() } }; setOnClickListener { showSettings() } }, LinearLayout.LayoutParams(dp(48), dp(48)))
    }

    private fun infoRow(value: String, banner: Boolean) = TextView(this).apply {
        text = value; textSize = 12f; gravity = Gravity.CENTER; setTextColor(color(R.color.text_secondary)); setPadding(dp(12), dp(5), dp(12), dp(5)); minHeight = dp(28)
        setBackgroundColor(if (banner) ColorUtils.setAlphaComponent(color(R.color.accent), 24) else color(R.color.chat_bg))
    }

    inner class MessageView(context: Context, val data: DemoMessage, val index: Int): LinearLayout(context) {
        private val bubble: LinearLayout
        private var chip: Button? = null
        init {
            orientation = VERTICAL; gravity = if (data.outgoing) Gravity.END else Gravity.START; id = resources.getIdentifier("chat_message_${index}", "id", packageName)
            bubble = LinearLayout(context).apply {
                orientation = VERTICAL; isFocusable = true; isClickable = true; isLongClickable = true; setPadding(dp(12), dp(8), dp(12), dp(7)); background = rounded(if (data.outgoing) color(R.color.bubble_out) else color(R.color.bubble_in), 18f)
                addView(TextView(context).apply { text = data.text; textSize = 16f; setTextColor(color(R.color.text_primary)) })
                addView(TextView(context).apply { text = "${data.sender} · ${data.time}"; textSize = 11f; gravity = Gravity.END; setTextColor(color(R.color.text_secondary)); setPadding(0, dp(3), 0, 0) })
                setOnTouchListener { _, e -> handleBubbleTouch(this@MessageView, e) }
                setOnLongClickListener { openPersistent(this@MessageView); true }
                setOnClickListener { openPersistent(this@MessageView) }
                ViewCompat.setAccessibilityDelegate(this, object: androidx.core.view.AccessibilityDelegateCompat() {
                    override fun onInitializeAccessibilityNodeInfo(host: View, info: androidx.core.view.accessibility.AccessibilityNodeInfoCompat) {
                        super.onInitializeAccessibilityNodeInfo(host, info)
                        info.contentDescription = description()
                        info.addAction(androidx.core.view.accessibility.AccessibilityNodeInfoCompat.AccessibilityActionCompat(0x01020001, getString(R.string.react)))
                        if (data.reaction != null) info.addAction(androidx.core.view.accessibility.AccessibilityNodeInfoCompat.AccessibilityActionCompat(0x01020002, getString(R.string.remove_reaction)))
                    }
                    override fun performAccessibilityAction(host: View, action: Int, args: Bundle?): Boolean = when(action) {
                        0x01020001, AccessibilityNodeInfo.ACTION_LONG_CLICK -> { openPersistent(this@MessageView); true }
                        0x01020002 -> { removeReaction(this@MessageView); true }
                        else -> super.performAccessibilityAction(host, action, args)
                    }
                })
                setOnKeyListener { _, key, event -> if (event.action == KeyEvent.ACTION_UP && (key == KeyEvent.KEYCODE_ENTER || key == KeyEvent.KEYCODE_SPACE)) { openPersistent(this@MessageView); true } else false }
            }
            addView(bubble, LayoutParams(-2, -2).apply { width = (resources.displayMetrics.widthPixels * .78f).toInt() })
            refresh()
        }
        fun description(): String { val r = data.reaction?.let { localizedName(it) }; return "${data.sender}, message, ${data.text}, ${data.time}. ${r?.let { "Your reaction: $it" } ?: "No reaction"}" }
        fun refresh() {
            bubble.contentDescription = description()
            chip?.let { removeView(it) }; chip = null
            data.reaction?.let { value ->
                chip = Button(context).apply {
                    text = "${Reactions.all[value].glyph}  1"; textSize = 14f; isAllCaps = false; minHeight = dp(48); minimumHeight = dp(48); setPadding(dp(8), 0, dp(8), 0)
                    background = rounded(color(R.color.chip_mine), 14f); contentDescription = "Remove ${localizedName(value)} reaction"
                    setOnClickListener { removeReaction(this@MessageView) }
                }
                addView(chip, LayoutParams(-2, dp(48)).apply { topMargin = dp(2) })
            }
        }
        fun bubbleCenter(): Pair<Float, Float> { val loc = IntArray(2); bubble.getLocationOnScreen(loc); val rootLoc = IntArray(2); root.getLocationOnScreen(rootLoc); return Pair(loc[0]-rootLoc[0]+bubble.width/2f, loc[1]-rootLoc[1]+bubble.height/2f) }
    }

    private var pending: Runnable? = null
    private var activeMessage: MessageView? = null
    private var downX = 0f; private var downY = 0f; private val handler = Handler(Looper.getMainLooper())
    private val slop by lazy { ViewConfiguration.get(this).scaledTouchSlop }

    private fun handleBubbleTouch(message: MessageView, event: MotionEvent): Boolean {
        val loc = IntArray(2); root.getLocationOnScreen(loc); val x = event.rawX-loc[0]; val y = event.rawY-loc[1]
        when(event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { activeMessage = message; downX=x; downY=y; pending?.let(handler::removeCallbacks); pending = Runnable { if (activeMessage === message) openHeld(message, downX, downY) }.also { handler.postDelayed(it, 350) }; handler.postDelayed({ if (activeMessage === message && overlay.visibility != View.VISIBLE) message.scaleX=.98f.also { message.scaleY=.98f } },100); return true }
            MotionEvent.ACTION_MOVE -> {
                if (overlay.visibility == View.VISIBLE) { overlay.track(x,y); return true }
                if (hypot(x-downX,y-downY)>slop) { cancelPending(message); message.parent?.requestDisallowInterceptTouchEvent(false); return false }
            }
            MotionEvent.ACTION_UP -> { if (overlay.visibility == View.VISIBLE) overlay.finish(x,y) else cancelPending(message); return true }
            MotionEvent.ACTION_CANCEL -> { if (overlay.visibility == View.VISIBLE) overlay.cancelWheel() else cancelPending(message); return false }
            MotionEvent.ACTION_POINTER_DOWN -> return true
        }
        return true
    }
    private fun cancelPending(message: MessageView) { pending?.let(handler::removeCallbacks); pending=null; activeMessage=null; message.animate().scaleX(1f).scaleY(1f).setDuration(if(reducedMotion())0 else 120).start() }
    private fun openHeld(message: MessageView, x: Float, y: Float) { pending=null; message.parent?.requestDisallowInterceptTouchEvent(true); scroll.isEnabled=false; message.scaleX=1f; message.scaleY=1f; overlay.open(message,x,y,false) }

    private fun openPersistent(message: MessageView) { cancelPending(message); showPicker(message) }
    private fun showPicker(message: MessageView) {
        val dialog = Dialog(this).apply { setTitle(getString(R.string.choose)); window?.setDimAmount(.45f) }
        val panel = LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setPadding(dp(16),dp(12),dp(16),dp(16)); background=rounded(color(R.color.bubble_in),24f) }
        panel.addView(TextView(this).apply { text=getString(R.string.choose); textSize=20f; setTypeface(typeface,1); setTextColor(color(R.color.text_primary)); setPadding(dp(8),0,0,dp(8)) })
        Reactions.all.forEachIndexed { i,r -> panel.addView(Button(this).apply { id=resources.getIdentifier("compact_item_$i","id",packageName); text="${r.glyph}  ${localizedName(i)}"; isAllCaps=false; textSize=16f; minHeight=dp(48); contentDescription="${localizedName(i)}, ${i+1} of 6${if(message.data.reaction==i) ", selected. Remove ${localizedName(i)} reaction" else ""}"; setOnClickListener { dialog.dismiss(); commit(message,i) } }, LinearLayout.LayoutParams(-1,dp(52)).apply { bottomMargin=dp(4) }) }
        panel.addView(Button(this).apply { text=getString(R.string.close); contentDescription=getString(R.string.close); isAllCaps=false; setOnClickListener { dialog.dismiss() } }, LinearLayout.LayoutParams(-1,dp(48)))
        val scroller=ScrollView(this).apply { addView(panel); accessibilityPaneTitle=getString(R.string.reaction_wheel) }
        dialog.setContentView(scroller); dialog.setOnDismissListener { message.requestFocus(); message.announceForAccessibility(descriptionFor(message)) }; dialog.setOnShowListener { dialog.window?.setLayout(min(dp(340),resources.displayMetrics.widthPixels-dp(24)),-2); panel.getChildAt(1).requestFocus(); panel.announceForAccessibility(getString(R.string.reaction_wheel)) }; dialog.show()
    }

    private fun commit(message: MessageView, reaction: Int) {
        val old=message.data.reaction
        if(old==reaction) { removeReaction(message); return }
        message.data.reaction=reaction; message.refresh(); haptic(message, if(Build.VERSION.SDK_INT>=30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
        val announcement=if(old==null) "Reacted with ${localizedName(reaction)}" else "Reaction changed to ${localizedName(reaction)}"
        message.announceForAccessibility(announcement); message.requestFocus()
    }
    private fun removeReaction(message: MessageView) { if(message.data.reaction==null)return; message.data.reaction=null; message.refresh(); haptic(message,if(Build.VERSION.SDK_INT>=30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY); message.announceForAccessibility("Reaction removed"); message.requestFocus() }
    private fun descriptionFor(message: MessageView)=message.description()

    private fun showSettings() {
        val box=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setPadding(dp(20),dp(12),dp(20),dp(20)) }
        fun toggle(label:Int,checked:Boolean,on:(Boolean)->Unit)=Switch(this).apply { text=getString(label); isChecked=checked; setTextColor(color(R.color.text_primary)); minHeight=dp(48); setOnCheckedChangeListener { _,v->on(v) } }
        box.addView(toggle(R.string.theme, resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK==Configuration.UI_MODE_NIGHT_YES) { AppCompatDelegate.setDefaultNightMode(if(it)AppCompatDelegate.MODE_NIGHT_YES else AppCompatDelegate.MODE_NIGHT_NO) })
        box.addView(toggle(R.string.reduce_motion,reduceMotionOverride){reduceMotionOverride=it})
        box.addView(toggle(R.string.haptics,haptics){haptics=it})
        box.addView(toggle(R.string.debug,debug){debug=it;overlay.invalidate()})
        box.addView(Button(this).apply { text=getString(R.string.reset); isAllCaps=false; minHeight=dp(48); setOnClickListener { android.app.AlertDialog.Builder(this@MainActivity).setMessage("Reset all mock reactions?").setNegativeButton(android.R.string.cancel,null).setPositiveButton(android.R.string.ok){_,_->messages.forEach{it.reaction=null};messageViews.forEach{it.refresh()}}.show() } })
        android.app.AlertDialog.Builder(this).setTitle(R.string.settings).setView(box).setPositiveButton(R.string.close,null).show()
    }

    inner class WheelOverlay(context: Context): View(context) {
        private val state=WheelStateMachine(); private var message:MessageView?=null; private var ax=0f;private var ay=0f;private var cx=0f;private var cy=0f;private var axis=0.0
        private var centersPx=emptyList<Pair<Float,Float>>(); private var centersDp=emptyList<Pair<Float,Float>>(); private val paint=Paint(3); private var lastTick=0L
        fun open(m:MessageView,x:Float,y:Float,persistent:Boolean) { message=m;ax=x;ay=y; val placement=place(x,y);cx=placement.first;cy=placement.second;axis=placement.third; computeCenters();state.open();visibility=VISIBLE;alpha=if(reducedMotion())0f else 1f;if(reducedMotion())animate().alpha(1f).setDuration(100).start();haptic(this,HapticFeedbackConstants.LONG_PRESS);invalidate() }
        private fun place(x:Float,y:Float):Triple<Float,Float,Double> { val margin=dp(52).toFloat(); val radius=dp(108).toFloat(); val candidates=listOf(0.0,Math.PI,Math.PI/2,Math.PI*3/2,Math.PI*3/4,Math.PI*5/4,Math.PI/4,Math.PI*7/4); candidates.forEach { a-> val pts=itemCenters(x,y,a,radius); if(pts.all{it.first in margin..width-margin && it.second in margin..height-margin})return Triple(x,y,a) }; return Triple(x.coerceIn(margin,width-margin),y.coerceIn(margin,height-margin),0.0) }
        private fun itemCenters(x:Float,y:Float,a:Double,r:Float)=List(6){i->val angle=a+Math.toRadians(-90.0+36.0*i);Pair(x+sin(angle).toFloat()*r,y-cos(angle).toFloat()*r)}
        private fun computeCenters(){centersPx=itemCenters(cx,cy,axis,dp(108).toFloat());centersDp=centersPx.map{Pair(it.first/density,it.second/density)}}
        fun track(x:Float,y:Float){val before=state.selected;state.move(ax/density,ay/density,x/density,y/density,centersDp);if(state.selected>=0&&state.selected!=before&&SystemClock.uptimeMillis()-lastTick>=85){haptic(this,if(Build.VERSION.SDK_INT>=34)HapticFeedbackConstants.SEGMENT_FREQUENT_TICK else HapticFeedbackConstants.CLOCK_TICK);lastTick=SystemClock.uptimeMillis()};invalidate()}
        fun finish(x:Float,y:Float){val chosen=state.release(ax/density,ay/density,x/density,y/density,centersDp); val target=message;dismiss();if(chosen!=null&&target!=null)commit(target,chosen)}
        fun cancelWheel(){state.cancel();dismiss()}
        private fun dismiss(){animate().cancel(); if(reducedMotion()){alpha=0f;end()}else animate().alpha(0f).setDuration(160).withEndAction{end()}.start()}
        private fun end(){visibility=GONE;alpha=1f;scroll.isEnabled=true;activeMessage=null;root.requestDisallowInterceptTouchEvent(false);message?.requestFocus()}
        override fun onDraw(c:Canvas){super.onDraw(c);paint.color=ColorUtils.setAlphaComponent(Color.BLACK,if(isNight())140 else 72);c.drawRect(0f,0f,width.toFloat(),height.toFloat(),paint);paint.style=Paint.Style.STROKE;paint.strokeWidth=dp(64).toFloat();paint.strokeCap=Paint.Cap.ROUND;paint.color=if(isNight())Color.rgb(35,44,54) else Color.WHITE;c.drawArc(cx-dp(108),cy-dp(108),cx+dp(108),cy+dp(108),(-180+Math.toDegrees(axis)).toFloat(),180f,false,paint);paint.style=Paint.Style.FILL
            centersPx.forEachIndexed{i,p->val selected=i==state.selected;val s=if(reducedMotion())1f else if(selected)1.4f else if(state.selected>=0).9f else 1f;paint.color=if(selected)color(R.color.chip_mine) else if(isNight())Color.rgb(35,44,54) else Color.WHITE;c.drawCircle(p.first,p.second,dp(24)*s,paint);paint.textAlign=Paint.Align.CENTER;paint.textSize=dp(28)*s;c.drawText(Reactions.all[i].glyph,p.first,p.second+paint.textSize*.35f,paint);if(selected&&message?.data?.reaction==i){paint.color=color(R.color.accent);paint.textSize=dp(16).toFloat();c.drawText("−",p.first+dp(22),p.second-dp(20),paint)}}
            val label=when{state.state==WheelStateMachine.State.SELECTED&&state.selected>=0->if(message?.data?.reaction==state.selected)"Remove ${localizedName(state.selected)}" else localizedName(state.selected);state.state==WheelStateMachine.State.OUTSIDE->getString(R.string.release_cancel);else->getString(R.string.slide_choose)};paint.textSize=dp(13).toFloat();paint.typeface=Typeface.DEFAULT_BOLD;val w=paint.measureText(label)+dp(24);val ly=(cy+dp(54)).coerceAtMost(height-dp(28).toFloat());paint.color=if(isNight())Color.argb(235,242,245,247) else Color.argb(225,17,20,24);c.drawRoundRect(cx-w/2,ly-dp(16),cx+w/2,ly+dp(16),dp(16).toFloat(),dp(16).toFloat(),paint);paint.color=if(isNight())Color.rgb(17,20,24) else Color.WHITE;c.drawText(label,cx,ly+dp(5),paint)
            if(debug){paint.style=Paint.Style.STROKE;paint.strokeWidth=dp(1).toFloat();paint.color=Color.MAGENTA;c.drawCircle(ax,ay,dp(44).toFloat(),paint);c.drawCircle(ax,ay,dp(32).toFloat(),paint);paint.style=Paint.Style.FILL}
        }
    }

    override fun onStop(){super.onStop();if(::overlay.isInitialized&&overlay.visibility==View.VISIBLE)overlay.cancelWheel()}
    private val density get()=resources.displayMetrics.density
    private fun dp(v:Int)=(v*density+.5f).toInt()
    private fun color(id:Int)=getColor(id)
    private fun rounded(c:Int,r:Float)=GradientDrawable().apply{setColor(c);cornerRadius=dp(r.toInt()).toFloat()}
    private fun localizedName(i:Int)=if(Locale.getDefault().language=="ru")Reactions.all[i].ru else Reactions.all[i].en
    private fun isNight()=resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK==Configuration.UI_MODE_NIGHT_YES
    private fun reducedMotion():Boolean { val system=runCatching{Settings.Global.getFloat(contentResolver,Settings.Global.ANIMATOR_DURATION_SCALE,1f)==0f}.getOrDefault(false);return reduceMotionOverride||system }
    private fun haptic(v:View,constant:Int){if(haptics)v.performHapticFeedback(constant)}
}
