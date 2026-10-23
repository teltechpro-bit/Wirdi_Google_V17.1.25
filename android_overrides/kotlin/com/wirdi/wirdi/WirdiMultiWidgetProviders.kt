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
                val next = (data.getInt("daily_ayah_index", 0) + 1) % ayat.size
                data.edit().putInt("daily_ayah_index", next).putString("daily_ayah_text", ayat[next]).putString("daily_ayah_date", today).apply()
            }
        }
        ids.forEach { id ->
            val views = RemoteViews(pkg, layout)
            val rootId = when (kind) {
                "daily" -> R.id.daily_root
                "ayah" -> R.id.ayah_root
                else -> R.id.tasbeeh_root
            }
            val background = when {
                data.getBoolean("widget_transparent", false) -> Color.TRANSPARENT
                data.getBoolean("widget_dark_mode", false) -> Color.rgb(23, 33, 43)
                kind == "tasbeeh" -> Color.rgb(236, 253, 245)
                kind == "ayah" -> Color.rgb(248, 250, 252)
                else -> Color.rgb(241, 245, 249)
            }
            views.setInt(rootId, "setBackgroundColor", background)
            val foreground = if (data.getBoolean("widget_dark_mode", false)) Color.WHITE else Color.rgb(15, 118, 110)
            val textIds = when (kind) {
                "daily" -> intArrayOf(R.id.daily_wird_progress, R.id.daily_azkar_remaining, R.id.daily_next_prayer, R.id.daily_countdown, R.id.daily_refresh, R.id.daily_open)
                "ayah" -> intArrayOf(R.id.ayah_text, R.id.ayah_next, R.id.ayah_open)
                else -> intArrayOf(R.id.tasbeeh_count, R.id.tasbeeh_open)
            }
            textIds.forEach { views.setTextColor(it, foreground) }
            if (kind == "tasbeeh") views.setTextColor(R.id.tasbeeh_increment, Color.WHITE)
            when (kind) {
                "daily" -> {
                    views.setTextViewText(R.id.daily_wird_progress, data.getString("wird_progress_text", "0 / 5 صفحات") ?: "0 / 5 صفحات")
                    views.setTextViewText(R.id.daily_azkar_remaining, data.getString("azkar_remaining_text", "الأذكار المتبقية: 0") ?: "الأذكار المتبقية: 0")
                    views.setTextViewText(R.id.daily_next_prayer, (data.getString("next_prayer_name", "الصلاة القادمة") ?: "الصلاة القادمة") + " • " + (data.getString("next_prayer_time", "--:--") ?: "--:--"))
                    views.setTextViewText(R.id.daily_countdown, data.getString("next_prayer_countdown_text", "متبقي -- دقيقة"))
                    views.setOnClickPendingIntent(R.id.daily_refresh, broadcast(context, WirdiDailyWidgetProvider::class.java, 1001, AppWidgetManager.ACTION_APPWIDGET_UPDATE))
                    views.setOnClickPendingIntent(R.id.daily_open, launchApp(context, 1002))
                }
                "ayah" -> {
                    val index = data.getInt("daily_ayah_index", 0).coerceIn(0, ayat.lastIndex)
                    views.setTextViewText(R.id.ayah_text, data.getString("daily_ayah_text", ayat[index]) ?: ayat[index])
                    views.setOnClickPendingIntent(R.id.ayah_next, broadcast(context, WirdiAyahWidgetProvider::class.java, 2001, "com.wirdi.wirdi.NEXT_AYAH"))
                    views.setOnClickPendingIntent(R.id.ayah_open, launchApp(context, 2002))
                }
                "tasbeeh" -> {
                    val count = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(COUNT, 0)
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
        prefs.edit().putInt(COUNT, prefs.getInt(COUNT, 0) + 1).apply()
    }
    fun nextAyah(context: Context, data: SharedPreferences) {
        val next = (data.getInt("daily_ayah_index", 0) + 1) % ayat.size
        data.edit().putInt("daily_ayah_index", next).putString("daily_ayah_text", ayat[next]).apply()
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