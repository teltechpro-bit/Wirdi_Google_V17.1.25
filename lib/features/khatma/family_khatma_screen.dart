import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/family_khatma_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bi.dart';
import '../auth/login_screen.dart';

String _errorText(BuildContext context, Object error) {
  final kind = error is FamilyKhatmaException ? error.kind : 'failed';
  switch (kind) {
    case 'notSignedIn':
      return bi(context, 'سجّل الدخول أولًا', 'Please sign in first');
    case 'notFound':
      return bi(context, 'لم يُعثر على ختمة بهذا الرمز', 'No khatma found with this code');
    case 'taken':
      return bi(context, 'هذا الجزء أخذه شخص آخر', 'Someone else already took this juz');
    case 'notOwner':
      return bi(context, 'هذا الإجراء لمنشئ الختمة فقط', 'Only the creator can do this');
    case 'permission':
      return bi(
        context,
        'صلاحيات Firestore لم تُحدَّث بعد لهذه الميزة (راجع FIREBASE_SETUP.md).',
        'Firestore rules have not been published for this feature yet (see FIREBASE_SETUP.md).',
      );
    default:
      return bi(context, 'حدث خطأ، تحقق من الاتصال وحاول مجددًا', 'Something went wrong. Check your connection and try again');
  }
}

/// Group (family / friends) khatma: create or join with a code, claim juz',
/// and see everyone's progress live.
class FamilyKhatmaScreen extends StatefulWidget {
  const FamilyKhatmaScreen({super.key});

  @override
  State<FamilyKhatmaScreen> createState() => _FamilyKhatmaScreenState();
}

