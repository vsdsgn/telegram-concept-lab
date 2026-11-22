package dev.telegramconceptlab.reactionwheel

import org.junit.Assert.*
import org.junit.Test

class WheelStateMachineTest {
    private val centers = listOf(0f to -108f, 64f to -87f, 103f to -33f, 103f to 33f, 64f to 87f, 0f to 108f)

    @Test fun smallAndDiagonalDriftNeverSelects() {
        val s=WheelStateMachine();s.open();s.move(0f,0f,21f,-21f,centers)
        assertEquals(WheelStateMachine.State.ARMED,s.state);assertNull(s.release(0f,0f,21f,-21f,centers))
    }
    @Test fun capturesAndCommitsNearestItem() {
        val s=WheelStateMachine();s.open();s.move(0f,0f,0f,-60f,centers)
        assertEquals(0,s.selected);assertEquals(0,s.release(0f,0f,0f,-60f,centers))
    }
    @Test fun returningInsideExitDeadZoneCancels() {
        val s=WheelStateMachine();s.open();s.move(0f,0f,0f,-60f,centers);s.move(0f,0f,0f,-31f,centers)
        assertEquals(-1,s.selected);assertNull(s.release(0f,0f,0f,-31f,centers))
    }
    @Test fun outsideCaptureCancels() {
        val s=WheelStateMachine();s.open();s.move(0f,0f,250f,250f,centers)
        assertEquals(WheelStateMachine.State.OUTSIDE,s.state);assertNull(s.release(0f,0f,250f,250f,centers))
    }
    @Test fun cancelIsIdempotent() { val s=WheelStateMachine();s.open();s.cancel();s.cancel();assertEquals(WheelStateMachine.State.IDLE,s.state) }
    @Test fun releaseCannotCreateASelection() {
        val s=WheelStateMachine();s.open()
        assertNull(s.release(0f,0f,0f,-60f,centers))
    }
    @Test fun releaseOutsideVisibleSelectionCancels() {
        val s=WheelStateMachine();s.open();s.move(0f,0f,0f,-60f,centers)
        assertNull(s.release(0f,0f,250f,250f,centers))
    }
}
