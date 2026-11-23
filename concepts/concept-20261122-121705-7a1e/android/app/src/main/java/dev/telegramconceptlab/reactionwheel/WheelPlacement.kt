package dev.telegramconceptlab.reactionwheel

import kotlin.math.*

data class SafeBounds(val left: Float, val top: Float, val right: Float, val bottom: Float)
data class WheelPlacement(val centerX: Float, val centerY: Float, val axisDegrees: Int, val centers: List<Pair<Float, Float>>)

object WheelGeometry {
    private val axes = listOf(0, 180, 90, 270, 135, 225, 45, 315)

    fun centers(cx: Float, cy: Float, axisDegrees: Int, radius: Float, rtl: Boolean): List<Pair<Float, Float>> {
        fun withSigma(sigma: Int) = List(6) { i ->
            val phi = -90.0 + 36.0 * i
            val theta = Math.toRadians(axisDegrees + sigma * phi)
            cx + sin(theta).toFloat() * radius to cy - cos(theta).toFloat() * radius
        }
        val plus = withSigma(1)
        val horizontalOrder = axisDegrees != 90 && axisDegrees != 270
        val plusMatches = if (horizontalOrder) (plus.last().first > plus.first().first) != rtl
            else plus.last().second > plus.first().second
        return if (plusMatches) plus else withSigma(-1)
    }

    fun compute(bounds: SafeBounds, anchorX: Float, anchorY: Float, uiScale: Float, rtl: Boolean): WheelPlacement? {
        val radius = 108f * uiScale
        val inset = ceil(8f + 0.5f * 1.4f * 48f * uiScale)
        val candidates = axes.mapNotNull { axis ->
            val offsets = centers(0f, 0f, axis, radius, rtl)
            val minX = offsets.minOf { it.first }; val maxX = offsets.maxOf { it.first }
            val minY = offsets.minOf { it.second }; val maxY = offsets.maxOf { it.second }
            val loX = bounds.left + inset - minX; val hiX = bounds.right - inset - maxX
            val loY = bounds.top + inset - minY; val hiY = bounds.bottom - inset - maxY
            if (loX > hiX || loY > hiY) return@mapNotNull null
            val cx = anchorX.coerceIn(loX, hiX); val cy = anchorY.coerceIn(loY, hiY)
            val shift = hypot(cx - anchorX, cy - anchorY)
            if (shift > 120f) return@mapNotNull null
            val points = centers(cx, cy, axis, radius, rtl)
            if (points.minOf { hypot(it.first - anchorX, it.second - anchorY) } < 96f) return@mapNotNull null
            Triple(shift, axis, WheelPlacement(cx, cy, axis, points))
        }
        return candidates.firstOrNull { it.first <= 24f }?.third
            ?: candidates.minByOrNull { it.first }?.third
    }
}
