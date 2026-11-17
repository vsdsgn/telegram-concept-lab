package lab.telegramconcept.multiswipe

import android.content.Context
import androidx.annotation.ColorRes
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes

/**
 * The pool of actions a user can put on either swipe side.
 * [destructive] actions are never triggered by a full swipe and need a second tap to confirm.
 * [removesRow] actions take the row out of the list (so the row slides off instead of springing back).
 */
enum class SwipeAction(
    val id: String,
    @param:StringRes val poolLabel: Int,
    @param:ColorRes val color: Int,
    val destructive: Boolean = false,
    val removesRow: Boolean = false,
) {
    PIN("pin", R.string.pool_pin, R.color.action_pin),
    READ("read", R.string.pool_read, R.color.action_read),
    FAVORITE("favorite", R.string.pool_favorite, R.color.action_favorite),
    MUTE("mute", R.string.pool_mute, R.color.action_mute),
    ARCHIVE("archive", R.string.pool_archive, R.color.action_archive, removesRow = true),
    DELETE("delete", R.string.pool_delete, R.color.action_delete, destructive = true, removesRow = true);

    @StringRes
    fun labelRes(chat: Chat): Int = when (this) {
        PIN -> if (chat.pinned) R.string.action_unpin else R.string.action_pin
        READ -> if (chat.showUnread) R.string.action_read else R.string.action_unread
        FAVORITE -> if (chat.favorite) R.string.action_unfavorite else R.string.action_favorite
        MUTE -> if (chat.muted) R.string.action_unmute else R.string.action_mute
        ARCHIVE -> R.string.action_archive
        DELETE -> R.string.action_delete
    }

    fun label(context: Context, chat: Chat): String = context.getString(labelRes(chat))

    @DrawableRes
    fun iconRes(chat: Chat): Int = when (this) {
        PIN -> R.drawable.ic_pin
        READ -> if (chat.showUnread) R.drawable.ic_read else R.drawable.ic_unread
        FAVORITE -> R.drawable.ic_star
        MUTE -> if (chat.muted) R.drawable.ic_unmute else R.drawable.ic_mute
        ARCHIVE -> R.drawable.ic_archive
        DELETE -> R.drawable.ic_delete
    }

    companion object {
        fun fromId(id: String): SwipeAction? = entries.firstOrNull { it.id == id }
    }
}