class _FamilyKhatmaScreenState extends State<FamilyKhatmaScreen> {
  final FamilyKhatmaService _service = FamilyKhatmaService.instance;
  Stream<List<FamilyKhatma>>? _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (_service.isSignedIn) {
      _stream = _service.myGroups();
    }
  }

  Future<void> _createDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(bi(ctx, 'ختمة جماعية جديدة', 'New group khatma')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: bi(ctx, 'اسم الختمة (مثال: عائلتي)', 'Name (e.g. My family)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(bi(ctx, 'إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(bi(ctx, 'إنشاء', 'Create')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final code = await _service.create(name);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => FamilyKhatmaGroupScreen(code: code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(context, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(bi(ctx, 'الانضمام برمز', 'Join with a code')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: bi(ctx, 'الرمز (6 خانات)', 'Code (6 characters)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(bi(ctx, 'إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(bi(ctx, 'انضمام', 'Join')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.join(code);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FamilyKhatmaGroupScreen(code: code.trim().toUpperCase())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(context, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(bi(context, 'الختمة الجماعية', 'Group Khatma')), centerTitle: true),
      body: !_service.isSignedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_rounded, size: 56, color: AppColors.goldAccent),
                    const SizedBox(height: 12),
                    Text(
                      bi(
                        context,
                        'الختمة الجماعية تحتاج حسابًا لتتزامن بين أفراد العائلة والأصدقاء.',
                        'Group khatma needs an account so everyone sees the same progress.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
                        if (!mounted) return;
                        setState(_bind);
                      },
                      child: Text(bi(context, 'تسجيل الدخول', 'Sign in')),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _createDialog,
                          icon: const Icon(Icons.add),
                          label: Text(bi(context, 'إنشاء ختمة', 'Create')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _joinDialog,
                          icon: const Icon(Icons.login),
                          label: Text(bi(context, 'انضمام برمز', 'Join')),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<FamilyKhatma>>(
                    stream: _stream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_errorText(context, snap.error ?? 'failed'), textAlign: TextAlign.center),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final groups = snap.data!;
                      if (groups.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              bi(context, 'لا توجد ختمات بعد. أنشئ واحدة وشارك رمزها مع أهلك.',
                                  'No khatmas yet. Create one and share its code with your family.'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
                        itemCount: groups.length,
                        itemBuilder: (context, i) {
                          final g = groups[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.12),
                                child: Text('${g.doneCount}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                '${bi(context, 'الرمز', 'Code')}: ${g.code} • ${g.members.length} ${bi(context, 'أعضاء', 'members')} • ${g.doneCount}/30',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => FamilyKhatmaGroupScreen(code: g.code)),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class FamilyKhatmaGroupScreen extends StatelessWidget {
  final String code;
  const FamilyKhatmaGroupScreen({super.key, required this.code});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(context, e))));
    }
  }

  void _juzSheet(BuildContext context, FamilyKhatma g, int juz) {
    final service = FamilyKhatmaService.instance;
    final me = service.uid;
    final claim = g.claims[juz];

    if (claim == null) {
      _run(context, () => service.claim(code, juz));
      return;
    }
    if (claim.uid != me) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${bi(context, 'الجزء', 'Juz')} $juz — ${claim.name}${claim.done ? ' ✓' : ''}',
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('${bi(ctx, 'الجزء', 'Juz')} $juz', style: const TextStyle(fontWeight: FontWeight.w800))),
            ListTile(
              leading: Icon(claim.done ? Icons.undo : Icons.check_circle_outline),
              title: Text(claim.done ? bi(ctx, 'إلغاء علامة الإتمام', 'Mark as not finished') : bi(ctx, 'أتممته', 'Mark as finished')),
              onTap: () {
                Navigator.pop(ctx);
                _run(context, () => service.setDone(code, juz, !claim.done));
              },
            ),
            if (!claim.done)
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(bi(ctx, 'تركه لغيري', 'Release it')),
                onTap: () {
                  Navigator.pop(ctx);
                  _run(context, () => service.release(code, juz));
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _tileColor(FamilyKhatma g, int juz, String? me) {
    final c = g.claims[juz];
    if (c == null) return Colors.grey.withValues(alpha: 0.18);
    if (c.done) return Colors.green.withValues(alpha: 0.55);
    if (c.uid == me) return AppColors.goldAccent.withValues(alpha: 0.55);
    return Colors.blue.withValues(alpha: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    final service = FamilyKhatmaService.instance;
    return StreamBuilder<FamilyKhatma?>(
      stream: service.watch(code),
      builder: (context, snap) {
        final g = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(g?.name ?? bi(context, 'ختمة', 'Khatma')),
            centerTitle: true,
            actions: [
              if (g != null)
                IconButton(
                  tooltip: bi(context, 'مشاركة الرمز', 'Share code'),
                  icon: const Icon(Icons.share),
                  onPressed: () => Share.share(
                    bi(
                      context,
                      'انضم إلى ختمتنا الجماعية في تطبيق وردي. الرمز: ${g.code}',
                      'Join our group khatma in the Wirdi app. Code: ${g.code}',
                    ),
                  ),
                ),
            ],
          ),
          body: snap.hasError
              ? Center(child: Text(_errorText(context, snap.error ?? 'failed')))
              : !snap.hasData && snap.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : g == null
                      ? Center(child: Text(bi(context, 'هذه الختمة لم تعد موجودة', 'This khatma no longer exists')))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${bi(context, 'الرمز', 'Code')}: ', style: const TextStyle(color: Colors.grey)),
                                        SelectableText(g.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 16)),
                                        const Spacer(),
                                        Text('${bi(context, 'الدورة', 'Round')} ${g.rounds}'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: g.doneCount / 30,
                                      minHeight: 10,
                                      borderRadius: BorderRadius.circular(8),
                                      color: AppColors.primaryEmerald,
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${g.doneCount} / 30 ${bi(context, 'جزءًا مكتملًا', 'juz completed')}'),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${bi(context, 'الأعضاء', 'Members')}: ${g.members.values.join('، ')}',
                                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bi(context, 'اضغط على جزء لتأخذه، وعلى جزئك لتعلّمه منتهيًا.', 'Tap a juz to take it; tap your own juz to mark it finished.'),
                              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            GridView.count(
                              crossAxisCount: 5,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              children: [
                                for (var juz = 1; juz <= 30; juz++)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _juzSheet(context, g, juz),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _tileColor(g, juz, service.uid),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('$juz', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                          if (g.claims[juz] != null)
                                            Text(
                                              g.claims[juz]!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 9.5),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _legend(Colors.grey.withValues(alpha: 0.18), bi(context, 'متاح', 'Free')),
                                _legend(AppColors.goldAccent.withValues(alpha: 0.55), bi(context, 'جزئي', 'Mine')),
                                _legend(Colors.blue.withValues(alpha: 0.35), bi(context, 'أخذه غيري', 'Taken')),
                                _legend(Colors.green.withValues(alpha: 0.55), bi(context, 'مكتمل', 'Done')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (g.ownerUid == service.uid)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(bi(ctx, 'بدء ختمة جديدة؟', 'Start a new round?')),
                                      content: Text(bi(ctx, 'ستُمسح كل الأجزاء المحجوزة.', 'All claimed juz will be cleared.')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(bi(ctx, 'إلغاء', 'Cancel'))),
                                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(bi(ctx, 'متابعة', 'Continue'))),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    await _run(context, () => service.startNewRound(code));
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: Text(bi(context, 'ختمة جديدة', 'Start a new round')),
                              ),
                            TextButton.icon(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(bi(ctx, 'مغادرة الختمة؟', 'Leave this khatma?')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(bi(ctx, 'إلغاء', 'Cancel'))),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(bi(ctx, 'مغادرة', 'Leave'))),
                                    ],
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  await _run(context, () => service.leave(code));
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.exit_to_app),
                              label: Text(bi(context, 'مغادرة الختمة', 'Leave')),
                            ),
                          ],
                        ),
        );
      },
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
