package lab.telegramconcept.multiswipe

/** A chat row. All instances come from [MockData]; nothing here is real Telegram data. */
data class Chat(
    val id: Int,
    val name: String,
    val preview: String,
    val time: String,
    val unread: Int = 0,
    val markedUnread: Boolean = false,
    val pinned: Boolean = false,
    val muted: Boolean = false,
    val archived: Boolean = false,
    val deleted: Boolean = false,
) {
    val showUnread: Boolean get() = unread > 0 || markedUnread
}
