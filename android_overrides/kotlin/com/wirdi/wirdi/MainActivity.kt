package com.wirdi.wirdi

import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.speech.RecognitionService
import android.speech.SpeechRecognizer
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "wirdi/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrayerSilentMode.register(flutterEngine, this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSpeechSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                        } else {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("speech_settings_unavailable", e.message, null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("app_settings_unavailable", e.message, null)
                    }
                }
                "speechDiagnostics" -> {
                    val hasRecordPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                        checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    val services = try {
                        packageManager.queryIntentServices(
                            Intent(RecognitionService.SERVICE_INTERFACE),
                            0
                        ).mapNotNull { it.serviceInfo?.packageName }.distinct()
                    } catch (_: Exception) { emptyList<String>() }
                    val defaultRecognizer = try {
                        Settings.Secure.getString(contentResolver, "voice_recognition_service")
                    } catch (_: Exception) { null }
                    result.success(mapOf(
                        "recordAudioPermissionGranted" to hasRecordPermission,
                        "recognitionAvailable" to SpeechRecognizer.isRecognitionAvailable(this),
                        "recognitionServices" to services,
                        "defaultRecognizer" to (defaultRecognizer ?: ""),
                        "sdkInt" to Build.VERSION.SDK_INT
                    ))
                }
                "hasOverlayPermission" -> result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "startOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        result.error("overlay_permission", "Overlay permission is not granted", null)
                    } else {
                        val intent = Intent(this, WirdiFloatingService::class.java).setAction(WirdiFloatingService.ACTION_START)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    }
                }
                "stopOverlay" -> {
                    stopService(Intent(this, WirdiFloatingService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Preserve Wirdi's existing behavior: a volume-key press dismisses an
    // active Adhan notification so its sound does not continue unexpectedly.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            try {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    for (active in manager.activeNotifications) {
                        if (active.notification.channelId == "wirdi_prayer_adhan_v2") manager.cancel(active.id)
                    }
                }
            } catch (_: Exception) { }
        }
        return super.dispatchKeyEvent(event)
    }
}