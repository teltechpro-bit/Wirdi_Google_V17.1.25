import re
from pathlib import Path

path = Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text()

# All permissions needed by Wirdi
# RE-ADDED (was removed earlier as "declared but unused"): now genuinely
# used -- see the ScheduledNotificationBootReceiver registration below.
perms = [
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.VIBRATE',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.WAKE_LOCK',
    # NEW: required for the Camera Qibla (AR overlay) screen added in v192,
    # which uses CameraController/availableCameras() from the `camera` plugin.
    'android.permission.CAMERA',
    # v17: prayer-time silent mode (user grants Do-Not-Disturb access in system
    # settings) and spoken recitation check (speech recognition).
    'android.permission.ACCESS_NOTIFICATION_POLICY',
    'android.permission.RECORD_AUDIO',
]
perm_lines = '\n'.join(
    f'    <uses-permission android:name="{p}" />'
    for p in perms if p not in text
)
# v1.54 FIX: this used to do a literal .replace() of the bare
# `<manifest xmlns:android=...>` tag. The tracked manifest has extra attributes on
# that tag (xmlns:tools, package=...), so the replace silently matched NOTHING and
# ACCESS_COARSE_LOCATION / VIBRATE / ACCESS_NETWORK_STATE were never added.
# Match the opening tag with a regex instead, and fail loudly if it is missing.
if perm_lines:
    text, n_sub = re.subn(r'(<manifest\b[^>]*>)', lambda m: m.group(1) + '\n' + perm_lines, text, count=1)
    if n_sub != 1:
        raise SystemExit('ERROR: could not find the <manifest> opening tag to insert permissions')

# Optional hardware: without required="false" the CAMERA / location / compass
# permissions make Google Play hide the app from devices that lack that hardware.
optional_features = [
    'android.hardware.camera',
    'android.hardware.camera.autofocus',
    'android.hardware.location',
    'android.hardware.location.gps',
    'android.hardware.sensor.compass',
]
feature_lines = '\n'.join(
    f'    <uses-feature android:name="{f}" android:required="false" />'
    for f in optional_features if f'android:name="{f}"' not in text
)
if feature_lines:
    text, n_sub = re.subn(r'(<manifest\b[^>]*>)', lambda m: m.group(1) + '\n' + feature_lines, text, count=1)
    if n_sub != 1:
        raise SystemExit('ERROR: could not find the <manifest> opening tag to insert uses-feature')

# Add usesCleartextTraffic and networkSecurityConfig to <application>
if 'usesCleartextTraffic' not in text:
    text = re.sub(
        r'<application\b',
        '<application android:usesCleartextTraffic="false" '
        'android:networkSecurityConfig="@xml/network_security_config"',
        text, count=1
    )

# Register audio_service's foreground media-playback service + media
# button receiver, so Radio/Quran audio show a system notification with
# Play/Pause/Stop (lock screen + notification shade controls).
if 'com.ryanheise.audioservice.AudioService' not in text:
    audio_service_block = (
        '\n    <service android:name="com.ryanheise.audioservice.AudioService"\n'
        '        android:foregroundServiceType="mediaPlayback"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.media.browse.MediaBrowserService" />\n'
        '        </intent-filter>\n'
        '    </service>\n'
        '    <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.MEDIA_BUTTON" />\n'
        '        </intent-filter>\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', audio_service_block + r'\1', text, count=1)


# Preserve Wirdi's scheduled-notification, widget, and silent-mode registrations.
# CI generates the Android platform folder from scratch, so these must be injected.
if 'ScheduledNotificationReceiver' not in text:
    notification_receivers = (
        '\n    <receiver android:exported="false"\n'
        '        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
        '    <receiver android:exported="false"\n'
        '        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
        '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
        '            <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
        '            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />\n'
        '        </intent-filter>\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', notification_receivers + r'\1', text, count=1)

if 'WirdiWidgetProvider' not in text:
    widget_block = (
        '\n    <receiver android:name="com.wirdi.wirdi.WirdiWidgetProvider"\n'
        '        android:exported="true">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
        '        </intent-filter>\n'
        '        <meta-data android:name="android.appwidget.provider"\n'
        '            android:resource="@xml/wirdi_widget_info" />\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', widget_block + r'\1', text, count=1)

if 'SilentModeReceiver' not in text:
    silent_block = (
        '\n    <receiver android:name="com.wirdi.wirdi.SilentModeReceiver"\n'
        '        android:exported="false">\n'
        '        <intent-filter>\n'
        '            <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
        '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
        '            <action android:name="com.wirdi.wirdi.SILENT_START" />\n'
        '            <action android:name="com.wirdi.wirdi.SILENT_END" />\n'
        '        </intent-filter>\n'
        '    </receiver>\n'
    )
    text = re.sub(r'(</application>)', silent_block + r'\1', text, count=1)


# Optional floating overlay. SYSTEM_ALERT_WINDOW is a special app-op and must be
# granted by the user from Android Settings; it is never silently enabled.
overlay_permissions = [
    'android.permission.SYSTEM_ALERT_WINDOW',
    'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
]
for permission in overlay_permissions:
    if f'android:name="{permission}"' not in text:
        text, n = re.subn(r'(<manifest\b[^>]*>)', lambda m: m.group(1) + f'\n    <uses-permission android:name="{permission}" />', text, count=1)
        if n != 1:
            raise SystemExit(f'ERROR: could not add {permission}')

