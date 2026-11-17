package lab.telegramconcept.multiswipe

/** In-memory store seeded with clearly fake chats. Resets when the process dies. */
object ChatStore {
    private var chats: List<Chat> = MockData.chats()

    /** Pinned first, then the original (recency) order. */
    fun visible(): List<Chat> = chats.filter { !it.archived && !it.deleted }.sortedByDescending { it.pinned }

    fun find(id: Int): Chat? = chats.firstOrNull { it.id == id }

    fun apply(action: SwipeAction, id: Int) {
        replace(id) { c ->
            when (action) {
                SwipeAction.PIN -> c.copy(pinned = !c.pinned)
                SwipeAction.READ -> if (c.showUnread) c.copy(unread = 0, markedUnread = false) else c.copy(markedUnread = true)
                SwipeAction.FAVORITE -> c.copy(favorite = !c.favorite)
                SwipeAction.MUTE -> c.copy(muted = !c.muted)
                SwipeAction.ARCHIVE -> c.copy(archived = true)
                SwipeAction.DELETE -> c.copy(deleted = true)
            }
        }
    }

    fun restore(previous: Chat) = replace(previous.id) { previous }

    fun reset() {
        chats = MockData.chats()
    }

    private fun replace(id: Int, transform: (Chat) -> Chat) {
        chats = chats.map { if (it.id == id) transform(it) else it }
    }
}

/** Shared seeded fixtures: the same six chats, order and state as the iOS concept (see SPEC / docs/UX_REVIEW.md). */
object MockData {
    fun chats(): List<Chat> = listOf(
        Chat(1, "Maya Chen", "The interaction prototype is ready to review.", "10:42", unread = 2, pinned = true),
        Chat(2, "Product Sync", "Noor: Let's move the review to Thursday.", "09:40", unread = 3, muted = true),
        Chat(3, "Weekend Plans", "Priya: Train leaves at 08:15.", "Yesterday", unread = 8),
        Chat(4, "Design Critique", "Jon: I like the third spring option best.", "Yesterday", unread = 5, favorite = true),
        Chat(5, "Ava Thompson", "Sent a photo", "Mon"),
        Chat(6, "Build Alerts", "Release build is green on the emulator.", "Sun", unread = 12, muted = true),
    )
}
