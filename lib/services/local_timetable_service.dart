import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';

class LocalTimetableService {
  /// 从 JSON 文件导入课表
  static Future<Map<String, List<Course>>> importFromFile(File file) async {
    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    final result = <String, List<Course>>{};

    data.forEach((week, courses) {
      if (courses is List) {
        result[week] = courses
            .map((c) => Course.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    });

    // 导入后自动缓存
    await cacheTimetable(result);
    return result;
  }

  /// 缓存课表到 SharedPreferences
  static Future<void> cacheTimetable(Map<String, List<Course>> timetable) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = <String, dynamic>{};
    timetable.forEach((week, courses) {
      jsonMap[week] = courses.map((c) => c.toJson()).toList();
    });
    await prefs.setString('timetable_json', json.encode(jsonMap));
  }

  /// 读取缓存的课表
  static Future<Map<String, List<Course>>?> loadCachedTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('timetable_json');
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final result = <String, List<Course>>{};
      data.forEach((week, courses) {
        if (courses is List) {
          result[week] = courses
              .map((c) => Course.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 清除缓存
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timetable_json');
  }

  /// 保存学期起始日
  static Future<void> saveWeek1Monday(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('week1_monday', date.toIso8601String());
  }

  /// 读取学期起始日
  static Future<DateTime?> loadWeek1Monday() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('week1_monday');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }
}
