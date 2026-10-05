package com.wirdi.wirdi

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Silences the phone (vibrate or silent) for short windows around prayer time
 * and restores the previous ringer mode afterwards.
 *
 * Needs the "Do Not Disturb access" permission (ACCESS_NOTIFICATION_POLICY),
 * which the user grants from system settings. Without it nothing is changed.
 */
object PrayerSilentMode {
    const val CHANNEL = "com.wirdi.wirdi/silent_mode"
    const val ACTION_START = "com.wirdi.wirdi.SILENT_START"
    const val ACTION_END = "com.wirdi.wirdi.SILENT_END"

    private const val PREFS = "wirdi_silent_mode"
    private const val KEY_WINDOWS = "windows"
    private const val KEY_MODE = "mode"
    private const val KEY_COUNT = "alarm_count"
    private const val KEY_ACTIVE = "active"
    private const val KEY_SAVED_RINGER = "saved_ringer"
    private const val KEY_APPLIED_RINGER = "applied_ringer"
    private const val REQ_BASE = 910000

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasPolicyAccess" -> result.success(hasPolicyAccess(appContext))
                    "openPolicySettings" -> {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        appContext.startActivity(intent)
                        result.success(true)
                    }
                    "schedule" -> {
                        val mode = call.argument<String>("mode") ?: "vibrate"
                        val raw = call.argument<List<Map<String, Any>>>("windows") ?: emptyList()
                        val array = JSONArray()
                        for (item in raw) {
                            val start = (item["start"] as Number).toLong()
                            val end = (item["end"] as Number).toLong()
                            val obj = JSONObject()
                            obj.put("start", start)
                            obj.put("end", end)
                            array.put(obj)
                        }
                        val prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        prefs.edit().putString(KEY_MODE, mode).putString(KEY_WINDOWS, array.toString()).apply()
                        scheduleFromPrefs(appContext)
                        result.success(true)
                    }
                    "cancel" -> {
                        cancelAll(appContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("silent_mode_error", e.message, null)
            }
        }
    }

    fun hasPolicyAccess(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    private fun pendingFor(context: Context, action: String, code: Int, flags: Int): PendingIntent? {
        val intent = Intent(context, SilentModeReceiver::class.java)
        intent.action = action
        var piFlags = flags
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, code, intent, piFlags)
    }

    private fun setAlarm(context: Context, atMillis: Long, pi: PendingIntent) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        }
    }

    private fun cancelAlarms(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val count = prefs.getInt(KEY_COUNT, 0)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until count) {
            for (action in listOf(ACTION_START, ACTION_END)) {
                val code = REQ_BASE + i * 2 + (if (action == ACTION_END) 1 else 0)
                val existing = pendingFor(context, action, code, PendingIntent.FLAG_NO_CREATE)
                if (existing != null) {
                    am.cancel(existing)
                    existing.cancel()
                }
            }
        }
        prefs.edit().putInt(KEY_COUNT, 0).apply()
    }

    /** (Re)creates the alarms for every future window stored in preferences. */
    fun scheduleFromPrefs(context: Context) {
        cancelAlarms(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_WINDOWS, null) ?: return
        val array = JSONArray(raw)
        val now = System.currentTimeMillis()
        var index = 0
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val start = obj.getLong("start")
            val end = obj.getLong("end")
            if (end <= now) continue
            val startCode = REQ_BASE + index * 2
            val endCode = REQ_BASE + index * 2 + 1
            if (start > now) {
                val startPi = pendingFor(context, ACTION_START, startCode, PendingIntent.FLAG_UPDATE_CURRENT)
                if (startPi != null) setAlarm(context, start, startPi)
            } else {
                applySilent(context)
            }
            val endPi = pendingFor(context, ACTION_END, endCode, PendingIntent.FLAG_UPDATE_CURRENT)
            if (endPi != null) setAlarm(context, end, endPi)
            index++
        }
        prefs.edit().putInt(KEY_COUNT, index).apply()
    }

    fun cancelAll(context: Context) {
        cancelAlarms(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_WINDOWS).apply()
        restoreRinger(context)
    }

    fun applySilent(context: Context) {
        if (!hasPolicyAccess(context)) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val current = audio.ringerMode
        val wantSilent = prefs.getString(KEY_MODE, "vibrate") == "silent"
        val target = if (wantSilent) AudioManager.RINGER_MODE_SILENT else AudioManager.RINGER_MODE_VIBRATE
        // RINGER_MODE_SILENT(0) < RINGER_MODE_VIBRATE(1) < RINGER_MODE_NORMAL(2).
        // If the phone is already as quiet as requested (or quieter) leave it alone.
        if (current <= target) {
            prefs.edit().putBoolean(KEY_ACTIVE, false).apply()
            return
        }
        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putInt(KEY_SAVED_RINGER, current)
            .putInt(KEY_APPLIED_RINGER, target)
            .apply()
        try {
            audio.ringerMode = target
        } catch (e: SecurityException) {
            prefs.edit().putBoolean(KEY_ACTIVE, false).apply()
        }
    }

    fun restoreRinger(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ACTIVE, false)) return
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val applied = prefs.getInt(KEY_APPLIED_RINGER, -1)
        val saved = prefs.getInt(KEY_SAVED_RINGER, AudioManager.RINGER_MODE_NORMAL)
        // Only restore if the user hasn't changed the ringer mode in the meantime.
        if (audio.ringerMode == applied) {
            try {
                audio.ringerMode = saved
            } catch (e: SecurityException) {
                // Permission was revoked meanwhile; nothing more we can do.
            }
        }
        prefs.edit().putBoolean(KEY_ACTIVE, false).apply()
    }
}

class SilentModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            PrayerSilentMode.ACTION_START -> PrayerSilentMode.applySilent(context)
            PrayerSilentMode.ACTION_END -> PrayerSilentMode.restoreRinger(context)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                PrayerSilentMode.scheduleFromPrefs(context)
            else -> {
            }
        }
    }
}
