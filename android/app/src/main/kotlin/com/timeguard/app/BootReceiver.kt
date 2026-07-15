package com.timeguard.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

/**
 * 开机广播接收器 — 自动启动前台追踪服务 + 调度闹钟
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            val serviceIntent = Intent(context, UsageTrackingService::class.java).apply {
                action = UsageTrackingService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            // 设置每日重置闹钟
            DailyResetReceiver.scheduleDailyReset(context)

            // 设置每日复盘闹钟（从 SharedPreferences 读取用户偏好时间）
            val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val reviewHour = prefs.getInt("flutter.daily_review_hour", 22)
            val reviewMinute = prefs.getInt("flutter.daily_review_minute", 0)
            DailyResetReceiver.scheduleDailyReview(context, reviewHour, reviewMinute)
        }
    }
}
