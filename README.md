# 课表 Lite (GDUST Timetable Lite)

广东科技学院（GDUST）课表查看工具 —— 导入 JSON 即用，零配置。

## ✨ 功能

- 📋 **网格/列表双视图** — 一周课表一目了然
- 👆 **左右滑动切换星期** — 手势操作，tab 同步联动
- 🎨 **课程卡片颜色条** — 每门课固定配色，已过课程自动变灰
- ⏰ **上课倒计时** — 实时显示距下一节课的时间
- 🔀 **连续课程合并** — 同一门连排课自动合并显示
- 📁 **文件/剪贴板导入** — 两种方式导入 JSON
- 💾 **本地缓存** — 首次导入后自动缓存，后续无需重复导入
- 📱 **拟态风格桌面小组件** — 主屏幕显示今日课程

## 📦 下载

| 版本 | 大小 | 下载 |
|------|------|------|
| v1.0.3 | ~20MB | [gdust_lite_v1.0.3.apk](../../releases/latest) |

> 包名 `com.jikuai.gdust_lite`，与 Full 版可共存。

## 📖 使用

Lite 版不含课表抓取，需先用 [gdust-timetable](https://github.com/chenzhuoxi/GDUST_timetable) 导出 JSON：

```bash
python3 gdust_timetable.py --all-weeks
```

把生成的 `timetable.json` 传到手机 → 打开 App → 导入即可。

## 🔧 从源码编译

```bash
cd gdust_timetable_lite
flutter pub get
flutter build apk --release
```

> 需要 Flutter 3.22+ 和 JDK 17+。

## 📝 与 Full 版的区别

| | Lite 版 | Full 版 |
|---|---------|---------|
| 课表展示 | ✅ | ✅ |
| 文件/剪贴板导入 | ✅ | ✅ |
| CAS 登录 / 自动抓取 | ❌ | ✅ |
| 课前提醒 | ❌ | ✅ |

## 相关项目

- [GDUST_timetable](https://github.com/chenzhuoxi/GDUST_timetable) — 课表抓取工具（命令行 + Web GUI），支持 CAS 登录、自动验证码识别
- [GDUST_timetable_full](https://github.com/chenzhuoxi/GDUST_timetable_full) — 广科课表 Full 版，内置 CAS 登录 + 自动抓取 + 课前提醒

## License

[MIT](LICENSE)
