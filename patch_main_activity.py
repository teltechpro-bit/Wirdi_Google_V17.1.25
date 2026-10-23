from pathlib import Path
import re

candidates = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
if not candidates:
    raise SystemExit("ERROR: MainActivity.kt not found; cannot guarantee media notification and silent-mode integration")
else:
    for path in candidates:
        text = path.read_text()

        if "AudioServiceActivity" not in text:
            text = text.replace(
                "import io.flutter.embedding.android.FlutterActivity",
                "import com.ryanheise.audioservice.AudioServiceActivity",
            )
            text = text.replace(
                "class MainActivity : FlutterActivity()",
                "class MainActivity : AudioServiceActivity()",
            )
            text = text.replace(
                "class MainActivity: FlutterActivity()",
                "class MainActivity: AudioServiceActivity()",
            )
            print(f"{path}: patched to extend AudioServiceActivity")
        else:
            print(f"{path}: already extends AudioServiceActivity, skipping that step")

        if "dispatchKeyEvent" not in text:
            needed_imports = [
                "import android.app.NotificationManager",
                "import android.content.Context",
                "import android.os.Build",
                "import android.view.KeyEvent",
            ]
            insert_at = text.index(chr(10), text.index("package ")) + 1
            imports_block = chr(10) + chr(10).join(i for i in needed_imports if i not in text) + chr(10)
            if imports_block.strip():
                text = text[:insert_at] + imports_block + text[insert_at:]

            method_lines = [
                "    // BUGFIX: stop the Adhan notification sound when the user",
                "    // presses a volume key while the app is in the foreground.",
                "    override fun dispatchKeyEvent(event: KeyEvent): Boolean {",
                "        if (event.action == KeyEvent.ACTION_DOWN &&",
                "            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {",
                "            try {",
                "                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager",
                "                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {",
                "                    for (activeNotification in notificationManager.activeNotifications) {",
                '                        if (activeNotification.notification.channelId == "wirdi_prayer_adhan_v2") {',
                "                            notificationManager.cancel(activeNotification.id)",
                "                        }",
                "                    }",
                "                }",
                "            } catch (e: Exception) {",
                "                // Best-effort only -- never let this crash the app.",
                "            }",
                "        }",
                "        return super.dispatchKeyEvent(event)",
                "    }",
            ]
            override_method = chr(10) + chr(10).join(method_lines) + chr(10)

            bodyless = re.search(r"class\s+MainActivity\s*:\s*\w+\(\)\s*(?://.*)?$", text, re.MULTILINE)
            brace_open = re.search(r"class\s+MainActivity\s*:\s*\w+\(\)\s*\{", text)
            if brace_open:
                insert_pos = brace_open.end()
                text = text[:insert_pos] + override_method + text[insert_pos:]
                print(f"{path}: inserted dispatchKeyEvent() into existing class body")
            elif bodyless:
                line = bodyless.group(0)
                new_line = line.rstrip() + " {" + override_method + "}"
                text = text[:bodyless.start()] + new_line + text[bodyless.end():]
                print(f"{path}: added class body with dispatchKeyEvent()")
            else:
                raise SystemExit(f"ERROR: {path}: MainActivity class declaration not recognized; dispatchKeyEvent() was not added")
        else:
            print(f"{path}: dispatchKeyEvent() already present, skipping that step")

        if "PrayerSilentMode.register" not in text:
            # Register the prayer-time silent-mode MethodChannel (see
            # android_overrides/kotlin/com/wirdi/wirdi/PrayerSilentMode.kt).
            engine_import = "import io.flutter.embedding.engine.FlutterEngine"
            if engine_import not in text:
                insert_at = text.index(chr(10), text.index("package ")) + 1
                text = text[:insert_at] + chr(10) + engine_import + chr(10) + text[insert_at:]
            cfg_lines = [
                "    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {",
                "        super.configureFlutterEngine(flutterEngine)",
                "        PrayerSilentMode.register(flutterEngine, this)",
                "    }",
            ]
            cfg_method = chr(10) + chr(10).join(cfg_lines) + chr(10)
            brace_open2 = re.search(r"class\s+MainActivity\s*:\s*\w+\(\)\s*\{", text)
            if brace_open2:
                text = text[:brace_open2.end()] + cfg_method + text[brace_open2.end():]
                print(f"{path}: registered PrayerSilentMode channel")
            else:
                raise SystemExit(f"ERROR: {path}: could not register PrayerSilentMode channel")
        else:
            print(f"{path}: PrayerSilentMode already registered, skipping")

        path.write_text(text)
