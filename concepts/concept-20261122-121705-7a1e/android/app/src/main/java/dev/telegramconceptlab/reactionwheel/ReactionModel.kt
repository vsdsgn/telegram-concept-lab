package dev.telegramconceptlab.reactionwheel

import kotlin.math.hypot

data class Reaction(val glyph: String, val en: String, val ru: String)

object Reactions {
    val all = listOf(Reaction("👍", "Like", "Нравится"), Reaction("❤️", "Love", "Люблю"), Reaction("😂", "Laugh", "Смешно"), Reaction("😮", "Wow", "Ого"), Reaction("😢", "Sad", "Грустно"), Reaction("🔥", "Fire", "Огонь"))
}

class WheelStateMachine {
    enum class State { IDLE, ARMED, SELECTED, OUTSIDE }
    var state = State.IDLE; private set
    var selected = -1; private set
    fun open() { state = State.ARMED; selected = -1 }
    fun move(anchorX: Float, anchorY: Float, x: Float, y: Float, centers: List<Pair<Float, Float>>) {
        val rho = hypot(x - anchorX, y - anchorY)
        if (rho < 32f) { state = State.ARMED; selected = -1; return }
        if (selected < 0 && rho < 44f) { state = State.ARMED; return }
        val distances = centers.map { hypot(x - it.first, y - it.second) }
        val nearest = distances.indices.minByOrNull { distances[it] } ?: -1
        if (selected >= 0 && distances[selected] <= 96f && (nearest == selected || distances[nearest] + 8f >= distances[selected])) return
        if (nearest >= 0 && distances[nearest] <= 80f && rho >= 44f) { selected = nearest; state = State.SELECTED }
        else { selected = -1; state = if (rho >= 12f) State.OUTSIDE else State.ARMED }
    }
    fun release(anchorX: Float, anchorY: Float, x: Float, y: Float, centers: List<Pair<Float, Float>>): Int? {
        // Release may validate the visible selection, but must never create a new one.
        // Otherwise a slightly different UP coordinate can commit an item the user never saw.
        val result = selected.takeIf { state == State.SELECTED && hypot(x-anchorX,y-anchorY) >= 32f && hypot(x-centers[it].first,y-centers[it].second) <= 96f }
        state = State.IDLE; selected = -1
        return result
    }
    fun cancel() { state = State.IDLE; selected = -1 }
}
