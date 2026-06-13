package com.jikuai.gdust_lite

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class TimetableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)

            try {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val timetableJson = prefs.getString("timetable_json", null)

                if (timetableJson != null) {
                    val data = JSONObject(timetableJson)
                    val week1MondayStr = prefs.getString("week1_monday", null)

                    // Calculate current teaching week
                    val week1Monday = if (week1MondayStr != null) {
                        try {
                            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault()).parse(week1MondayStr)
                                ?: SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
                        } catch (e: Exception) {
                            SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
                        }
                    } else {
                        SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse("2026-03-09")
                    }

                    val now = Calendar.getInstance()
                    val diff = ((now.timeInMillis - week1Monday!!.time) / (1000 * 60 * 60 * 24)).toInt()
                    val currentWeek = (diff / 7 + 1).coerceIn(1, 20)

                    // Get today's weekday (1=Monday, 7=Sunday)
                    val todayWeekday = now.get(Calendar.DAY_OF_WEEK)
                    val weekday = when (todayWeekday) {
                        Calendar.MONDAY -> 1
                        Calendar.TUESDAY -> 2
                        Calendar.WEDNESDAY -> 3
                        Calendar.THURSDAY -> 4
                        Calendar.FRIDAY -> 5
                        Calendar.SATURDAY -> 6
                        Calendar.SUNDAY -> 7
                        else -> 1
                    }

                    // Update title
                    val dayName = when (weekday) {
                        1 -> "周一"
                        2 -> "周二"
                        3 -> "周三"
                        4 -> "周四"
                        5 -> "周五"
                        6 -> "周六"
                        7 -> "周日"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_title, "今日课表 · $dayName")
                    views.setTextViewText(R.id.widget_week, "第${currentWeek}周")

                    // Find today's courses
                    val courses = mutableListOf<String>()
                    val weekStr = currentWeek.toString()

                    if (data.has(weekStr)) {
                        val weekCourses = data.getJSONArray(weekStr)
                        for (i in 0 until weekCourses.length()) {
                            val course = weekCourses.getJSONObject(i)
                            val courseDay = course.optInt("dayWeek", 0)
                            val courseDate = course.optString("courseDate", "")

                            // Match by dayWeek or by date
                            val isToday = if (courseDay > 0) {
                                courseDay == weekday
                            } else if (courseDate.isNotEmpty()) {
                                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now.time)
                                courseDate == todayStr
                            } else {
                                false
                            }

                            if (isToday) {
                                val name = course.optString("courseName", course.optString("kcmc", course.optString("name", "?")))
                                val section = course.optInt("whichSection", course.optInt("jcs", 0))
                                val room = course.optString("classroomName", course.optString("classroom", course.optString("jxdd", "")))
                                val time = sectionTime(section)
                                courses.add("📌 $time  $name\n    📍 $room")
                            }
                        }
                    }

                    if (courses.isEmpty()) {
                        views.setTextViewText(R.id.widget_courses, "今天没有课程 🎉")
                    } else {
                        views.setTextViewText(R.id.widget_courses, courses.joinToString("\n\n"))
                    }
                } else {
                    views.setTextViewText(R.id.widget_title, "今日课表")
                    views.setTextViewText(R.id.widget_week, "")
                    views.setTextViewText(R.id.widget_courses, "请先导入课表数据 📥")
                }
            } catch (e: Exception) {
                views.setTextViewText(R.id.widget_title, "今日课表")
                views.setTextViewText(R.id.widget_week, "")
                views.setTextViewText(R.id.widget_courses, "数据加载失败")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun sectionTime(section: Int): String {
            return when (section) {
                1 -> "08:30-09:15"
                2 -> "09:20-10:05"
                3 -> "10:25-11:10"
                4 -> "11:15-12:00"
                5 -> "14:40-15:25"
                6 -> "15:30-16:15"
                7 -> "16:30-17:15"
                8 -> "17:20-18:05"
                9 -> "19:30-20:15"
                10 -> "20:20-21:05"
                else -> "第${section}节"
            }
        }
    }
}
