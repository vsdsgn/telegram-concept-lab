package lab.telegramconcept.multiswipe

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.dynamicanimation.animation.DynamicAnimation
import androidx.dynamicanimation.animation.FloatPropertyCompat
import androidx.dynamicanimation.animation.SpringAnimation
import androidx.dynamicanimation.animation.SpringForce
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * A chat-list row with a multi-action swipe, drawn on a single Canvas.
 *
 * Gesture model (see README "Gesture states"):
 *   IDLE -> PRESSED (touch-down) -> DRAGGING (horizontal slop passed) -> SETTLING (spring) -> IDLE | OPEN
 * The visual offset is the single source of truth; springs animate it, the finger sets it directly.
 * Positive offset = row moved right = LEADING actions revealed on the left; negative = TRAILING on the right.
 */
class ChatRowView(context: Context) : View(context) {

    interface Listener {
        /** Finger went down on this row (used to close any other open row). */
        fun onTouchDown(row: ChatRowView)
        fun onDragStart(row: ChatRowView)
        fun onSettledOpen(row: ChatRowView)
        fun onAction(chat: Chat, action: SwipeAction)
        fun onOpenChat(chat: Chat)
        fun onLongPress(chat: Chat)
        /** Non-gesture path (TalkBack custom action): the host decides whether to confirm destructive actions. */
        fun onAlternativeAction(chat: Chat, action: SwipeAction)
    }

    var listener: Listener? = null
    var chat: Chat? = null
        private set

    // ---- animated state -------------------------------------------------------------------------------------------

    /** Signed horizontal row offset in px. */
    var offset = 0f
        set(value) {
            field = value
            invalidate()
        }

    /** 0..1: how far the primary action has expanded to fill the revealed area (full-swipe armed). */
    var expand = 0f
        set(value) {
            field = value
            invalidate()
        }

    private val offsetProp = object : FloatPropertyCompat<ChatRowView>("offset") {
        override fun getValue(o: ChatRowView) = o.offset
        override fun setValue(o: ChatRowView, value: Float) {
            o.offset = value
        }
    }
    private val expandProp = object : FloatPropertyCompat<ChatRowView>("expand") {
        override fun getValue(o: ChatRowView) = o.expand * 1000f
        override fun setValue(o: ChatRowView, value: Float) {
            o.expand = value / 1000f
        }
    }
    private val offsetAnim = SpringAnimation(this, offsetProp)
    private val expandAnim = SpringAnimation(this, expandProp)

    // ---- gesture state ---------------------------------------------------------------------------------------------

    private var pressedContent = false
    private var pressedButton = -1
    private var dragging = false
    private var longPressed = false
    private var downX = 0f
    private var downY = 0f
    private var dragStartX = 0f
    private var dragStartOffset = 0f
    private var restOffset = 0f // where the row rests after a cancel/interrupt
    private var stage = SwipeLogic.STAGE_NONE
    private var velocityTracker: VelocityTracker? = null
    private var armed: SwipeAction? = null
    private var pendingCommit: SwipeAction? = null
    private var committing = false

    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private val longPressRunnable = Runnable {
        val c = chat ?: return@Runnable
        if (pressedContent && !dragging && abs(offset) < 1f) {
            longPressed = true
            pressedContent = false
            invalidate()
            Haptics.longPress(this)
            listener?.onLongPress(c)
        }
    }
    private val disarmRunnable = Runnable {
        armed = null
        invalidate()
    }

    // ---- metrics & paints ----------------------------------------------------------------------------------------------

