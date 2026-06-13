# 课表 Lite (GDUST Timetable Lite)

广东科技学院（GDUST）课表查看工具 Lite 版 —— 纯展示，导入 JSON 即用。

## ✨ 功能

- 📋 **网格/列表双视图** — 一周课表一目了然
- ⏰ **上课倒计时** — 实时显示距离下一节课的时间
- 🔀 **连续课程合并** — 同一门连排课自动合并显示
- 📁 **文件导入** — 从手机本地选择 JSON 文件导入
- 📋 **剪贴板导入** — 从剪贴板粘贴 JSON 内容
- 💾 **本地缓存** — 首次导入后自动缓存，后续打开无需重复导入

## 📦 下载

| 版本 | 大小 | 下载 |
|------|------|------|
| v3 (Flutter 3.24.5) | 21.0MB | [gdust_lite.apk](../../releases/latest) |

> 包名 `com.jikuai.gdust_lite`，与 Full 版可共存。

## 🔧 编译环境

| 组件 | 版本 |
|------|------|
| Flutter | 3.24.5 (Dart 3.5.4) |
| JDK | OpenJDK 21.0.10 |
| AGP | 8.3.0 |
| Gradle | 8.9 |
| Kotlin | 1.9.10 |
| compileSdk | 35 |
| NDK | 25.1.8937393 |

### 从源码编译

```bash
# 确保已安装 Flutter 3.24.5+ 和 JDK 21
cd gdust_timetable_lite

# 获取依赖
flutter pub get

# 编译 Release APK
flutter build apk --release

# 输出：build/app/outputs/flutter-apk/app-release.apk
```

## 📖 使用方法

Lite 版不包含课表抓取功能，需要先用 [gdust-timetable](https://github.com/chenzhuoxi/GDUST_timetable) 命令行工具导出 JSON：

```bash
# 1. 用命令行工具导出全学期课表
python3 gdust_timetable.py --all-weeks

# 2. 将生成的 timetable.json 传到手机

# 3. 打开 Lite App → 点「导入文件」→ 选择 timetable.json
```

## 📁 JSON 格式

```json
[
  {
    "course_name": "高等数学",
    "teacher": "张三",
    "classroom": "A101",
    "day_of_week": 1,
    "start_section": 1,
    "end_section": 2,
    "week_range": "1-16"
  }
]
```

## 📂 项目结构

```
gdust_timetable_lite/
├── lib/
│   ├── main.dart              # 主界面（网格/列表视图、导入逻辑）
│   ├── models/
│   │   └── course.dart        # 课程数据模型
│   ├── screens/
│   │   └── settings_screen.dart  # 设置页面
│   └── services/
│       └── local_timetable_service.dart  # 本地 JSON 解析与缓存
├── android/                   # Android 工程配置
├── pubspec.yaml               # 依赖声明
└── README.md
```

## 📝 与 Full 版的区别

| 功能 | Lite 版 | Full 版 |
|------|---------|---------|
| 课表展示 | ✅ | ✅ |
| 文件/剪贴板导入 | ✅ | ✅ |
| CAS 登录 | ❌ | ✅ |
| 自动抓取课表 | ❌ | ✅ |
| 课前提醒 | ❌ | ✅ |
| 包名 | com.jikuai.gdust_lite | com.jikuai.gdust_timetable |

## 相关项目

- [GDUST_timetable](https://github.com/chenzhuoxi/GDUST_timetable) — 命令行版 + Web GUI，支持 CAS 登录和自动抓取

## License

[MIT](LICENSE)
