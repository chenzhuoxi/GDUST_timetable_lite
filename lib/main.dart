import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:home_widget/home_widget.dart';

import 'models/course.dart';
import 'services/local_timetable_service.dart';
import 'screens/settings_screen.dart';

void main() => runApp(const GdustLiteApp());

class GdustLiteApp extends StatelessWidget {
  const GdustLiteApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课表 Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B7FD7),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const TimetablePage(),
    );
  }
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  Map<String, List<Course>> timetable = {};
  bool loaded = false;
  bool _loadedEmpty = false;
  int selectedWeekday = DateTime.now().weekday;
  int selectedWeek = currentTeachingWeek();
  Timer? _timer;
  String? _nextClassName;
  Duration? _nextClassCountdown;
  String? _statusMsg;
  bool _gridMode = false;
  bool _mergeCourses = false;
  late PageController _weekdayPageController;

  @override
  void initState() {
    super.initState();
    _weekdayPageController = PageController(initialPage: selectedWeekday - 1);
    _loadSettings().then((_) => _loadCached());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weekdayPageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _mergeCourses = prefs.getBool('merge_courses') ?? false);
    final savedDate = await LocalTimetableService.loadWeek1Monday();
    if (savedDate != null) week1Monday = savedDate;
    // Refresh current week after loading week1Monday
    setState(() => selectedWeek = currentTeachingWeek());
  }

  Future<void> _loadCached() async {
    final cached = await LocalTimetableService.loadCachedTimetable();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        timetable = cached;
        loaded = true;
        _loadedEmpty = false;
      });
      _updateCountdown();
      _updateHomeWidget();
    } else {
      setState(() => _loadedEmpty = true);
    }
  }

  Future<void> _updateHomeWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('timetable_json');
      if (jsonStr != null) {
        await HomeWidget.saveWidgetData<String>('timetable_json', jsonStr);
        final week1Str = prefs.getString('week1_monday');
        if (week1Str != null) {
          await HomeWidget.saveWidgetData<String>('week1_monday', week1Str);
        }
        await HomeWidget.updateWidget(
          name: 'TimetableWidgetProvider',
          androidName: 'TimetableWidgetProvider',
          qualifiedAndroidName: 'com.jikuai.gdust_lite.TimetableWidgetProvider',
        );
      }
    } catch (_) {}
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      setState(() => _statusMsg = '正在导入...');

      final data = await LocalTimetableService.importFromFile(file);
      setState(() {
        timetable = data;
        loaded = true;
        _loadedEmpty = false;
        _statusMsg = '导入完成：${data.length} 周，${data.values.fold(0, (s, l) => s + l.length)} 条课程';
        selectedWeek = currentTeachingWeek();
      });
      _updateCountdown();
      _updateHomeWidget();

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _statusMsg = null);
      });
    } catch (e) {
      setState(() => _statusMsg = '导入失败: $e');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _statusMsg = null);
      });
    }
  }

  void _updateCountdown() {
    if (!loaded) return;
    final now = DateTime.now();
    final week = currentTeachingWeek();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayCourses = _getCoursesForDate(todayStr, week);

    Course? next;
    Duration? minDiff;

    for (final c in todayCourses) {
      final t = sectionStart[c.section];
      if (t == null) continue;
      final p = t.split(':');
      final classTime = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
      final diff = classTime.difference(now);
      if (diff.inSeconds > 0 && (minDiff == null || diff < minDiff)) {
        minDiff = diff;
        next = c;
      }
    }

    setState(() {
      _nextClassName = next?.name;
      _nextClassCountdown = minDiff;
    });
  }

  List<Course> _getCoursesForDate(String dateStr, int week) {
    final result = <Course>[];
    for (final entry in timetable.entries) {
      if (int.tryParse(entry.key) == week) {
        for (final c in entry.value) {
          if (c.date == dateStr) result.add(c);
        }
      }
    }
    return result;
  }

  List<Course> _getCoursesForWeekday(int week, int weekday) {
    final dateStr = DateFormat('yyyy-MM-dd').format(dateFromWeekDay(week, weekday));
    return _getCoursesForDate(dateStr, week);
  }

  /// Max week number that has data
  int _maxWeek() {
    int max = 1;
    for (final key in timetable.keys) {
      final n = int.tryParse(key) ?? 0;
      if (n > max) max = n;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = currentTeachingWeek();

    return Scaffold(
      appBar: AppBar(
        title: _buildWeekDropdown(currentWeek),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: '导入 JSON',
            onPressed: _importFromFile,
          ),
          IconButton(
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view),
            tooltip: _gridMode ? '列表视图' : '网格视图',
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(selectedWeek),
    );
  }

  Widget _buildWeekDropdown(int currentWeek) {
    final maxWeek = _maxWeek();
    return DropdownButton<int>(
      value: selectedWeek,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: List.generate(maxWeek, (i) {
        final w = i + 1;
        final isCurrent = w == currentWeek;
        return DropdownMenuItem(
          value: w,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('第 $w 周', style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              )),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('当前', style: TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ],
            ],
          ),
        );
      }),
      onChanged: (v) {
        if (v != null) setState(() => selectedWeek = v);
      },
    );
  }

  Widget _buildBody(int week) {
    if (!loaded || _loadedEmpty) return _buildEmpty();
    return _buildContent(week);
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 堆叠的书本+咖啡 emoji
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_loadedEmpty ? '📚' : '😴', style: const TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _loadedEmpty ? '还没有课表数据' : '今天可以休息啦',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _loadedEmpty
                  ? '用 gdust-timetable 抓取课表后\n导出 JSON 文件，再导入到这里'
                  : '这天没有课程安排，去做点喜欢的事吧',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5),
            ),
            if (_loadedEmpty) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('选择 JSON 文件'),
                onPressed: _importFromFile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(int week) {
    if (_gridMode) {
      return Column(
        children: [
          if (_nextClassName != null && _nextClassCountdown != null && week == currentTeachingWeek())
            _buildCountdownCard(),
          if (_statusMsg != null) _buildStatusBar(),
          Expanded(child: _buildGridView(week)),
        ],
      );
    }
    return Column(
      children: [
        if (_nextClassName != null && _nextClassCountdown != null && week == currentTeachingWeek())
          _buildCountdownCard(),
        if (_statusMsg != null) _buildStatusBar(),
        _buildWeekdayTabs(),
        Expanded(
          child: PageView.builder(
            controller: _weekdayPageController,
            itemCount: 7,
            onPageChanged: (i) => setState(() => selectedWeekday = i + 1),
            itemBuilder: (ctx, i) => _buildCourseList(week),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade50,
      child: Text(_statusMsg!, style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
    );
  }

  Widget _buildCountdownCard() {
    final cd = _nextClassCountdown!;
    final h = cd.inHours;
    final m = cd.inMinutes % 60;
    final s = cd.inSeconds % 60;
    final timeStr = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m ${s.toString().padLeft(2, '0')}s';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('距下一节课', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(timeStr, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(_nextClassName!, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _mergeCourseList(List<Course> courses) {
    if (!_mergeCourses) {
      return courses.map((c) => {
        'course': c,
        'sectionLabel': '${c.section}',
        'startSection': c.section,
        'endSection': c.section,
      }).toList();
    }

    courses.sort((a, b) => a.section.compareTo(b.section));
    final used = <int>{};
    final result = <Map<String, dynamic>>[];
    const pairs = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]];

    for (final pair in pairs) {
      final s1 = pair[0];
      final s2 = pair[1];
      final c1 = courses.where((c) => c.section == s1 && !used.contains(c.section)).toList();
      final c2 = courses.where((c) => c.section == s2 && !used.contains(c.section)).toList();

      if (c1.isNotEmpty && c2.isNotEmpty) {
        final same = c1.length == 1 && c2.length == 1 &&
            c1.first.name == c2.first.name &&
            c1.first.room == c2.first.room &&
            c1.first.teacher == c2.first.teacher &&
            c1.first.date == c2.first.date;
        if (same) {
          used.add(s1);
          used.add(s2);
          result.add({
            'course': c1.first,
            'sectionLabel': '$s1-$s2',
            'startSection': s1,
            'endSection': s2,
          });
          continue;
        }
      }
      if (c1.isNotEmpty) {
        used.add(s1);
        result.add({
          'course': c1.first,
          'sectionLabel': '$s1',
          'startSection': s1,
          'endSection': s1,
        });
      }
      if (c2.isNotEmpty && (c1.isEmpty || c2.length > 1 ||
          c1.first.name != c2.first.name ||
          c1.first.room != c2.first.room ||
          c1.first.teacher != c2.first.teacher ||
          c1.first.date != c2.first.date)) {
        used.add(s2);
        result.add({
          'course': c2.first,
          'sectionLabel': '$s2',
          'startSection': s2,
          'endSection': s2,
        });
      }
    }
    return result;
  }

  Widget _buildGridView(int week) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    const sectionPairs = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]];

    final Map<String, Map<int, Map<String, dynamic>?>> grid = {};

    if (_mergeCourses) {
      for (final pair in sectionPairs) {
        final key = '${pair[0]}-${pair[1]}';
        grid[key] = {};
        for (int wd = 1; wd <= 7; wd++) grid[key]![wd] = null;
      }
      for (int wd = 1; wd <= 7; wd++) {
        final courses = _getCoursesForWeekday(week, wd);
        final merged = _mergeCourseList(courses);
        for (final entry in merged) {
          for (final pair in sectionPairs) {
            final key = '${pair[0]}-${pair[1]}';
            if (entry['startSection'] == pair[0] || entry['startSection'] == pair[1]) {
              grid[key]![wd] = entry;
              break;
            }
          }
        }
      }
    } else {
      for (int sec = 1; sec <= 10; sec++) {
        grid['$sec'] = {};
        for (int wd = 1; wd <= 7; wd++) grid['$sec']![wd] = null;
      }
      for (int wd = 1; wd <= 7; wd++) {
        for (final c in _getCoursesForWeekday(week, wd)) {
          grid['${c.section}']![wd] = {
            'course': c,
            'sectionLabel': '${c.section}',
            'startSection': c.section,
            'endSection': c.section,
          };
        }
      }
    }

    final rowKeys = _mergeCourses
        ? sectionPairs.map((p) => '${p[0]}-${p[1]}').toList()
        : List.generate(10, (i) => '${i + 1}');

    final now = DateTime.now();
    Color courseColor(String name) {
      final hue = (name.hashCode.abs() % 360).toDouble();
      return HSLColor.fromAHSL(0.12, hue, 0.55, 0.92).toColor();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
            columnWidths: const {0: FixedColumnWidth(58)},
            defaultColumnWidth: const FixedColumnWidth(110),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                children: [
                  _gridHeader('节'),
                  for (final l in labels) _gridHeader(l),
                ],
              ),
              for (final key in rowKeys)
                TableRow(
                  children: [
                    _sectionLabel(key),
                    for (int wd = 1; wd <= 7; wd++)
                      _gridCell(grid[key]![wd], wd, now, courseColor),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );

  Widget _sectionLabel(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    alignment: Alignment.center,
    color: Colors.grey.shade100,
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
  );

  Widget _gridCell(Map<String, dynamic>? entry, int weekday, DateTime now, Color Function(String) courseColor) {
    if (entry == null) return const SizedBox.shrink();
    final course = entry['course'] as Course;
    final sectionLabel = entry['sectionLabel'] as String;
    final startStr = sectionStart[entry['startSection']] ?? '??:??';
    final endStr = sectionEnd[entry['endSection']] ?? '??:??';
    final isToday = _weekdayFromDate(course.date) == now.weekday;
    final isPast = isToday && _isSectionPast(entry['startSection']);
    final bgColor = courseColor(course.name);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: isPast ? Colors.grey.shade200 : bgColor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${course.name} $sectionLabel节',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
              decoration: isPast ? TextDecoration.lineThrough : null,
              color: isPast ? Colors.grey : Colors.black87),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${course.room}\n$startStr-$endStr',
            style: TextStyle(fontSize: 10,
              color: isPast ? Colors.grey : Colors.black54,
              decoration: isPast ? TextDecoration.lineThrough : null),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          if (course.teacher.isNotEmpty && course.teacher != '网络名师（超星尔雅）')
            Text(course.teacher,
              style: TextStyle(fontSize: 9, color: isPast ? Colors.grey : Colors.black38),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _onWeekdayTabTap(int wd) {
    setState(() => selectedWeekday = wd);
    _weekdayPageController.animateToPage(
      wd - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildWeekdayTabs() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(7, (i) {
          final wd = i + 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Center(child: Text(labels[i])),
                selected: wd == selectedWeekday,
                onSelected: (_) => _onWeekdayTabTap(wd),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCourseList(int week) {
    final raw = _getCoursesForWeekday(week, selectedWeekday);
    if (raw.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.free_breakfast, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('这天没课 ☺', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    final merged = _mergeCourseList(raw);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: merged.length,
      itemBuilder: (ctx, i) => _courseCard(merged[i]),
    );
  }

  /// 课程名 → 确定性颜色
  Color _courseColor(String name) {
    final hue = (name.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.50).toColor();
  }

  Widget _courseCard(Map<String, dynamic> entry) {
    final course = entry['course'] as Course;
    final sectionLabel = entry['sectionLabel'] as String;
    final start = sectionStart[entry['startSection']] ?? '??:??';
    final end = sectionEnd[entry['endSection']] ?? '??:??';
    final now = DateTime.now();
    final isToday = _weekdayFromDate(course.date) == now.weekday;
    final isPast = isToday && _isSectionPast(entry['startSection']);
    final barColor = isPast ? Colors.grey : _courseColor(course.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 5, color: barColor),
            Expanded(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: barColor,
                  child: Text(sectionLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                title: Text(course.name, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isPast ? TextDecoration.lineThrough : null,
                  color: isPast ? Colors.grey : null,
                )),
                subtitle: Text('$start-$end · ${course.room}\n${course.teacher}'),
                isThreeLine: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSectionPast(int section) {
    final endStr = sectionEnd[section];
    if (endStr == null) return false;
    final now = DateTime.now();
    final p = endStr.split(':');
    return now.isAfter(DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1])));
  }

  int _weekdayFromDate(String dateStr) {
    try { return DateTime.parse(dateStr).weekday; } catch (_) { return 0; }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          mergeCourses: _mergeCourses,
          onMergeChanged: (v) async {
            setState(() => _mergeCourses = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('merge_courses', v);
          },
        ),
      ),
    );
    await _loadSettings();
  }
}
