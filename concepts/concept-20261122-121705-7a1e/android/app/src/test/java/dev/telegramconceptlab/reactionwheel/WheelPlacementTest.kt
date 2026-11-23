package dev.telegramconceptlab.reactionwheel

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.abs

class WheelPlacementTest {
    private val phone = SafeBounds(0f, 59f, 390f, 810f)

    @Test fun midScreenUsesUpWithSpecifiedOrder() {
        val p = requireNotNull(WheelGeometry.compute(phone,195f,500f,1f,false))
        assertEquals(0,p.axisDegrees); assertEquals(195f,p.centerX,.01f)
        assertTrue(p.centers.first().first < p.centers.last().first)
    }
    @Test fun leftEdgeUsesRightAndShiftsWholeWheel() {
        val p = requireNotNull(WheelGeometry.compute(phone,20f,500f,1f,false))
        assertEquals(90,p.axisDegrees); assertEquals(42f,p.centerX,1f)
        assertTrue(p.centers.last().second > p.centers.first().second)
    }
    @Test fun downAxisStillStartsOnLeft() {
        val p = requireNotNull(WheelGeometry.compute(phone,195f,110f,1f,false))
        assertEquals(180,p.axisDegrees)
        assertTrue(p.centers.first().first < p.centers.last().first)
    }
    @Test fun rtlMirrorsHorizontalOrder() {
        val ltr = WheelGeometry.centers(0f,0f,0,108f,false)
        val rtl = WheelGeometry.centers(0f,0f,0,108f,true)
        assertTrue(ltr.first().first < ltr.last().first); assertTrue(rtl.first().first > rtl.last().first)
    }
    @Test fun narrowWindowFallsBackToCompact() {
        assertNull(WheelGeometry.compute(SafeBounds(0f,0f,240f,800f),120f,400f,1.3f,false))
    }
}
