package com.jikuai.gdust_lite

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * 共享的小组件数据更新逻辑，支持 2 种尺寸：
 * - compact (2×2): 下一节课（StackView 可滑动）
 * - medium  (4×2): 今日课表（ListView 可滑动）
 */
object WidgetDataProvider {

    data class CourseInfo(
        val name: String,
        val section: Int,
        val room: String
    )

    fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        layoutId: Int,
        size: String
    ) {
        val views = RemoteViews(context.packageName, layoutId)

        // 点击打开 App
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (size == "medium") {
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        } else {
            views.setOnClickPendingIntent(android.R.id.background, pendingIntent)
        }

        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val timetableJson = prefs.getString("timetable_json", null)

            if (timetableJson != null) {
                val data = JSONObject(timetableJson)
                val week1MondayStr = prefs.getString("week1_monday", null)
                val week1Monday = parseWeek1Monday(week1MondayStr)
                val now = Calendar.getInstance()
                val diff = ((now.timeInMillis - week1Monday!!.time) / (1000 * 60 * 60 * 24)).toInt()
                val currentWeek = (diff / 7 + 1).coerceIn(1, 20)
                val weekday = getWeekday(now)
                val dayName = getDayName(weekday)
                val courses = findTodayCourses(data, currentWeek, weekday, now)

                when (size) {
                    "compact" -> updateCompact(context, views, appWidgetId, dayName, currentWeek, courses)
                    "medium" -> updateMedium(context, views, appWidgetId, dayName, currentWeek, courses)
                }
            } else {
                when (size) {
                    "compact" -> {
                        views.setTextViewText(R.id.widget_compact_weekday, "课表")
                        views.setViewVisibility(R.id.widget_compact_empty, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_compact_list, View.GONE)
                    }
                    "medium" -> {
                        views.setTextViewText(R.id.widget_title, "今日课表")
                        views.setTextViewText(R.id.widget_week, "")
                        views.setViewVisibility(R.id.widget_medium_empty, View.VISIBLE)
                        views.setTextViewText(R.id.widget_medium_empty, "请先导入课表数据 📥")
                        views.setViewVisibility(R.id.widget_medium_list, View.GONE)
                    }
                }
            }
        } catch (e: Exception) {
            when (size) {
                "compact" -> {
                    views.setTextViewText(R.id.widget_compact_weekday, "课表")
                    views.setViewVisibility(R.id.widget_compact_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_compact_list, View.GONE)
                }
                "medium" -> {
                    views.setTextViewText(R.id.widget_title, "今日课表")
                    views.setTextViewText(R.id.widget_week, "")
                    views.setViewVisibility(R.id.widget_medium_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_medium_empty, "数据加载失败")
                    views.setViewVisibility(R.id.widget_medium_list, View.GONE)
                }
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // ==================== Compact 2×2 (StackView) ====================
    private fun updateCompact(
        context: Context, views: RemoteViews, appWidgetId: Int,
        dayName: String, currentWeek: Int, courses: List<CourseInfo>
    ) {
        views.setTextViewText(R.id.widget_compact_weekday, "第${currentWeek}周 · $dayName")
        val remaining = getRemainingCourses(courses)

        if (remaining.isEmpty()) {
            views.setViewVisibility(R.id.widget_compact_list, View.GONE)
            views.setViewVisibility(R.id.widget_compact_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_compact_list, View.VISIBLE)
            views.setViewVisibility(R.id.widget_compact_empty, View.GONE)

            val svcIntent = Intent(context, WidgetCompactStackService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_compact_list, svcIntent)
            views.setEmptyView(R.id.widget_compact_list, R.id.widget_compact_empty)
        }
    }

    // ==================== Medium 4×2 (ListView) ====================
    private fun updateMedium(
        context: Context, views: RemoteViews, appWidgetId: Int,
        dayName: String, currentWeek: Int, courses: List<CourseInfo>
    ) {
        val now = Calendar.getInstance()
        val month = now.get(Calendar.MONTH) + 1
        val day = now.get(Calendar.DAY_OF_MONTH)
        views.setTextViewText(R.id.widget_title, "今日课表 · $dayName $month/$day")
        views.setTextViewText(R.id.widget_week, "第${currentWeek}周")

        if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_medium_list, View.GONE)
            views.setViewVisibility(R.id.widget_medium_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_medium_list, View.VISIBLE)
            views.setViewVisibility(R.id.widget_medium_empty, View.GONE)

            val svcIntent = Intent(context, WidgetMediumListService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_medium_list, svcIntent)
            views.setEmptyView(R.id.widget_medium_list, R.id.widget_medium_empty)
        }
    }

    // ==================== Data Loading for Services ====================

    fun loadCourseItems(context: Context): List<Triple<String, String, String>> {
        val result = mutableListOf<Triple<String, String, String>>()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val timetableJson = prefs.getString("timetable_json", null) ?: return result
            val data = JSONObject(timetableJson)
            val week1MondayStr = prefs.getString("week1_monday", null)
            val week1Monday = parseWeek1Monday(week1MondayStr)
            val now = Calendar.getInstance()
            val diff = ((now.timeInMillis - week1Monday!!.time) / (1000 * 60 * 60 * 24)).toInt()
            val currentWeek = (diff / 7 + 1).coerceIn(1, 20)
            val weekday = getWeekday(now)
            val courses = findTodayCourses(data, currentWeek, weekday, now)
            for (c in courses) {
                result.add(Triple(sectionTime(c.section), c.name, c.room))
            }
        } catch (_: Exception) {}
        return result
    }

    fun loadRemainingCourseItems(context: Context): List<Triple<String, String, String>> {
        val result = mutableListOf<Triple<String, String, String>>()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val timetableJson = prefs.getString("timetable_json", null) ?: return result
            val data = JSONObject(timetableJson)
            val week1MondayStr = prefs.getString("week1_monday", null)
            val week1Monday = parseWeek1Monday(week1MondayStr)
            val now = Calendar.getInstance()
            val diff = ((now.timeInMillis - week1Monday!!.time) / (1000 * 60 * 60 * 24)).toInt()
            val currentWeek = (diff / 7 + 1).coerceIn(1, 20)
            val weekday = getWeekday(now)
            val courses = findTodayCourses(data, currentWeek, weekday, now)
            val remaining = getRemainingCourses(courses)
            for (c in remaining) {
                result.add(Triple(sectionTimeShort(c.section), c.name, c.room))
            }
        } catch (_: Exception) {}
        return result
    }

    // ==================== Helper ====================

    private fun getRemainingCourses(courses: List<CourseInfo>): List<CourseInfo> {
        val now = Calendar.getInstance()
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for (c in courses) {
            val endStr = sectionEndMap[c.section] ?: continue
            val endParts = endStr.split(":")
            val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()
            if (currentMinutes <= endMinutes) {
                return courses.filter { it.section >= c.section }
            }
        }
        return emptyList()
    }

    private fun findTodayCourses(data: JSONObject, currentWeek: Int, weekday: Int, now: Calendar): List<CourseInfo> {
        val courses = mutableListOf<CourseInfo>()
        val weekStr = currentWeek.toString()
        if (data.has(weekStr)) {
            val weekCourses = data.getJSONArray(weekStr)
            for (i in 0 until weekCourses.length()) {
                val course = weekCourses.getJSONObject(i)
                val courseDay = course.optInt("dayWeek", 0)
                val courseDate = course.optString("courseDate", "")
                val isToday = if (courseDay > 0) {
                    courseDay == weekday
                } else if (courseDate.isNotEmpty()) {
                    val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now.time)
                    courseDate == todayStr
                } else false
                if (isToday) {
                    val name = course.optString("courseName", course.optString("kcmc", course.optString("name", "?")))
                    val section = course.optInt("whichSection", course.optInt("jcs", 0))
                    val room = course.optString("classroomName", course.optString("classroom", course.optString("jxdd", "")))
                    courses.add(CourseInfo(name, section, room))
                }
            }
        }
        return courses.sortedBy { it.section }
    }

    private fun parseWeek1Monday(week1MondayStr: String?): Date? {
        return if (week1MondayStr != null) {
            try {
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault()).parse(week1MondayStr)
                    ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
            } catch (e: Exception) {
                SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
            }
        } else {
            SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
        }
    }

    private fun getWeekday(now: Calendar): Int {
        return when (now.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1; Calendar.TUESDAY -> 2; Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4; Calendar.FRIDAY -> 5; Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7; else -> 1
        }
    }

    private fun getDayName(weekday: Int): String {
        return when (weekday) {
            1 -> "周一"; 2 -> "周二"; 3 -> "周三"; 4 -> "周四"
            5 -> "周五"; 6 -> "周六"; 7 -> "周日"; else -> ""
        }
    }

    fun sectionTime(section: Int): String {
        return when (section) {
            1 -> "08:30-09:15"; 2 -> "09:20-10:05"; 3 -> "10:25-11:10"
            4 -> "11:15-12:00"; 5 -> "14:40-15:25"; 6 -> "15:30-16:15"
            7 -> "16:30-17:15"; 8 -> "17:20-18:05"; 9 -> "19:30-20:15"
            10 -> "20:20-21:05"; else -> "第${section}节"
        }
    }

    fun sectionTimeShort(section: Int): String {
        return when (section) {
            1 -> "08:30"; 2 -> "09:20"; 3 -> "10:25"; 4 -> "11:15"
            5 -> "14:40"; 6 -> "15:30"; 7 -> "16:30"; 8 -> "17:20"
            9 -> "19:30"; 10 -> "20:20"; else -> "第${section}节"
        }
    }

    private val sectionEndMap = mapOf(
        1 to "09:15", 2 to "10:05", 3 to "11:10", 4 to "12:00",
        5 to "15:25", 6 to "16:15", 7 to "17:15", 8 to "18:05",
        9 to "20:15", 10 to "21:05"
    )
}
