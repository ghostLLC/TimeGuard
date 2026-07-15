package com.timeguard.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
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

            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type")

        when (type) {
            "review" -> {
                // 触发每日复盘（通过 Flutter 侧处理，这里发送广播）
                val flutterIntent = Intent("com.timeguard.DAILY_REVIEW")
                context.sendBroadcast(flutterIntent)
                // 重新安排明天的复盘
                scheduleDailyReview(context, 22, 0)
            }
            else -> {
                // 每日重置：通知 Flutter 侧清零
                val flutterIntent = Intent("com.timeguard.DAILY_RESET")
                context.sendBroadcast(flutterIntent)
                // 重新安排明天的重置
                scheduleDailyReset(context)
            }
        }
    }
}
