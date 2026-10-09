import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/quran_audio_service.dart';
import 'way2quran_storage.dart';

class Way2QuranPlaylistStore {
  static const _key = 'way2quran.playlists.v1';

  static Future<Map<String, List<String>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty || entry.value is! List) continue;
        final tracks = (entry.value as List)
            .map((value) => value.toString())
            .where((path) => path.trim().isNotEmpty)
            .toSet()
            .toList();
        result[name] = tracks;
      }
      return result;
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static Future<void> _save(Map<String, List<String>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(playlists));
  }

  static Future<bool> create(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return false;
    final playlists = await all();
    if (playlists.containsKey(normalized)) return false;
    playlists[normalized] = <String>[];
    await _save(playlists);
    return true;
  }

  static Future<bool> addTrack(String playlist, String path) async {
    final normalized = playlist.trim();
    final file = File(path);
    if (normalized.isEmpty || !path.toLowerCase().endsWith('.mp3') || !await file.exists()) return false;
    final appDir = await getApplicationDocumentsDirectory();
    final expectedParent = Directory('${appDir.path}/${Way2QuranStorage.recitationsRelativePath}').absolute.path;
    if (file.parent.absolute.path != expectedParent) return false;
    final playlists = await all();
    final tracks = playlists[normalized];
    if (tracks == null) return false;
    if (!tracks.contains(file.path)) tracks.add(file.path);
    await _save(playlists);
    return true;
  }

  static Future<void> removeTrack(String playlist, String path) async {
    final playlists = await all();
    playlists[playlist]?.remove(path);
    await _save(playlists);
  }

  static Future<void> delete(String playlist) async {
    final playlists = await all();
    playlists.remove(playlist);
    await _save(playlists);
  }

  static Future<bool> addFileToPlaylist(BuildContext context, String path) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final playlists = await all();
    final controller = TextEditingController();
    String? selected = playlists.keys.isEmpty ? null : playlists.keys.first;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ar ? 'إضافة إلى قائمة تشغيل' : 'Add to playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (playlists.isNotEmpty) ...[
                Text(ar ? 'اختر قائمة موجودة' : 'Choose an existing playlist'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selected,
                  isExpanded: true,
                  items: playlists.keys.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) => setDialogState(() => selected = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: ar ? 'أو اكتب اسم قائمة جديدة' : 'Or create a new playlist',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ar ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final typed = controller.text.trim();
                Navigator.pop(dialogContext, typed.isNotEmpty ? typed : selected);
              },
              child: Text(ar ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return false;
    var target = result.trim();
    if (!playlists.containsKey(target)) {
      final created = await create(target);
      if (!created) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'يوجد بالفعل قائمة بهذا الاسم.' : 'A playlist with that name already exists.')));
        }
        return false;
      }
    }
    final added = await addTrack(target, path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added
            ? (ar ? 'تمت الإضافة إلى القائمة.' : 'Added to playlist.')
            : (ar ? 'تعذرت إضافة الملف إلى القائمة.' : 'Could not add this file to the playlist.')),
      ));
    }
    return added;
  }
}

class Way2QuranPlaylistsScreen extends StatefulWidget {
  const Way2QuranPlaylistsScreen({super.key});

  @override
  State<Way2QuranPlaylistsScreen> createState() => _Way2QuranPlaylistsScreenState();
}

class _Way2QuranPlaylistsScreenState extends State<Way2QuranPlaylistsScreen> {
  Map<String, List<String>> _playlists = {};
  bool _loading = true;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final value = await Way2QuranPlaylistStore.all();
    if (mounted) setState(() { _playlists = value; _loading = false; });
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ar ? 'قائمة تشغيل جديدة' : 'New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: _ar ? 'اسم القائمة' : 'Playlist name', border: const OutlineInputBorder()),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_ar ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(_ar ? 'إنشاء' : 'Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final created = await Way2QuranPlaylistStore.create(name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created
          ? (_ar ? 'تم إنشاء قائمة التشغيل.' : 'Playlist created.')
          : (_ar ? 'يوجد بالفعل قائمة بهذا الاسم.' : 'A playlist with that name already exists.'))));
    }
    if (mounted) await _load();
  }

  Future<void> _play(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'الملف لم يعد موجودًا؛ احذف المسار من القائمة.' : 'The file is missing. Remove it from the playlist.')));
      }
      return;
    }
    try {
      await quranAudio.playExternalFile(file.path, title: _label(file));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'تعذر تشغيل التلاوة.' : 'Could not play this recitation.')));
    }
  }

  String _label(File file) {
    final base = file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
    return base.replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), '').replaceAll('_', ' ').replaceAll('-', ' ');
  }

  Future<void> _deletePlaylist(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ar ? 'حذف قائمة التشغيل؟' : 'Delete playlist?'),
        content: Text(_ar ? 'سيتم حذف القائمة فقط، ولن تُحذف الملفات المنزّلة.' : 'Only the playlist is removed; downloaded audio files stay on the device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_ar ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await Way2QuranPlaylistStore.delete(name);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ar ? 'قوائم التشغيل' : 'Playlists'),
        actions: [IconButton(onPressed: _create, tooltip: _ar ? 'قائمة جديدة' : 'New playlist', icon: const Icon(Icons.add_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, size: 60, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(_ar ? 'أنشئ قائمة تشغيل خاصة بك' : 'Create your own playlist', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(_ar ? 'أضف التلاوات المنزّلة إلى قوائم حسب رغبتك.' : 'Add downloaded recitations to playlists organized your way.', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: Text(_ar ? 'إنشاء قائمة' : 'Create playlist')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: _playlists.entries.map((entry) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const CircleAvatar(child: Icon(Icons.queue_music_rounded)),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_ar ? '${entry.value.length} تلاوة' : '${entry.value.length} recitation(s)'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) { if (value == 'delete') _deletePlaylist(entry.key); },
                        itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(_ar ? 'حذف القائمة' : 'Delete playlist'))],
                      ),
                      children: entry.value.isEmpty
                          ? [Padding(padding: const EdgeInsets.all(16), child: Text(_ar ? 'القائمة فارغة. أضف تلاوة من صفحة التنزيلات.' : 'This playlist is empty. Add a recitation from Downloads.'))]
                          : entry.value.map((path) {
                              final file = File(path);
                              final exists = file.existsSync();
                              return ListTile(
                                leading: Icon(exists ? Icons.audio_file_rounded : Icons.file_present_outlined),
                                title: Text(_label(file), maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: exists ? null : Text(_ar ? 'الملف غير موجود' : 'File missing'),
                                onTap: exists ? () => _play(path) : null,
                                trailing: IconButton(
                                  tooltip: _ar ? 'إزالة من القائمة' : 'Remove from playlist',
                                  onPressed: () async {
                                    await Way2QuranPlaylistStore.removeTrack(entry.key, path);
                                    await _load();
                                  },
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                ),
                              );
                            }).toList(),
                    ),
                  )).toList(),
                ),
      floatingActionButton: _playlists.isEmpty ? null : FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(_ar ? 'قائمة جديدة' : 'New playlist'),
      ),
    );
  }
}
