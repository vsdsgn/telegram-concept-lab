package lab.telegramconcept.multiswipe

import kotlin.math.abs

/** Pure gesture maths, kept free of Android types so it can be unit-tested on the JVM. */
object SwipeLogic {
    enum class Release { CLOSE, OPEN, COMMIT }

    /** 0 = below the open threshold, 1 = release would leave the row open, 2 = release would commit the primary action. */
    const val STAGE_NONE = 0
    const val STAGE_OPEN = 1
    const val STAGE_FULL = 2

    /** Diminishing-returns drag: asymptotically approaches [dim]. */
    fun rubberBand(x: Float, dim: Float, c: Float = 0.55f): Float {
        if (x <= 0f) return 0f
        return (1f - 1f / (x * c / dim + 1f)) * dim
    }

    /**
     * Maps the raw finger offset to the visual row offset.
     * Linear while the row reveals actions; rubber-banded where there is nothing to reveal.
     * @param revealLimit offset up to which movement is 1:1 (0 when this side has no actions)
     */
    fun resist(target: Float, revealLimit: Float, bandDim: Float): Float {
        val t = abs(target)
        val out = if (t <= revealLimit) t else revealLimit + rubberBand(t - revealLimit, bandDim)
        return if (target < 0f) -out else out
    }

    fun openThreshold(openWidth: Float) = openWidth * 0.5f

    /** Distance at which a full swipe commits the primary action. */
    fun fullThreshold(openWidth: Float, rowWidth: Float, extra: Float): Float =
        minOf(maxOf(openWidth + extra, rowWidth * 0.62f), rowWidth * 0.8f)

    /** Stage with hysteresis so the haptic doesn't chatter on the threshold. */
    fun stage(absOffset: Float, previous: Int, openWidth: Float, fullAt: Float, hasFull: Boolean, hysteresis: Float): Int {
        val openAt = openThreshold(openWidth)
        val up = when {
            hasFull && absOffset >= fullAt -> STAGE_FULL
            absOffset >= openAt -> STAGE_OPEN
            else -> STAGE_NONE
        }
        if (up >= previous) return up
        // going down: require extra distance
        return when (previous) {
            STAGE_FULL -> if (absOffset < fullAt - hysteresis) (if (absOffset >= openAt) STAGE_OPEN else STAGE_NONE) else STAGE_FULL
            STAGE_OPEN -> if (absOffset < openAt - hysteresis) STAGE_NONE else STAGE_OPEN
            else -> up
        }
    }

    /**
     * What happens when the finger lifts.
     * @param revealVelocity px/s, positive when moving in the revealing direction
     */
    fun decide(
        absOffset: Float,
        revealVelocity: Float,
        openWidth: Float,
        fullAt: Float,
        hasFull: Boolean,
        flingVelocity: Float,
    ): Release = when {
        absOffset <= 0f || openWidth <= 0f -> Release.CLOSE
        hasFull && absOffset >= fullAt -> Release.COMMIT
        hasFull && revealVelocity > flingVelocity * 3f && absOffset > openWidth * 0.8f -> Release.COMMIT
        revealVelocity > flingVelocity && absOffset > openWidth * 0.15f -> Release.OPEN
        revealVelocity < -flingVelocity -> Release.CLOSE
        absOffset >= openThreshold(openWidth) -> Release.OPEN
        else -> Release.CLOSE
    }
}
