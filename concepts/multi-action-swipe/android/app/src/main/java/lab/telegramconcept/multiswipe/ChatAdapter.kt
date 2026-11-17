package lab.telegramconcept.multiswipe

import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView

class ChatAdapter(private val listener: ChatRowView.Listener) :
    ListAdapter<Chat, ChatAdapter.VH>(DIFF) {

    class VH(val row: ChatRowView) : RecyclerView.ViewHolder(row)

    override fun getItemId(position: Int) = getItem(position).id.toLong()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val row = ChatRowView(parent.context)
        row.layoutParams = RecyclerView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        row.listener = listener
        return VH(row)
    }

    override fun onBindViewHolder(holder: VH, position: Int) = holder.row.bind(getItem(position))

    override fun onViewDetachedFromWindow(holder: VH) = holder.row.reset()

    private companion object {
        val DIFF = object : DiffUtil.ItemCallback<Chat>() {
            override fun areItemsTheSame(a: Chat, b: Chat) = a.id == b.id
            override fun areContentsTheSame(a: Chat, b: Chat) = a == b
        }
    }
}
