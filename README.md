<div align="center">

# 时用 TimeGuard

**掌控屏幕时间，养成自律习惯**

[![Version](https://img.shields.io/badge/version-1.0.0-6366F1?style=flat-square)](https://github.com/ghostLLC/TimeGuard/releases)
[![Platform](https://img.shields.io/badge/platform-Android%208.0+-3DDC84?style=flat-square&logo=android)](#安装)
[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=flat-square&logo=flutter)](#技术栈)
[![License](https://img.shields.io/badge/license-MIT-gray?style=flat-square)](LICENSE)

[功能](#功能) · [安装](#安装) · [使用](#使用指南) · [架构](#项目架构) · [开发](#开发指南)

</div>

---

## 简介

时用是一款 Android 应用使用时间管理工具。为每个应用设定每日使用上限，超时即推送通知提醒——不强制锁定，靠提醒驱动自律。支持分时段限额、分类管理、专注模式和成就激励。

## 功能

**应用限额** — 选择任意应用，设定每日使用时长上限（15 分钟 ~ 8 小时）。超时后收到高优先级通知，每 5 分钟重复提醒。

**分时段限额** — 同一应用可按上午（06-12 时）、下午（12-18 时）、晚上（18-24 时）分别设限，适配不同场景的自律需求。

**分类限额** — 社交、娱乐、学习、购物、工具五大预设分类，可对整个分类设总时长上限，任一应用触发即提醒。

**使用统计** — 环形图展示时长分布，柱状图对比限额与已用，折线图追踪趋势，排行榜呈现 Top 10。支持今日/本周/本月切换。

**专注模式** — 一键开启倒计时（25/45/60/90/120 分钟），专注期间检测到被屏蔽应用在前台运行时立即通知。

**成就系统** — 8 种徽章（初见成效、三日不辍、周自律、月度之星…）+ 积分累计，让自律变得有成就感。

**小米澎湃 OS 适配** — 前台服务保活策略 + 引导式权限设置（自启动、省电策略、锁定最近任务）。

## 安装

### 方式一：Android Studio（推荐）

```bash
git clone https://github.com/ghostLLC/TimeGuard.git
```

用 Android Studio 打开 `TimeGuard` 目录 → 等待 Gradle 同步 → 连接手机 → 点击 Run ▶

### 方式二：命令行

```bash
git clone https://github.com/ghostLLC/TimeGuard.git
cd TimeGuard
flutter create . --project-name timeguard --org com.timeguard --platforms android
flutter pub get
flutter build apk --release --split-per-abi
```

产物位于 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`，传到手机安装即可。

## 使用指南

### 添加限额

首页点击右下角 **+** → 搜索并选择应用 → 滑动设定每日时长 → 可选开启分时段限额 → 选择分类 → 保存。

### 专注模式

专注页选择时长 → 点击「开始专注」→ 大圆环倒计时运行 → 完成获得 +10 积分。

### 查看统计

统计页切换今日/本周/本月，查看使用分布、趋势和排行。

## 小米澎湃 OS 设置

安装后需完成以下设置，确保后台服务不被系统杀死：

| 步骤 | 操作路径 |
|:---|:---|
| 自启动 | 设置 → 应用管理 → TimeGuard → 自启动 → **开启** |
| 省电策略 | 设置 → 应用管理 → TimeGuard → 省电策略 → **无限制** |
| 锁定任务 | 最近任务界面 → 下拉 TimeGuard → 点击锁定 |
| 使用统计 | 设置 → 应用管理 → TimeGuard → 其他权限 → 获取使用情况 |

## 项目架构

```
┌─────────────────────────────────────────────┐
│              Flutter UI (Dart)               │
│   Material 3 · go_router · fl_chart          │
├─────────────────────────────────────────────┤
│           Riverpod State Management          │
│   AppLimits · Usage · Focus · Achievement    │
├─────────────────────────────────────────────┤
│          SQLite + SharedPreferences          │
├─────────────────────────────────────────────┤
│         Platform Channel (MethodChannel)      │
├─────────────────────────────────────────────┤
│           Android Native (Kotlin)            │
│   ForegroundService · UsageStatsManager      │
│   BootReceiver · DailyResetReceiver          │
└─────────────────────────────────────────────┘
```

```
lib/
├── core/          # 常量、主题、工具函数
├── models/        # 数据模型（AppLimit, Category, FocusSession…）
├── database/      # SQLite 建表与 CRUD
├── providers/     # Riverpod 状态管理
├── services/      # 平台服务（追踪、通知、小米适配、成就检测）
├── pages/         # 页面（首页、统计、专注、我的、引导）
└── widgets/       # 可复用组件
```

## 技术栈

| 层 | 技术 |
|:---|:---|
| UI | Flutter 3.19+, Material 3, go_router |
| 状态管理 | Riverpod 2.x |
| 图表 | fl_chart |
| 本地存储 | sqflite + shared_preferences |
| 后台服务 | Kotlin ForegroundService + UsageStatsManager |
| 通知 | flutter_local_notifications |
| 定时任务 | workmanager + AlarmManager |

## 开发指南

### 环境要求

- Flutter 3.19+（含 Dart 3.2+）
- Android SDK API 34
- JDK 17+（推荐 Android Studio 自带 JBR）

### 国内网络适配

如果 `flutter pub get` 或 Gradle 构建因网络问题失败，设置国内镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

项目的 `settings.gradle.kts` 和 `build.gradle.kts` 已预置阿里云 Maven 镜像。

### 运行调试

```bash
flutter run --debug
```

## 常见问题

**Q: 后台服务被杀？**
检查小米适配设置是否全部完成（自启动 + 省电策略 + 锁定最近任务）。

**Q: 使用统计数据不准确？**
确保已授予「获取使用情况」权限，且手机时区设置正确。

**Q: 通知收不到？**
检查通知权限 + 通知渠道设置，部分小米系统需额外开启「悬浮通知」。

## 路线图

- [ ] 桌面小组件（今日使用进度）
- [ ] 周报/月报统计
- [ ] 悬浮窗专注计时
- [ ] 数据导出（CSV）
- [ ] Wear OS 手表端同步

## 许可证

[MIT License](LICENSE)
