package com.jikuai.gdust_lite

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/**
 * 2×2 Compact 小组件的 ListView 数据服务
 */
class WidgetCompactStackService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CompactListFactory(applicationContext)
    }

    private class CompactListFactory(private val context: Context) : RemoteViewsFactory {
        private data class Item(val time: String, val name: String, val room: String)
        private val items = mutableListOf<Item>()

        override fun onCreate() {}
        override fun onDestroy() { items.clear() }
        override fun getCount() = items.size
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = true
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1

        override fun onDataSetChanged() {
            items.clear()
            items.addAll(WidgetDataProvider.loadRemainingCourseItems(context).map { Item(it.first, it.second, it.third) })
        }

        override fun getViewAt(position: Int): RemoteViews {
            val item = items[position]
            val views = RemoteViews(context.packageName, R.layout.widget_compact_list_item)
            views.setTextViewText(R.id.compact_item_time, item.time)
            views.setTextViewText(R.id.compact_item_name, item.name)
            views.setTextViewText(R.id.compact_item_room, item.room)
            return views
        }
    }
}