# Three native home-screen widgets; each receiver has a matching Kotlin provider
# and appwidget-provider XML in android_overrides/.
multi_widget_receivers = [
    ('com.wirdi.wirdi.WirdiDailyWidgetProvider', 'wirdi_daily_widget_info'),
    ('com.wirdi.wirdi.WirdiAyahWidgetProvider', 'wirdi_ayah_widget_info'),
    ('com.wirdi.wirdi.WirdiTasbeehWidgetProvider', 'wirdi_tasbeeh_widget_info'),
]
for class_name, info_xml in multi_widget_receivers:
    if class_name not in text:
        block = (
            f'\n    <receiver android:name="{class_name}" android:exported="true">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
            '        </intent-filter>\n'
            f'        <meta-data android:name="android.appwidget.provider" android:resource="@xml/{info_xml}" />\n'
            '    </receiver>\n'
        )
        text = re.sub(r'(</application>)', block + r'\1', text, count=1)

if 'com.wirdi.wirdi.WirdiFloatingService' not in text:
    overlay_service = (
        '\n    <service android:name="com.wirdi.wirdi.WirdiFloatingService" '
        'android:exported="false" android:stopWithTask="false" '
        'android:foregroundServiceType="specialUse">\n'
        '        <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" '
        'android:value="User-enabled persistent floating tasbeeh overlay" />\n'
        '    </service>\n'
    )
    text = re.sub(r'(</application>)', overlay_service + r'\1', text, count=1)

# Advertise Wirdi as a media app to Android Auto / Android Automotive.
# This enables discovery of the existing audio_service media session; a browsable
# catalog still requires the handler to expose getChildren()/playFromMediaId().
if 'com.google.android.gms.car.application' not in text:
    car_metadata = (
        '\\n    <meta-data android:name="com.google.android.gms.car.application" '
        'android:resource="@xml/automotive_app_desc" />\\n'
    )
    text, n_car = re.subn(r'(</application>)', car_metadata + r'\\1', text, count=1)
    if n_car != 1:
        raise SystemExit('ERROR: could not register Android Auto media metadata')

# Keep Android Auto Backup disabled; user data migration is handled by opt-in sync.
if 'android:allowBackup' not in text:
    text, n_backup = re.subn(
        r'<application\b',
        '<application android:allowBackup="false"',
        text,
        count=1,
    )
    if n_backup != 1:
        raise SystemExit('ERROR: could not set android:allowBackup="false"')

# Use the localized launcher resource rather than Flutter's default literal project name.
def _set_launcher_label(match):
    attrs = match.group(1)
    if re.search(r'\bandroid:label\s*=', attrs):
        attrs = re.sub(
            r'\bandroid:label\s*=\s*("[^"]*"|\'[^\']*\')',
            'android:label="@string/app_name"',
            attrs,
            count=1,
        )
    else:
        attrs += ' android:label="@string/app_name"'
    return '<application' + attrs + '>'

text, n_label = re.subn(
    r'<application\b([^>]*)>',
    _set_launcher_label,
    text,
    count=1,
    flags=re.DOTALL,
)
if n_label != 1:
    raise SystemExit('ERROR: could not set android:label on the <application> element')

# Consolidate package-visibility queries into a single <queries> block.
# Flutter templates may already contain <queries>; adding another block is invalid
# or may cause required URL/speech queries to be skipped.
query_matches = list(re.finditer(r'<queries\b[^>]*>.*?</queries>', text, flags=re.DOTALL))
query_opening = '<queries>'
query_contents = []
if '<queries' in text and not query_matches:
    raise SystemExit('ERROR: found an unclosed <queries> block in AndroidManifest.xml')
if query_matches:
    query_opening = re.match(r'<queries\b[^>]*>', query_matches[0].group(0), flags=re.DOTALL).group(0)
    for match in query_matches:
        inner = re.sub(r'^<queries\b[^>]*>|</queries>$', '', match.group(0), flags=re.DOTALL).strip()
        if inner:
            query_contents.append(inner)
    text = re.sub(r'<queries\b[^>]*>.*?</queries>', '', text, flags=re.DOTALL)

query_body = '\n'.join(query_contents)
required_query_intents = [
    ('android.intent.action.VIEW', 'android:scheme="https"',
     '        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>'),
    ('android.intent.action.VIEW', 'android:scheme="http"',
     '        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="http" />\n        </intent>'),
    ('android.intent.action.VIEW', 'android:scheme="geo"',
     '        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="geo" />\n        </intent>'),
]
for action, scheme, intent_xml in required_query_intents:
    existing_intents = re.findall(r'<intent\b.*?</intent>', query_body, flags=re.DOTALL)
    if not any(action in intent and scheme in intent for intent in existing_intents):
        query_body = (query_body + '\n' + intent_xml).strip()
if 'android.speech.RecognitionService' not in query_body:
    speech_intent = (
        '        <intent>\n'
        '            <action android:name="android.speech.RecognitionService" />\n'
        '        </intent>'
    )
    query_body = (query_body + '\n' + speech_intent).strip()

queries_block = f'\n    {query_opening}\n{query_body}\n    </queries>\n'
text = text.replace('</manifest>', queries_block + '</manifest>', 1)

path.write_text(text)
print('AndroidManifest.xml patched:')
print(text)
