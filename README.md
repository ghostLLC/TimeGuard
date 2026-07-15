# TimeGuard（时用）— 构建与安装指南

## 项目概述

TimeGuard 是一款 Android 应用使用时间管理工具，帮助你为每个应用设定每日使用上限，超时后推送通知提醒。

核心功能：应用限额提醒 / 分时段限额 / 使用统计图表 / 专注模式 / 分类限额 / 成就激励系统

## 环境要求

| 工具 | 最低版本 | 说明 |
|---|---|---|
| Flutter | 3.19+ | 含 Dart 3.2+ |
| Android SDK | API 34 | compileSdkVersion 34 |
| JDK | 17 | Android Gradle Plugin 8.x 要求 |
| Android Studio | 任意 | 用于构建和调试 |
| Git | 任意 | 获取项目代码 |

## 快速开始

### 1. 安装 Flutter

如果还没有安装 Flutter，参考官方文档：
```
https://docs.flutter.dev/get-started/install
```

Windows 用户：
```powershell
# 使用 winget
winget install Flutter.Flutter

# 或手动下载解压并添加到 PATH
```

验证安装：
```bash
flutter doctor
```

### 2. 获取项目

将 `TimeGuard` 文件夹复制到你的开发目录。项目结构：

```
TimeGuard/
├── lib/                    # Flutter Dart 源码
├── android/                # Android 原生代码
├── pubspec.yaml            # 依赖配置
└── README.md               # 本文件
```

### 3. 初始化项目

由于这是一个手动创建的项目结构（非 `flutter create` 生成），需要先补充一些 Flutter 自动生成的配置文件。

在项目根目录执行：

```bash
cd TimeGuard

# 方案 A：用 flutter create 补充缺失文件（推荐）
flutter create . --project-name timeguard --org com.timeguard --platforms android

# 这会补充缺失的 .metadata, analysis_options.yaml,
# android/settings.gradle, android/gradlew 等文件
# 不会覆盖已有的 lib/ 和 android/app/src/ 文件
```

### 4. 获取依赖

```bash
flutter pub get
```

### 5. 构建 APK

```bash
# Debug 版本（可直接安装测试）
flutter build apk --debug

# Release 版本（体积更小，性能更好）
flutter build apk --release --split-per-abi
```

构建产物位置：
```
build/app/outputs/flutter-apk/app-debug.apk      # Debug
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  # Release (arm64)
```

### 6. 安装到手机

```bash
# 方式 1：直接安装
flutter install

# 方式 2：USB 连接后安装 APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 方式 3：将 APK 传到手机，在手机上点击安装
```

## 小米澎湃 OS 首次使用设置

安装完成后，需要完成以下设置才能正常使用：

### 必须设置

1. **授予使用统计权限**
   - 打开 TimeGuard → 引导页会自动引导
   - 或手动：设置 → 应用管理 → TimeGuard → 其他权限 → 获取使用情况

2. **允许通知**
   - 设置 → 应用管理 → TimeGuard → 通知管理 → 全部开启

3. **开启自启动**
   - 设置 → 应用管理 → TimeGuard → 自启动 → 开启

4. **关闭省电限制**
   - 设置 → 应用管理 → TimeGuard → 省电策略 → 无限制

### 推荐设置

5. **锁定最近任务**
   - 在最近任务界面找到 TimeGuard → 下拉 → 点击锁定图标

6. **关闭电池优化**
   - 设置 → 电池 → 应用省电策略 → TimeGuard → 无限制

## 项目架构

```
┌─────────────────────────────────────────────┐
│            Flutter UI (Dart)                │
│  Material 3 + go_router + fl_chart          │
├─────────────────────────────────────────────┤
│          Riverpod State Management          │
│  AppLimits | Usage | Focus | Achievement    │
├─────────────────────────────────────────────┤
│          Platform Channel (MethodChannel)    │
├─────────────────────────────────────────────┤
│          Android Native (Kotlin)            │
│  ForegroundService | UsageStatsManager      │
│  BootReceiver | DailyResetReceiver          │
├─────────────────────────────────────────────┤
│              SQLite Local Storage           │
└─────────────────────────────────────────────┘
```

## 关键文件说明

| 文件 | 功能 |
|---|---|
| `lib/main.dart` | 应用入口，初始化通知服务 |
| `lib/app.dart` | MaterialApp 配置，路由定义 |
| `lib/core/constants.dart` | 全局常量，时段定义，预设分类 |
| `lib/core/theme.dart` | Material 3 主题 |
| `lib/models/` | 数据模型（AppLimit, Category 等） |
| `lib/database/` | SQLite 建表 + CRUD 操作 |
| `lib/providers/` | Riverpod 状态管理 |
| `lib/services/` | 平台服务封装（追踪、通知、小米适配） |
| `lib/pages/` | 各页面 UI |
| `android/.../UsageTrackingService.kt` | 前台服务，持续监控 |
| `android/.../BootReceiver.kt` | 开机自启动 |
| `android/.../DailyResetReceiver.kt` | 每日 00:00 重置 |

## 常见问题

### Q: 构建时报 `flutter.sdk not set`
确保执行了 `flutter create .` 补充缺失文件，并在 `android/local.properties` 中设置了 `flutter.sdk` 路径。

### Q: 后台服务被杀
检查小米适配设置是否全部完成（自启动 + 省电策略 + 锁定最近任务）。

### Q: 使用统计数据不准确
确保已授予「获取使用情况」权限，且手机时区设置正确。

### Q: 通知收不到
检查通知权限 + 通知渠道设置，部分小米系统需要额外开启「悬浮通知」。

## 后续迭代方向

- 桌面小组件（今日使用进度）
- 周报/月报统计
- 悬浮窗专注计时
- 数据导出（CSV）
- Wear OS 手表端同步
