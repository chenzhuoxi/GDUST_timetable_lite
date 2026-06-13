class Course {
  final String name;
  final String date;
  final int section;
  final String room;
  final String teacher;
  final int week;
  final int dayWeek;

  Course({
    required this.name,
    required this.date,
    required this.section,
    required this.room,
    required this.teacher,
    this.week = 0,
    this.dayWeek = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['courseName'] ?? json['kcmc'] ?? json['name'] ?? '未知课程',
      date: json['courseDate'] ?? '',
      section: _parseInt(json['whichSection'] ?? json['jcs'] ?? json['section']),
      room: json['classroomName'] ?? json['classroom'] ?? json['room'] ?? json['jxdd'] ?? '',
      teacher: json['teacher'] ?? json['teacherName'] ?? json['xm'] ?? '',
      week: json['week'] is int ? json['week'] : int.tryParse('${json['week'] ?? 0}') ?? 0,
      dayWeek: json['dayWeek'] is int ? json['dayWeek'] : int.tryParse('${json['dayWeek'] ?? 0}') ?? 0,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) {
      final nums = RegExp(r'\d+').allMatches(v).map((m) => int.parse(m.group(0)!)).toList();
      return nums.isNotEmpty ? nums.first : 0;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'courseName': name,
    'courseDate': date,
    'whichSection': section,
    'classroomName': room,
    'teacher': teacher,
    'week': week,
    'dayWeek': dayWeek,
  };
}

const Map<int, String> sectionStart = {
  1: '08:30', 2: '09:20', 3: '10:25', 4: '11:15',
  5: '14:40', 6: '15:30', 7: '16:30', 8: '17:20',
  9: '19:30', 10: '20:20',
};

const Map<int, String> sectionEnd = {
  1: '09:15', 2: '10:05', 3: '11:10', 4: '12:00',
  5: '15:25', 6: '16:15', 7: '17:15', 8: '18:05',
  9: '20:15', 10: '21:05',
};

DateTime week1Monday = DateTime(2026, 3, 9);

int currentTeachingWeek() {
  final diff = DateTime.now().difference(week1Monday).inDays;
  return (diff ~/ 7 + 1).clamp(1, 20);
}

DateTime dateFromWeekDay(int week, int weekday) {
  return week1Monday.add(Duration(days: (week - 1) * 7 + (weekday - 1)));
}
