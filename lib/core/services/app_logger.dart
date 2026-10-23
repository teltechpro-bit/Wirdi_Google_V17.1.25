import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local-only diagnostic logging. Entries stay on the device until the user
/// explicitly shares the file from Notification Diagnostics. No upload or
/// analytics is performed by this class.
class AppLogger {
  AppLogger._();

  static const int _maxLogBytes = 1024 * 1024;
  static const String _logFileName = 'wirdi_diagnostics.log';
  static Future<void> _writeQueue = Future<void>.value();

  static void error(String message, {String name = 'Wirdi', Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: name, error: error, stackTrace: stackTrace, level: 1000);
    _enqueue('ERROR', name, message, error, stackTrace);
  }

  static void info(String message, {String name = 'Wirdi'}) {
    developer.log(message, name: name, level: 800);
    _enqueue('INFO', name, message, null, null);
  }

  static void _enqueue(
    String level,
    String name,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final line = StringBuffer()
      ..write(DateTime.now().toIso8601String())
      ..write(' [$level] [$name] ')
      ..writeln(message);
    if (error != null) line.writeln('Error: $error');
    if (stackTrace != null) line.writeln(stackTrace);

    _writeQueue = _writeQueue.then((_) async {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_logFileName');
      final backup = File('${directory.path}/$_logFileName.1');
      final newBytes = utf8.encode(line.toString()).length;
      if (await file.exists() && await file.length() + newBytes > _maxLogBytes) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      await file.writeAsString(line.toString(), mode: FileMode.append, flush: true);
    }).catchError((Object writeError, StackTrace writeStack) {
      // Logging must never crash or interrupt the app's normal error path.
      developer.log('Local diagnostic log write failed', name: 'Wirdi', error: writeError, stackTrace: writeStack);
    });
  }

  /// Returns the current log file after pending writes finish. Sharing is
  /// always initiated separately by an explicit user action.
  static Future<File?> diagnosticLogFile() async {
    await _writeQueue;
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_logFileName');
      if (!await file.exists() || await file.length() == 0) return null;
      return file;
    } catch (error, stackTrace) {
      developer.log('Could not access local diagnostic log', name: 'Wirdi', error: error, stackTrace: stackTrace);
      return null;
    }
  }
}
