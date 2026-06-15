package com.jikuai.gdust_lite

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/**
 * 4×2 Medium 小组件的 ListView 数据服务
 */
class WidgetMediumListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MediumListFactory(applicationContext)
    }

    private class MediumListFactory(private val context: Context) : RemoteViewsFactory {
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
            items.addAll(WidgetDataProvider.loadCourseItems(context).map { Item(it.first, it.second, it.third) })
        }

        override fun getViewAt(position: Int): RemoteViews {
            val item = items[position]
            val views = RemoteViews(context.packageName, R.layout.widget_medium_list_item)
            views.setTextViewText(R.id.list_item_time, "⏰ ${item.time}")
            views.setTextViewText(R.id.list_item_name, item.name)
            views.setTextViewText(R.id.list_item_room, "📍 ${item.room}")
            val fillInIntent = Intent()
            views.setOnClickFillInIntent(R.id.list_item_name, fillInIntent)
            return views
        }
    }
}
