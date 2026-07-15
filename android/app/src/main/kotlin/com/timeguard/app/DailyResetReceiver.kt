package com.timeguard.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * 每日重置广播接收器 — 每天 00:00 重置使用累计
 * 同时触发每日复盘通知（可配置时间）
 */
class DailyResetReceiver : BroadcastReceiver() {

    companion object {
        private const val RESET_ALARM_ID = 3001
        private const val REVIEW_ALARM_ID = 3002

        /**
         * 设置每日 00:00 重置闹钟
         */
        fun scheduleDailyReset(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, DailyResetReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, RESET_ALARM_ID, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5) // 延迟 5 秒避免午夜拥堵
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_MONTH, 1)
                }
            }

            // 设置精确重复闹钟
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        }

        /**
         * 设置每日复盘通知闹钟
         */
        fun scheduleDailyReview(context: Context, hour: Int, minute: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, DailyResetReceiver::class.java).apply {
                putExtra("type", "review")
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, REVIEW_ALARM_ID, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_MONTH, 1)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type")

        try {
            when (type) {
                "review" -> {
                    val flutterIntent = Intent("com.timeguard.DAILY_REVIEW").apply {
                        setPackage(context.packageName)
                    }
                    context.sendBroadcast(flutterIntent)
                }
                else -> {
                    val flutterIntent = Intent("com.timeguard.DAILY_RESET").apply {
                        setPackage(context.packageName)
                    }
                    context.sendBroadcast(flutterIntent)
                }
            }
        } finally {
            // 无论是否异常，都必须续链闹钟
            if (type == "review") {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val reviewHour = prefs.getInt("flutter.daily_review_hour", 22)
                val reviewMinute = prefs.getInt("flutter.daily_review_minute", 0)
                scheduleDailyReview(context, reviewHour, reviewMinute)
            } else {
                scheduleDailyReset(context)
            }
        }
    }
}