    private val density = resources.displayMetrics.density
    private fun dp(v: Float) = v * density
    private fun sp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    private val fontScale = resources.configuration.fontScale
    private val buttonWidth = dp(76f) * max(1f, 1f + 0.5f * (fontScale - 1f))
    private val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = sp(16f); typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val previewPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = sp(15f) }
    private val timePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = sp(12f) }
    private val badgePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = sp(12f); typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER
    }
    private val initialsPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = sp(18f); typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.CENTER
        color = 0xFFFFFFFF.toInt()
    }
    private val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = sp(12f); color = 0xFFFFFFFF.toInt(); textAlign = Paint.Align.CENTER
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dividerPaint = Paint()

    private val cRowBg = ContextCompat.getColor(context, R.color.row_bg)
    private val cPinnedBg = ContextCompat.getColor(context, R.color.row_pinned_bg)
    private val cPressed = ContextCompat.getColor(context, R.color.row_pressed)
    private val cDivider = ContextCompat.getColor(context, R.color.divider)
    private val cPrimary = ContextCompat.getColor(context, R.color.text_primary)
    private val cSecondary = ContextCompat.getColor(context, R.color.text_secondary)
    private val cAccent = ContextCompat.getColor(context, R.color.accent)
    private val cBadgeMuted = ContextCompat.getColor(context, R.color.badge_muted)
    private val cDeleteArmed = ContextCompat.getColor(context, R.color.action_delete_armed)
    private val avatarColors = intArrayOf(
        0xFFE17076.toInt(), 0xFFEDA86C.toInt(), 0xFFA695E7.toInt(),
        0xFF7BC862.toInt(), 0xFF6EC9CB.toInt(), 0xFF65AADD.toInt(), 0xFFEE7AAE.toInt(),
    )

    private val iconCache = HashMap<Int, Drawable>()
    private fun icon(res: Int): Drawable = iconCache.getOrPut(res) {
        ContextCompat.getDrawable(context, res)!!.mutate().also { it.setTint(0xFFFFFFFF.toInt()) }
    }
    private val pinIcon: Drawable by lazy {
        ContextCompat.getDrawable(context, R.drawable.ic_pin)!!.mutate().also { it.setTint(cSecondary) }
    }

    private val starIcon: Drawable by lazy {
        ContextCompat.getDrawable(context, R.drawable.ic_star)!!.mutate().also { it.setTint(ContextCompat.getColor(context, R.color.action_favorite)) }
    }

    private var titleText = ""
    private var previewText = ""
    private val tmpRect = RectF()
    private val iconRect = Rect()

    init {
        isClickable = true
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    // ---- binding -----------------------------------------------------------------------------------------------------

    fun bind(newChat: Chat) {
        if (chat?.id != newChat.id) reset()
        chat = newChat
        layoutTexts()
        refreshAccessibility(newChat)
        invalidate()
    }

    /** Immediately return to rest with no animation (used on recycle/detach). */
    fun reset() {
        demoOpen = false
        offsetAnim.cancel()
        expandAnim.cancel()
        removeCallbacks(longPressRunnable)
        removeCallbacks(disarmRunnable)
        pendingCommit = null
        committing = false
        dragging = false
        pressedContent = false
        pressedButton = -1
        armed = null
        stage = SwipeLogic.STAGE_NONE
        offset = 0f
        expand = 0f
        restOffset = 0f
        recycleTracker()
    }

    private fun layoutTexts() {
        val c = chat ?: return
        if (width == 0) {
            titleText = c.name
            previewText = c.preview
            return
        }
        val textStart = textStart()
        val timeW = timePaint.measureText(c.time) + if (c.favorite) dp(18f) else 0f
        titleText = TextUtils.ellipsize(c.name, titlePaint, width - textStart - dp(16f) - timeW - dp(8f), TextUtils.TruncateAt.END).toString()
        previewText = TextUtils.ellipsize(c.preview, previewPaint, width - textStart - dp(16f) - trailingBadgeWidth(c), TextUtils.TruncateAt.END).toString()
    }

    private fun textStart() = dp(16f) + dp(52f) + dp(12f)

    private fun badgeLabel(c: Chat) = when {
        c.unread > 0 -> c.unread.toString()
        c.markedUnread -> ""
        else -> null
    }

    private fun badgeWidth(c: Chat): Float {
        val label = badgeLabel(c) ?: return 0f
        val h = dp(22f)
        return if (label.isEmpty()) dp(12f) else max(h, badgePaint.measureText(label) + dp(14f))
    }

    private fun trailingBadgeWidth(c: Chat): Float = when {
        badgeLabel(c) != null -> badgeWidth(c) + dp(8f)
        c.pinned -> dp(18f) + dp(8f)
        else -> 0f
    }

    private fun refreshAccessibility(c: Chat) {
        val parts = mutableListOf(c.name, c.preview, c.time)
        if (c.unread > 0) parts += "${c.unread} unread" else if (c.markedUnread) parts += "marked unread"
        if (c.pinned) parts += "pinned"
        if (c.favorite) parts += "favorite"
        if (c.muted) parts += "muted"
        contentDescription = parts.joinToString(", ")
        for (id in a11yIds) ViewCompat.removeAccessibilityAction(this, id)
        a11yIds.clear()
        val all = (SwipeConfig.visible(Side.LEADING) + SwipeConfig.visible(Side.TRAILING)).distinct()
        for (a in all) {
            a11yIds += ViewCompat.addAccessibilityAction(this, a.label(context, c)) { _, _ ->
                Haptics.confirm(this)
                listener?.onAlternativeAction(c, a)
                true
            }
        }
    }

    private val a11yIds = mutableListOf<Int>()

    // ---- layout / draw -----------------------------------------------------------------------------------------------------

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val tf = titlePaint.fontMetrics
        val pf = previewPaint.fontMetrics
        val textH = (tf.descent - tf.ascent) + (pf.descent - pf.ascent) + dp(4f)
        val h = max(dp(76f), textH + dp(26f))
        setMeasuredDimension(getDefaultSize(suggestedMinimumWidth, widthMeasureSpec), h.toInt())
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        layoutTexts()
    }

    override fun onDraw(canvas: Canvas) {
        val c = chat ?: return
        if (offset != 0f) drawActions(canvas, c)
        canvas.save()
        canvas.translate(offset, 0f)
        drawContent(canvas, c)
        canvas.restore()
    }

    private fun drawContent(canvas: Canvas, c: Chat) {
        val w = width.toFloat()
        val h = height.toFloat()
        fill.color = if (c.pinned) cPinnedBg else cRowBg
        canvas.drawRect(0f, 0f, w, h, fill)
        if (pressedContent && pressedButton < 0) {
            fill.color = cPressed
            canvas.drawRect(0f, 0f, w, h, fill)
        }

        // avatar (initials on a colour; no real photos)
        val r = dp(26f)
        val cx = dp(16f) + r
        val cy = h / 2f
        fill.color = avatarColors[c.id % avatarColors.size]
        canvas.drawCircle(cx, cy, r, fill)
        val initials = c.name.split(" ").filter { it.isNotEmpty() && it[0].isLetter() }.take(2).joinToString("") { it.take(1) }
        canvas.drawText(initials, cx, cy - (initialsPaint.ascent() + initialsPaint.descent()) / 2f, initialsPaint)

        // text
        val tf = titlePaint.fontMetrics
        val pf = previewPaint.fontMetrics
        val titleH = tf.descent - tf.ascent
        val previewH = pf.descent - pf.ascent
        val top = (h - (titleH + previewH + dp(4f))) / 2f
        val titleBase = top - tf.ascent
        val previewBase = top + titleH + dp(4f) - pf.ascent
        val ts = textStart()
        titlePaint.color = cPrimary
        canvas.drawText(titleText, ts, titleBase, titlePaint)
        previewPaint.color = cSecondary
        canvas.drawText(previewText, ts, previewBase, previewPaint)
        timePaint.color = if (c.showUnread && !c.muted) cAccent else cSecondary
        timePaint.textAlign = Paint.Align.RIGHT
        canvas.drawText(c.time, w - dp(16f), titleBase, timePaint)
        if (c.favorite) {
            val s = dp(14f).toInt()
            val right = (w - dp(16f) - timePaint.measureText(c.time) - dp(4f)).toInt()
            val mid = (titleBase + (timePaint.ascent() + timePaint.descent()) / 2f).toInt()
            starIcon.setBounds(right - s, mid - s / 2, right, mid + s / 2)
            starIcon.draw(canvas)
        }

        // unread badge / pin marker on the preview line
        val label = badgeLabel(c)
        if (label != null) {
            val bw = badgeWidth(c)
            val bh = if (label.isEmpty()) dp(12f) else dp(22f)
            val right = w - dp(16f)
            val mid = previewBase + (pf.ascent + pf.descent) / 2f
            tmpRect.set(right - bw, mid - bh / 2f, right, mid + bh / 2f)
            fill.color = if (c.muted) cBadgeMuted else cAccent
            canvas.drawRoundRect(tmpRect, bh / 2f, bh / 2f, fill)
            if (label.isNotEmpty()) {
                badgePaint.color = 0xFFFFFFFF.toInt()
                canvas.drawText(label, tmpRect.centerX(), tmpRect.centerY() - (badgePaint.ascent() + badgePaint.descent()) / 2f, badgePaint)
            }
        } else if (c.pinned) {
            val s = dp(18f).toInt()
            val right = (w - dp(16f)).toInt()
            val mid = (previewBase + (pf.ascent + pf.descent) / 2f).toInt()
            pinIcon.setBounds(right - s, mid - s / 2, right, mid + s / 2)
            pinIcon.draw(canvas)
        }

        // divider
        dividerPaint.color = cDivider
        canvas.drawRect(ts, h - 1f, w, h, dividerPaint)
    }

    private fun sideOf(o: Float) = if (o > 0f) Side.LEADING else Side.TRAILING

    private fun drawActions(canvas: Canvas, c: Chat) {
        val side = sideOf(offset)
        val actions = SwipeConfig.visible(side)
        val n = actions.size
        if (n == 0) return
        val w = width.toFloat()
        val h = height.toFloat()
        val d = abs(offset)
        val bw = d / n
        val e = expand
        canvas.save()
        if (side == Side.TRAILING) canvas.clipRect(w - d, 0f, w, h) else canvas.clipRect(0f, 0f, d, h)
        for (i in n - 1 downTo 0) {
            val a = actions[i]
            val l0: Float
            val r0: Float
            if (side == Side.TRAILING) {
                r0 = w - i * bw; l0 = r0 - bw
            } else {
                l0 = i * bw; r0 = l0 + bw
            }
            var l = l0
            var r = r0
            if (i == 0 && e > 0f) { // primary grows to swallow the others
                if (side == Side.TRAILING) l = lerp(l0, w - d, e) else r = lerp(r0, d, e)
            }
            val alpha = if (i == 0) 1f else 1f - e
            if (alpha <= 0.01f) continue
            val isArmed = armed == a
            fill.color = if (isArmed) cDeleteArmed else ContextCompat.getColor(context, a.color)
            fill.alpha = (alpha * 255).toInt()
            canvas.drawRect(l, 0f, r, h, fill)
            fill.alpha = 255
            if (pressedButton == i && pressedContent) {
                fill.color = 0x33000000
                canvas.drawRect(l, 0f, r, h, fill)
            }
            // icon position: centred in its slot; the primary icon rides the row edge while expanding
            var icx = (l0 + r0) / 2f
            if (i == 0 && e > 0f) {
                val edgeCx = if (side == Side.TRAILING) (w - d) + buttonWidth / 2f else d - buttonWidth / 2f
                icx = lerp(icx, edgeCx, e)
            }
            drawActionIcon(canvas, c, a, icx, h / 2f, if (i == 0) 1f + 0.15f * e else 1f, alpha, bw, isArmed)
        }
        canvas.restore()
    }

    private fun drawActionIcon(canvas: Canvas, c: Chat, a: SwipeAction, cx: Float, cy: Float, scale: Float, alpha: Float, slotW: Float, isArmed: Boolean) {
        val ic = icon(a.iconRes(c))
        val s = (dp(24f) * scale)
        val label = if (isArmed) context.getString(R.string.action_confirm_delete) else a.label(context, c)
        val labelFits = labelPaint.measureText(label) <= buttonWidth - dp(8f) && slotW > dp(40f)
        val lf = labelPaint.fontMetrics
        val labelH = lf.descent - lf.ascent
        val gap = dp(4f)
        val block = if (labelFits) s + gap + labelH else s
        val iconTop = cy - block / 2f
        iconRect.set((cx - s / 2f).toInt(), iconTop.toInt(), (cx + s / 2f).toInt(), (iconTop + s).toInt())
        ic.bounds = iconRect
        ic.alpha = (alpha * 255).toInt()
        ic.draw(canvas)
        if (labelFits) {
            labelPaint.alpha = (alpha * 255).toInt()
            canvas.drawText(label, cx, iconTop + s + gap - lf.ascent, labelPaint)
            labelPaint.alpha = 255
        }
    }

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    // ---- geometry helpers ----------------------------------------------------------------------------------------------

    private fun openWidth(side: Side) = SwipeConfig.visible(side).size * buttonWidth

    private fun fullAt(side: Side) = SwipeLogic.fullThreshold(openWidth(side), width.toFloat(), dp(56f))

    private fun hasFull(side: Side) = SwipeConfig.fullSwipe(side) != null

    /** Which action button is under [x] when the row rests open, or -1. */
    private fun buttonAt(x: Float): Int {
        if (offset == 0f) return -1
        val side = sideOf(offset)
        val n = SwipeConfig.visible(side).size
        if (n == 0) return -1
        val d = abs(offset)
        val bw = d / n
        return if (side == Side.TRAILING) {
            if (x < width - d) -1 else min(n - 1, ((width - x) / bw).toInt())
        } else {
            if (x > d) -1 else min(n - 1, (x / bw).toInt())
        }
    }

    // ---- touch ---------------------------------------------------------------------------------------------------------

    override fun onTouchEvent(e: MotionEvent): Boolean {
        val chat = chat ?: return super.onTouchEvent(e)
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                recycleTracker()
                velocityTracker = VelocityTracker.obtain().also { it.addMovement(e) }
                downX = e.x; downY = e.y
                longPressed = false
                listener?.onTouchDown(this)
                val wasMoving = offsetAnim.isRunning || committing
                if (wasMoving) {
                    // INTERRUPTION: catch the row mid-flight; cancel any pending commit and keep dragging from here.
                    pendingCommit = null
                    committing = false
                    offsetAnim.cancel()
                    expandAnim.cancel()
                    Haptics.grab(this)
                    beginDrag(e.x)
                } else {
                    pressedButton = buttonAt(e.x)
                    pressedContent = true
                    postDelayed(longPressRunnable, ViewConfiguration.getLongPressTimeout().toLong())
                    invalidate()
                }
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                velocityTracker?.addMovement(e)
                if (!dragging) {
                    val dx = e.x - downX
                    val dy = e.y - downY
                    if (abs(dx) > slop && abs(dx) > abs(dy)) {
                        removeCallbacks(longPressRunnable)
                        pressedContent = false
                        pressedButton = -1
                        beginDrag(e.x)
                    } else if (abs(dy) > slop) {
                        removeCallbacks(longPressRunnable)
                        pressedContent = false
                        pressedButton = -1
                        invalidate()
                    }
                } else {
                    dragTo(e.x)
                }
                return true
            }

            MotionEvent.ACTION_UP -> {
                velocityTracker?.addMovement(e)
                removeCallbacks(longPressRunnable)
                if (dragging) {
                    dragTo(e.x) // apply the final position: batched MOVEs may not have been delivered yet
                    velocityTracker?.computeCurrentVelocity(1000)
                    finishDrag(velocityTracker?.xVelocity ?: 0f)
                } else if (pressedContent && !longPressed) {
                    handleTap(chat, e.x)
                }
                pressedContent = false
                pressedButton = -1
                invalidate()
                recycleTracker()
                return true
            }

            MotionEvent.ACTION_CANCEL -> {
                // CANCELLATION: parent took over (e.g. vertical scroll) or system cancelled. Return to the prior rest state.
                removeCallbacks(longPressRunnable)
                pressedContent = false
                pressedButton = -1
                if (dragging) {
                    dragging = false
                    settleToRest()
                }
                invalidate()
                recycleTracker()
                return true
            }
        }
        return super.onTouchEvent(e)
    }

    private fun beginDrag(x: Float) {
        demoOpen = false
        dragging = true
        dragStartX = x
        dragStartOffset = offset
        restOffset = snapRest(offset)
        stage = stageFor(abs(offset), sideOf(offset), SwipeLogic.STAGE_NONE)
        parent?.requestDisallowInterceptTouchEvent(true)
        listener?.onDragStart(this)
    }

    /** The resting position nearest to [o]: closed, or fully open on that side. */
    private fun snapRest(o: Float): Float {
        if (o == 0f) return 0f
        val side = sideOf(o)
        val ow = openWidth(side)
        return if (abs(o) >= ow * 0.5f && ow > 0f) (if (o > 0) ow else -ow) else 0f
    }

    private fun stageFor(abs: Float, side: Side, prev: Int): Int {
        val ow = openWidth(side)
        if (ow <= 0f) return SwipeLogic.STAGE_NONE
        return SwipeLogic.stage(abs, prev, ow, fullAt(side), hasFull(side), dp(10f))
    }

    private fun dragTo(x: Float) {
        val target = dragStartOffset + (x - dragStartX)
        val side = if (target >= 0f) Side.LEADING else Side.TRAILING
        val n = SwipeConfig.visible(side).size
        val limit = if (n == 0) 0f else if (hasFull(side)) width * 0.92f else openWidth(side)
        val band = if (n == 0) dp(56f) else dp(44f)
        val newOffset = SwipeLogic.resist(target, limit, band)
        val prevSide = if (offset >= 0f) Side.LEADING else Side.TRAILING
        if (side != prevSide) stage = SwipeLogic.STAGE_NONE
        offset = newOffset

        val newStage = if (n == 0) SwipeLogic.STAGE_NONE else stageFor(abs(newOffset), side, stage)
        if (newStage != stage) {
            val up = newStage > stage
            when {
                newStage == SwipeLogic.STAGE_FULL -> Haptics.thresholdOn(this)
                stage == SwipeLogic.STAGE_FULL -> Haptics.thresholdOff(this)
                else -> Haptics.tick(this)
            }
            stage = newStage
            if (up || stage != SwipeLogic.STAGE_FULL) animateExpand(if (stage == SwipeLogic.STAGE_FULL) 1f else 0f)
        }
    }

    private fun finishDrag(vx: Float) {
        dragging = false
        val side = sideOf(offset)
        val ow = openWidth(side)
        val dir = if (offset >= 0f) 1f else -1f
        val decision = SwipeLogic.decide(
            absOffset = abs(offset),
            revealVelocity = vx * dir,
            openWidth = ow,
            fullAt = fullAt(side),
            hasFull = hasFull(side),
            flingVelocity = dp(900f),
        )
        when (decision) {
            SwipeLogic.Release.CLOSE -> {
                restOffset = 0f
                springOffset(0f, vx, stiffness = 650f, damping = 0.9f, clampAtZero = true)
                animateExpand(0f)
            }

            SwipeLogic.Release.OPEN -> {
                restOffset = dir * ow
                springOffset(restOffset, vx, stiffness = 520f, damping = 0.72f)
                animateExpand(0f)
                listener?.onSettledOpen(this)
            }

            SwipeLogic.Release.COMMIT -> commit(SwipeConfig.fullSwipe(side)!!, dir, vx)
        }
    }

    /** Spring back to where the row was before the interrupted gesture. */
    private fun settleToRest() {
        val target = restOffset
        if (target == 0f) {
            springOffset(0f, 0f, stiffness = 650f, damping = 0.9f, clampAtZero = true)
        } else {
            springOffset(target, 0f, stiffness = 520f, damping = 0.72f)
        }
        animateExpand(0f)
        stage = SwipeLogic.STAGE_NONE
    }

    private fun commit(action: SwipeAction, dir: Float, vx: Float) {
        Haptics.confirm(this)
        restOffset = 0f
        if (action.removesRow) {
            // Throw the row off-screen, then perform; touch-down during the slide cancels it.
            committing = true
            pendingCommit = action
            animateExpand(1f)
            springOffset(dir * width, vx, stiffness = 700f, damping = 1f, onEnd = {
                val a = pendingCommit
                pendingCommit = null
                committing = false
                val ch = chat
                if (a != null && ch != null) listener?.onAction(ch, a)
            })
        } else {
            chat?.let { listener?.onAction(it, action) }
            springOffset(0f, vx, stiffness = 420f, damping = 0.78f, clampAtZero = true)
            animateExpand(0f)
        }
    }

    /** True while the tray was opened by the tutorial; taps then only close it and never run an action. */
    var demoOpen = false
        private set

    /** Tutorial: spring the row open to reveal the real action tray on [side]. No action is executed. */
    fun demoOpen(side: Side) {
        if (SwipeConfig.visible(side).isEmpty() || dragging) return
        demoOpen = true
        restOffset = if (side == Side.LEADING) openWidth(side) else -openWidth(side)
        springOffset(restOffset, 0f, stiffness = 520f, damping = 0.72f, onEnd = { listener?.onSettledOpen(this) })
        Haptics.tick(this)
    }

    private fun handleTap(chat: Chat, x: Float) {
        if (demoOpen && abs(offset) > 1f) {
            closeAnimated()
            return
        }
        if (abs(offset) > 1f) {
            val i = buttonAt(x)
            val actions = SwipeConfig.visible(sideOf(offset))
            if (i in actions.indices) performButton(chat, actions[i]) else closeAnimated()
        } else {
            performClick()
        }
    }

    private fun performButton(chat: Chat, action: SwipeAction) {
        if (action.destructive && armed != action) {
            // Destructive actions need a second tap; the button turns dark red and relabels itself.
            armed = action
            Haptics.tick(this)
            removeCallbacks(disarmRunnable)
            postDelayed(disarmRunnable, 3000)
            invalidate()
            return
        }
        armed = null
        removeCallbacks(disarmRunnable)
        Haptics.confirm(this)
        listener?.onAction(chat, action)
        if (!action.removesRow) closeAnimated()
    }

    override fun performClick(): Boolean {
        super.performClick()
        if (abs(offset) > 1f) closeAnimated() else chat?.let { listener?.onOpenChat(it) }
        return true
    }

    /** Close (used by the host when another row opens or the list scrolls). */
    fun closeAnimated() {
        demoOpen = false
        if (offset == 0f && !offsetAnim.isRunning) return
        restOffset = 0f
        committing = false
        pendingCommit = null
        armed = null
        removeCallbacks(disarmRunnable)
        springOffset(0f, 0f, stiffness = 650f, damping = 0.9f, clampAtZero = true)
        animateExpand(0f)
    }

    val isOpenOrMoving: Boolean get() = offset != 0f

    // ---- spring helpers ----------------------------------------------------------------------------------------------------

    private fun reduceMotion(): Boolean =
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private fun springOffset(
        target: Float,
        velocity: Float,
        stiffness: Float,
        damping: Float,
        clampAtZero: Boolean = false,
        onEnd: (() -> Unit)? = null,
    ) {
        offsetAnim.cancel()
        if (reduceMotion()) {
            offset = target
            onEnd?.invoke()
            return
        }
        // never swing through zero into the opposite side's actions
        offsetAnim.setMinValue(if (clampAtZero && offset > 0f) 0f else -Float.MAX_VALUE)
        offsetAnim.setMaxValue(if (clampAtZero && offset < 0f) 0f else Float.MAX_VALUE)
        offsetAnim.setStartVelocity(velocity)
        offsetAnim.spring = SpringForce(target).setStiffness(stiffness).setDampingRatio(damping)
        offsetAnim.removeEndListener(endListener)
        endCallback = onEnd
        offsetAnim.addEndListener(endListener)
        offsetAnim.start()
    }

    private var endCallback: (() -> Unit)? = null
    private val endListener = DynamicAnimation.OnAnimationEndListener { _, canceled, _, _ ->
        val cb = endCallback
        endCallback = null
        if (!canceled) cb?.invoke()
    }

    private fun animateExpand(target: Float) {
        expandAnim.cancel()
        if (reduceMotion()) {
            expand = target
            return
        }
        expandAnim.spring = SpringForce(target * 1000f).setStiffness(700f).setDampingRatio(0.6f)
        expandAnim.setMinValue(0f)
        expandAnim.setMaxValue(1100f)
        expandAnim.start()
    }

    private fun recycleTracker() {
        velocityTracker?.recycle()
        velocityTracker = null
    }
}
