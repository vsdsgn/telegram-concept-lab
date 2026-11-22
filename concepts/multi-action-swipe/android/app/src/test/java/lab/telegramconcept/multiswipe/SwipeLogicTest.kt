package lab.telegramconcept.multiswipe

import lab.telegramconcept.multiswipe.SwipeLogic.Release
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SwipeLogicTest {
    private val open = 228f
    private val full = 284f
    private val fling = 900f

    private fun decide(offset: Float, v: Float, hasFull: Boolean = true) =
        SwipeLogic.decide(offset, v, open, full, hasFull, fling)

    @Test fun rubberBandIsMonotonicAndBounded() {
        var prev = 0f
        for (x in listOf(1f, 10f, 100f, 1000f, 100000f)) {
            val y = SwipeLogic.rubberBand(x, 50f)
            assertTrue(y > prev && y < 50f)
            prev = y
        }
        assertEquals(0f, SwipeLogic.rubberBand(0f, 50f), 0f)
        assertEquals(0f, SwipeLogic.rubberBand(-5f, 50f), 0f)
    }

    @Test fun resistIsLinearInsideLimitAndSigned() {
        assertEquals(-100f, SwipeLogic.resist(-100f, 300f, 40f), 0.001f)
        assertEquals(100f, SwipeLogic.resist(100f, 300f, 40f), 0.001f)
        val beyond = SwipeLogic.resist(-600f, 300f, 40f)
        assertTrue(beyond < -300f && beyond > -340f)
    }

    @Test fun sideWithoutActionsOnlyRubberBands() {
        val v = SwipeLogic.resist(500f, 0f, 56f)
        assertTrue(v > 0f && v < 56f)
    }

    @Test fun releaseDecisions() {
        assertEquals(Release.CLOSE, decide(40f, 0f))
        assertEquals(Release.OPEN, decide(130f, 0f))
        assertEquals(Release.OPEN, decide(250f, 0f)) // past open width, below full
        assertEquals(Release.COMMIT, decide(300f, 0f))
        assertEquals(Release.COMMIT, decide(300f, 0f)) // beyond full threshold
        assertEquals(Release.CLOSE, decide(200f, -1200f)) // fast flick back closes
        assertEquals(Release.OPEN, decide(60f, 1200f)) // fast flick forward opens
        assertEquals(Release.COMMIT, decide(240f, 3000f)) // very fast flick commits
        assertEquals(Release.OPEN, decide(300f, 0f, hasFull = false)) // no full swipe: never commits
        assertEquals(Release.CLOSE, decide(0f, 5000f))
    }

    @Test fun stageHasHysteresis() {
        val h = 10f
        assertEquals(SwipeLogic.STAGE_NONE, SwipeLogic.stage(50f, 0, open, full, true, h))
        assertEquals(SwipeLogic.STAGE_OPEN, SwipeLogic.stage(120f, 0, open, full, true, h))
        assertEquals(SwipeLogic.STAGE_FULL, SwipeLogic.stage(290f, 1, open, full, true, h))
        // just under the full threshold stays FULL until 10px below
        assertEquals(SwipeLogic.STAGE_FULL, SwipeLogic.stage(280f, 2, open, full, true, h))
        assertEquals(SwipeLogic.STAGE_OPEN, SwipeLogic.stage(270f, 2, open, full, true, h))
        // without a full action the stage never reaches FULL
        assertEquals(SwipeLogic.STAGE_OPEN, SwipeLogic.stage(500f, 0, open, full, false, h))
    }

    @Test fun fullThresholdIsBounded() {
        val t = SwipeLogic.fullThreshold(228f, 1000f, 56f)
        assertTrue(t >= 620f && t <= 800f)
    }
}
