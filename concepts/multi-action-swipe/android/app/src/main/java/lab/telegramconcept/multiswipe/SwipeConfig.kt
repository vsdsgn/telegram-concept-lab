package lab.telegramconcept.multiswipe

import android.content.Context
import android.content.SharedPreferences

enum class Side { LEADING, TRAILING }

/** User-configurable swipe layout, persisted in SharedPreferences. Local only. */
object SwipeConfig {
    const val MAX_PER_SIDE = 3
    private const val PREFS = "swipe_config"

    private lateinit var prefs: SharedPreferences
    private lateinit var appContext: Context
    private val order = mutableMapOf<Side, MutableList<SwipeAction>>()
    private val enabled = mutableMapOf<Side, MutableSet<SwipeAction>>()
    var haptics: Boolean = true
        private set

    private val defaultOrder = mapOf(
        Side.LEADING to listOf(SwipeAction.READ, SwipeAction.PIN, SwipeAction.FAVORITE, SwipeAction.MUTE, SwipeAction.ARCHIVE, SwipeAction.DELETE),
        Side.TRAILING to listOf(SwipeAction.ARCHIVE, SwipeAction.MUTE, SwipeAction.DELETE, SwipeAction.PIN, SwipeAction.READ, SwipeAction.FAVORITE),
    )
    private val defaultEnabled = mapOf(
        Side.LEADING to setOf(SwipeAction.READ, SwipeAction.PIN, SwipeAction.FAVORITE),
        Side.TRAILING to setOf(SwipeAction.ARCHIVE, SwipeAction.MUTE, SwipeAction.DELETE),
    )

    fun init(context: Context) {
        appContext = context.applicationContext
        prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        haptics = prefs.getBoolean("haptics", true)
        for (side in Side.entries) {
            val saved = prefs.getString("order_$side", null)?.split(",")?.mapNotNull { SwipeAction.fromId(it) }.orEmpty()
            val full = (saved + defaultOrder.getValue(side)).distinct()
            order[side] = full.toMutableList()
            val en = prefs.getString("enabled_$side", null)
            enabled[side] = if (en == null) defaultEnabled.getValue(side).toMutableSet()
            else en.split(",").mapNotNull { SwipeAction.fromId(it) }.take(MAX_PER_SIDE).toMutableSet()
        }
    }

    /** All actions in user order (enabled or not) – for the settings screen. */
    fun order(side: Side): List<SwipeAction> = order.getValue(side)

    fun isEnabled(side: Side, action: SwipeAction) = action in enabled.getValue(side)

    /** Actions shown when swiping, outermost (primary) first. */
    fun visible(side: Side): List<SwipeAction> = order(side).filter { isEnabled(side, it) }

    /** The action a full swipe commits, or null. Destructive actions are never full-swipe actions. */
    fun fullSwipe(side: Side): SwipeAction? = visible(side).firstOrNull()?.takeIf { !it.destructive }

    /** @return false when enabling would exceed [MAX_PER_SIDE]. */
    fun setEnabled(side: Side, action: SwipeAction, on: Boolean): Boolean {
        val set = enabled.getValue(side)
        if (on) {
            if (action !in set && set.size >= MAX_PER_SIDE) return false
            set.add(action)
        } else set.remove(action)
        save()
        return true
    }

    fun move(side: Side, action: SwipeAction, delta: Int) {
        val list = order.getValue(side)
        val from = list.indexOf(action)
        val to = (from + delta).coerceIn(0, list.lastIndex)
        if (from < 0 || from == to) return
        list.removeAt(from)
        list.add(to, action)
        save()
    }

    fun setHaptics(on: Boolean) {
        haptics = on
        prefs.edit().putBoolean("haptics", on).apply()
    }

    fun reset() {
        prefs.edit().clear().apply()
        init(appContext)
    }

    private fun save() {
        val e = prefs.edit()
        for (side in Side.entries) {
            e.putString("order_$side", order.getValue(side).joinToString(",") { it.id })
            e.putString("enabled_$side", enabled.getValue(side).joinToString(",") { it.id })
        }
        e.apply()
    }
}
