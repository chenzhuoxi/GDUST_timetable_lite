# Build Environment Record

## v3 Release (2026-06-13)

| 组件 | 版本 |
|------|------|
| Flutter | 3.24.5 (Dart 3.5.4) |
| JDK | OpenJDK 21.0.10 (Homebrew) |
| AGP (Android Gradle Plugin) | 8.3.0 |
| Gradle | 8.9 |
| Kotlin | 1.9.10 |
| compileSdkVersion | 35 |
| minSdkVersion | flutter.minSdkVersion |
| targetSdkVersion | flutter.targetSdkVersion |
| NDK | 25.1.8937393 |
| macOS | Darwin 25.4.0 (arm64) |
| APK 大小 | 21.0MB |
| 包名 | com.jikuai.gdust_lite |

## 历史编译记录

### v1 (2026-06-12 06:59)
- Flutter 3.7.12 (Dart 2.19.6) + JDK 17
- APK 19.3MB
- 无文件选择器（file_picker namespace 冲突）

### v2 (2026-06-12 07:27)
- 尝试加回 file_picker → 闪退
- 根因：Flutter 3.7.12 + Dart 2.19.6 不兼容 file_picker 5.x

### v3 (2026-06-13 17:23) ✅ 当前版本
- Flutter 3.24.5 (Dart 3.5.4) + JDK 21
- file_picker 5.x 正常工作
- 编译通过，功能验证正常

## 已知编译陷阱

1. **JDK 21 + Gradle ≤7.5** — 不兼容，需 Gradle ≥8.5
2. **file_picker 4.x + AGP 8.x** — namespace 未声明，编译失败
3. **file_picker 5.x + Dart <3.0** — 版本约束不满足
4. **compileSdk 33 + JDK 21** — 不兼容，需 compileSdk ≥34
