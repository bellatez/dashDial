package com.tuigha.dashdial

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            // Schedule the next daily notification
            scheduleDailyEveningNotification(context)
            
            // Show the evening reminder notification
            showEveningReminderNotification(context)
        } catch (e: Exception) {
            // Silent error handling for production
        }
    }
    
    private fun scheduleDailyEveningNotification(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Check if we have exact alarm permission (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                // Fall back to inexact alarm if exact permission not available
                scheduleInexactEveningNotification(context)
                return
            }
        }
        
        val intent = Intent(context, NotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 
            123, // Unique request code
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Set time to 7:00 PM (19:00) - typical time people are back from work
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = System.currentTimeMillis()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 19) // 7 PM
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        
        // If it's already past 7 PM, schedule for tomorrow
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        
        // Schedule daily repeating alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                AlarmManager.INTERVAL_DAY, // Repeat daily
                pendingIntent
            )
        }
    }
    
    private fun scheduleInexactEveningNotification(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, NotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 
            123, // Unique request code
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Set time to 7:00 PM (19:00)
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = System.currentTimeMillis()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 19) // 7 PM
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        
        // If it's already past 7 PM, schedule for tomorrow
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
        }

        // Use inexact alarm as fallback
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }
    
    private fun showEveningReminderNotification(context: Context) {
        // Create notification channel (for Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "evening_reminders",
                "Evening Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily evening reminders to check your contacts"
                enableLights(true)
                enableVibration(true)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
        
        // Create notification
        val notification = NotificationCompat.Builder(context, "evening_reminders")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("dashDial Reminder")
            .setContentText("Time to check who you need to call today!")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Time to check who you need to call today! Open dashDial to see your due contacts."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        // Show notification
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.notify(456, notification) // Unique notification ID
    }
}
