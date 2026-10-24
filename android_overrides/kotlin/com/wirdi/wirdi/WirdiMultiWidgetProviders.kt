package com.wirdi.wirdi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.graphics.Color
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import es.antonborri.home_widget.HomeWidgetProvider

private object WirdiWidgetUi {
    private const val PREFS = "HomeWidgetPreferences"
    private const val COUNT = "tasbeeh_count"
    private val ayat = arrayOf(
        "إِنَّ مَعَ الْعُسْرِ يُسْرًا", "فَاذْكُرُونِي أَذْكُرْكُمْ", "وَهُوَ مَعَكُمْ أَيْنَ مَا كُنْتُمْ"
    )
    fun refresh(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences, layout: Int, kind: String) {
        val pkg = context.packageName
        if (kind == "ayah") {
            val today = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
            if (data.getString("daily_ayah_date", "") != today) {
                val pool = readAyahPool(data)
                val epochDay = java.util.concurrent.TimeUnit.MILLISECONDS.toDays(System.currentTimeMillis())
                val next = Math.floorMod(epochDay * 17L, pool.size.toLong()).toInt()
                data.edit().putInt("daily_ayah_index", next).putString("daily_ayah_text", pool[next]).putString("daily_ayah_date", today).apply()
            }
        }
        ids.forEach { id ->
            val views = RemoteViews(pkg, layout)
            val rootId = when (kind) {
                "daily" -> R.id.daily_root
                "ayah" -> R.id.ayah_root
                else -> R.id.tasbeeh_root
            }
            val dark = data.getBoolean("widget_dark_mode", false)
            val transparent = data.getBoolean("widget_transparent", false)
            if (transparent) {
                views.setInt(rootId, "setBackgroundColor", Color.TRANSPARENT)
            } else {
                val surface = if (dark) R.drawable.wirdi_widget_surface_dark else R.drawable.wirdi_widget_surface_light
                views.setInt(rootId, "setBackgroundResource", surface)
            }
            val primary = if (dark) Color.rgb(238, 220, 167) else Color.rgb(12, 93, 77)
            val body = if (dark) Color.rgb(244, 244, 235) else Color.rgb(23, 61, 53)
            val muted = if (dark) Color.rgb(184, 204, 194) else Color.rgb(88, 113, 107)
            val actionBg = if (dark) R.drawable.wirdi_widget_action_dark else R.drawable.wirdi_widget_action
            when (kind) {
                "daily" -> {
                    views.setTextColor(R.id.daily_title, primary)
                    views.setTextColor(R.id.daily_wird_progress, body)
                    views.setTextColor(R.id.daily_azkar_remaining, muted)
                    views.setTextColor(R.id.daily_next_prayer, primary)
                    views.setTextColor(R.id.daily_countdown, muted)
                    views.setTextColor(R.id.daily_refresh, primary)
                    views.setTextColor(R.id.daily_open, primary)
                    views.setInt(R.id.daily_refresh, "setBackgroundResource", actionBg)
                    views.setInt(R.id.daily_open, "setBackgroundResource", actionBg)
                }
                "ayah" -> {
                    views.setTextColor(R.id.ayah_title, primary)
                    views.setTextColor(R.id.ayah_text, body)
                    views.setTextColor(R.id.ayah_next, primary)
                    views.setTextColor(R.id.ayah_open, primary)
                    views.setInt(R.id.ayah_next, "setBackgroundResource", actionBg)
                    views.setInt(R.id.ayah_open, "setBackgroundResource", actionBg)
                }
                else -> {
                    views.setTextColor(R.id.tasbeeh_title, primary)
                    views.setTextColor(R.id.tasbeeh_subtitle, muted)
                    views.setTextColor(R.id.tasbeeh_count, primary)
                    views.setTextColor(R.id.tasbeeh_open, muted)
                    views.setTextColor(R.id.tasbeeh_increment, Color.WHITE)
                }
            }
            when (kind) {
                "daily" -> {
                    views.setTextViewText(R.id.daily_wird_progress, data.getString("wird_progress_text", "0 / 5 صفحات") ?: "0 / 5 صفحات")
                    views.setTextViewText(R.id.daily_azkar_remaining, data.getString("azkar_remaining_text", "الأذكار المتبقية: 0") ?: "الأذكار المتبقية: 0")
                    views.setTextViewText(R.id.daily_next_prayer, (data.getString("next_prayer_name", "الصلاة القادمة") ?: "الصلاة القادمة") + " • " + (data.getString("next_prayer_time", "--:--") ?: "--:--"))
                    val nextTimestamp = data.getLong("next_prayer_timestamp_ms", 0L)
                    val remaining = (nextTimestamp - System.currentTimeMillis()) / 60000L
                    val countdownText = if (nextTimestamp > System.currentTimeMillis()) {
                        val hours = remaining / 60L
                        val minutes = remaining % 60L
                        if (hours > 0) "متبقي $hours س و $minutes د" else "متبقي $minutes دقيقة"
                    } else {
                        data.getString("next_prayer_countdown_text", "حدّث مواقيت الصلاة") ?: "حدّث مواقيت الصلاة"
                    }
                    views.setTextViewText(R.id.daily_countdown, countdownText)
                    views.setOnClickPendingIntent(R.id.daily_refresh, broadcast(context, WirdiDailyWidgetProvider::class.java, 1001, AppWidgetManager.ACTION_APPWIDGET_UPDATE))
                    views.setOnClickPendingIntent(R.id.daily_open, launchApp(context, 1002))
                }
                "ayah" -> {
                    val pool = readAyahPool(data)
                    val index = data.getInt("daily_ayah_index", 0).coerceIn(0, pool.lastIndex)
                    views.setTextViewText(R.id.ayah_text, data.getString("daily_ayah_text", pool[index]) ?: pool[index])
                    views.setOnClickPendingIntent(R.id.ayah_next, broadcast(context, WirdiAyahWidgetProvider::class.java, 2001, "com.wirdi.wirdi.NEXT_AYAH"))
                    views.setOnClickPendingIntent(R.id.ayah_open, launchApp(context, 2002))
                }
                "tasbeeh" -> {
                    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val count = prefs.getInt("tasbeeh_display_count", prefs.getInt(COUNT, 0))
                    views.setTextViewText(R.id.tasbeeh_count, count.toString())
                    views.setOnClickPendingIntent(R.id.tasbeeh_increment, broadcast(context, WirdiTasbeehWidgetProvider::class.java, 3001, "com.wirdi.wirdi.INCREMENT_TASBEEH"))
                    views.setOnClickPendingIntent(R.id.tasbeeh_open, launchApp(context, 3002))
                }
            }
            manager.updateAppWidget(id, views)
        }
    }
    private fun broadcast(context: Context, cls: Class<*>, request: Int, action: String): PendingIntent {
        val intent = Intent(context, cls).setAction(action)
        return PendingIntent.getBroadcast(context, request, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun launchApp(context: Context, request: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(context, request, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun increment(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val phraseId = prefs.getString("tasbeeh_selected_phrase_id", "subhanallah") ?: "subhanallah"
        val phraseTapKey = "tasbeeh_widget_taps_$phraseId"
        prefs.edit()
            // COUNT remains a monotonic legacy counter for migration; the visible counter tracks the selected phrase's widget cycle.
            .putInt(COUNT, prefs.getInt(COUNT, 0) + 1)
            .putInt("tasbeeh_display_count", prefs.getInt("tasbeeh_display_count", prefs.getInt(COUNT, 0)) + 1)
            .putInt(phraseTapKey, prefs.getInt(phraseTapKey, 0) + 1)
            .apply()
    }
    private fun readAyahPool(data: SharedPreferences): List<String> {
        val raw = data.getString("daily_ayah_pool_json", null)
        if (!raw.isNullOrBlank()) {
            try {
                val json = JSONArray(raw)
                val verses = (0 until json.length()).mapNotNull { json.optString(it).takeIf(String::isNotBlank) }
                if (verses.isNotEmpty()) return verses
            } catch (_: Exception) { }
        }
        return ayat.toList()
    }

    fun nextAyah(context: Context, data: SharedPreferences) {
        val pool = readAyahPool(data)
        val today = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
        val next = if (data.getString("daily_ayah_date", "") != today) {
            Math.floorMod(java.util.concurrent.TimeUnit.MILLISECONDS.toDays(System.currentTimeMillis()) * 17L, pool.size.toLong()).toInt()
        } else {
            (data.getInt("daily_ayah_index", 0) + 1) % pool.size
        }
        data.edit().putInt("daily_ayah_index", next).putString("daily_ayah_text", pool[next]).putString("daily_ayah_date", today).apply()
    }
}

class WirdiDailyWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WirdiDailyWidgetProvider::class.java))
            onUpdate(context, manager, ids, context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE))
        } else super.onReceive(context, intent)
    }
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) =
        WirdiWidgetUi.refresh(context, appWidgetManager, appWidgetIds, widgetData, R.layout.wirdi_daily_widget, "daily")
}
class WirdiAyahWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.wirdi.wirdi.NEXT_AYAH") {
            WirdiWidgetUi.nextAyah(context, context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE))
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WirdiAyahWidgetProvider::class.java))
            onUpdate(context, manager, ids, context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE))
        } else super.onReceive(context, intent)
    }
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) =
        WirdiWidgetUi.refresh(context, appWidgetManager, appWidgetIds, widgetData, R.layout.wirdi_ayah_widget, "ayah")
}
class WirdiTasbeehWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.wirdi.wirdi.INCREMENT_TASBEEH") {
            WirdiWidgetUi.increment(context)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WirdiTasbeehWidgetProvider::class.java))
            onUpdate(context, manager, ids, context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE))
        } else super.onReceive(context, intent)
    }
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) =
        WirdiWidgetUi.refresh(context, appWidgetManager, appWidgetIds, widgetData, R.layout.wirdi_tasbeeh_widget, "tasbeeh")
}