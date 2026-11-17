package lab.telegramconcept.multiswipe

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View

/** Thin wrapper over View.performHapticFeedback, honouring the in-app toggle and the system touch-feedback setting. */
object Haptics {
    /** Light tick: open threshold crossed (either direction). */
    fun tick(v: View) = perform(v, HapticFeedbackConstants.CLOCK_TICK)

    /** Full-swipe threshold crossed upward. */
    fun thresholdOn(v: View) = perform(
        v,
        if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE else HapticFeedbackConstants.VIRTUAL_KEY,
    )

    /** Full-swipe threshold crossed back downward. */
    fun thresholdOff(v: View) = perform(
        v,
        if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.GESTURE_THRESHOLD_DEACTIVATE else HapticFeedbackConstants.CLOCK_TICK,
    )

    /** Grabbing a row that is still moving. */
    fun grab(v: View) = perform(
        v,
        if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.GESTURE_START else HapticFeedbackConstants.CLOCK_TICK,
    )

    /** An action was performed. */
    fun confirm(v: View) = perform(
        v,
        if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS,
    )

    fun longPress(v: View) = perform(v, HapticFeedbackConstants.LONG_PRESS)

    private fun perform(v: View, constant: Int) {
        if (SwipeConfig.haptics) v.performHapticFeedback(constant)
    }
}
