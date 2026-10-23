package com.wirdi.wirdi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.TextView
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class WirdiFloatingService : Service() {
    companion object {
        const val ACTION_START = "com.wirdi.wirdi.OVERLAY_START"
        private const val CHANNEL = "wirdi_floating_widget"
        private const val PREFS = "HomeWidgetPreferences"
        private const val COUNT = "tasbeeh_count"
    }
    private var wm: WindowManager? = null
    private var bubble: TextView? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) { stopSelf(); return }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) nm.createNotificationChannel(NotificationChannel(CHANNEL, "Wirdi floating widget", NotificationManager.IMPORTANCE_LOW))
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        startForeground(7412, notification.setSmallIcon(R.drawable.ic_stat_wirdi).setContentTitle("وِرْدِي").setContentText("النافذة العائمة مفعّلة").setOngoing(true).build())
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        showBubble()
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun showBubble() {
        if (bubble != null) return
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
        val p = WindowManager.LayoutParams(78, 78, type, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
        p.gravity = Gravity.TOP or Gravity.START; p.x = 12; p.y = 180
        val v = TextView(this)
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val initialContent = prefs.getString("overlay_content", "tasbeeh") ?: "tasbeeh"
        v.text = when (initialContent) {
            "dhikr" -> "اذكر الله"
            "quran" -> "وِرْدِي\\nالقرآن"
            else -> "سُبْحَانَ الله\\n" + prefs.getInt(COUNT, 0)
        }
        v.textSize = 12f; v.gravity = Gravity.CENTER; v.setTextColor(Color.WHITE); v.setBackgroundColor(Color.rgb(15,118,110)); v.setPadding(8,8,8,8)
        var sx = 0f; var sy = 0f; var px = 0; var py = 0
        v.setOnTouchListener { view, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { sx=e.rawX; sy=e.rawY; px=p.x; py=p.y; true }
                MotionEvent.ACTION_MOVE -> { p.x=px+(e.rawX-sx).toInt(); p.y=py+(e.rawY-sy).toInt(); wm?.updateViewLayout(view,p); true }
                MotionEvent.ACTION_UP -> {
                    if (kotlin.math.abs(e.rawX-sx)<8 && kotlin.math.abs(e.rawY-sy)<8) {
                        val prefs=getSharedPreferences(PREFS, MODE_PRIVATE)
                        when (prefs.getString("overlay_content", "tasbeeh")) {
                            "dhikr" -> (view as TextView).text = if ((view as TextView).text.toString().contains("استغفر")) "سبحان الله" else "استغفر الله"
                            "quran" -> {
                                val launch = packageManager.getLaunchIntentForPackage(packageName)
                                launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                if (launch != null) startActivity(launch)
                            }
                            else -> {
                                val n=prefs.getInt(COUNT,0)+1; prefs.edit().putInt(COUNT,n).apply()
                                (view as TextView).text="سُبْحَانَ الله\\n$n"
                                val ids=AppWidgetManager.getInstance(this).getAppWidgetIds(ComponentName(this,WirdiTasbeehWidgetProvider::class.java))
                                sendBroadcast(Intent(this,WirdiTasbeehWidgetProvider::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS,ids))
                            }
                        }
                    } else if (kotlin.math.abs(e.rawX-sx)>=8 || kotlin.math.abs(e.rawY-sy)>=8) {
                        val screenWidth = resources.displayMetrics.widthPixels
                        if (p.x <= 16 || p.x + 78 >= screenWidth - 16) stopSelf()
                    }
                    true
                }
                else -> false
            }
        }
        try { wm?.addView(v,p); bubble=v } catch (_: Exception) { stopSelf() }
    }
    override fun onDestroy() { bubble?.let { try { wm?.removeView(it) } catch (_: Exception) {} }; bubble=null; super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}