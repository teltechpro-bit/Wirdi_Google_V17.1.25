import 'package:flutter/widgets.dart';

/// True when the active app language is Arabic.
bool isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

/// Inline bilingual helper (Arabic / English). Other languages see English,
/// which is the same convention the existing tool screens already use.
String bi(BuildContext context, String ar, String en) =>
    isArabic(context) ? ar : en;
