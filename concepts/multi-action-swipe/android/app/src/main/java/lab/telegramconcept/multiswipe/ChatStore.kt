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

object MockData {
    fun chats(): List<Chat> = listOf(
        Chat(1, "Mira Volkova", "Sent the updated prototype link, tell me what you think", "17:42", unread = 3),
        Chat(2, "Product Sync (mock group)", "Noor: Let's move the review to Thursday", "17:10", unread = 12, muted = true),
        Chat(3, "Weekend Hike", "Photos from the ridge are up in the album", "16:58"),
        Chat(4, "Leo Brandt", "Typing the notes now, 5 minutes", "16:31", unread = 1),
        Chat(5, "Design Crit Club", "Sana: The empty state needs a clearer next step", "15:47", muted = true),
        Chat(6, "Ivy Okafor", "Thanks! That fixed it", "15:02"),
        Chat(7, "Build Alerts (mock bot)", "Pipeline #482 passed in 4m 12s", "14:20", unread = 27, muted = true),
        Chat(8, "Kasper Lindqvist", "Voice message (0:48)", "13:55", unread = 1),
        Chat(9, "Family (mock)", "Dinner at 7?", "12:34"),
        Chat(10, "Tomas Reyes", "I'll send the invoice tomorrow morning", "11:19"),
        Chat(11, "Reading Circle", "This month: a short story collection", "10:05", unread = 4),
        Chat(12, "Anya Petrova", "Ok, see you then", "09:48"),
        Chat(13, "Studio Notes", "You: Draft is in the shared folder", "Tue"),
        Chat(14, "Hugo Martins", "Haha, exactly", "Tue", unread = 2),
        Chat(15, "Pixel Lab (mock group)", "Emre: New icons exported", "Mon"),
        Chat(16, "Dara Cohen", "Can you review the schedule?", "Mon"),
        Chat(17, "Garden Swap", "Seedlings available this weekend", "Sun", muted = true),
        Chat(18, "Jun Watanabe", "Great, talk soon", "Sun"),
        Chat(19, "Coffee Run", "Who's in for Friday?", "Sat", unread = 6),
        Chat(20, "Rina Sato", "Sticker pack idea attached", "Sat"),
        Chat(21, "Orla Finch", "Do you still have the cable?", "Fri"),
        Chat(22, "Mock Support Desk", "Your request was closed", "Fri"),
        Chat(23, "Felix Aaltonen", "Let me check and get back", "Thu"),
        Chat(24, "Run Club", "Route for Sunday posted", "Thu", unread = 9, muted = true),
    ).mapIndexed { i, c -> if (i == 8) c.copy(pinned = true) else if (i == 2) c.copy(pinned = true) else c }
}
