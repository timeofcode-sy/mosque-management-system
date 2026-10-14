import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/connected_action.dart';
import '../widgets/sync_bar.dart';

/// الإعلانات — كانت في لوحة الويب وحدها، خلف `announcements.manage`.
///
/// **تُقرأ من الشبكة** لا من drift: الإعلاناتُ لا تصل الإدارةَ في التيّار، فهي
/// كـ«المعاهد» قائمةٌ تحتاج اتصالاً، والكتابةُ تعيد قراءتها.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  static const audiences = {
    'students': 'الطلاب',
    'guardians': 'أولياء الأمور',
    'teachers': 'الأساتذة',
  };

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  Future<List<AdminAnnouncement>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final deps = AppScope.of(context);

    setState(() {
      _future = deps.content.loadAnnouncements();
    });
  }

  /// سحبُ القائمة إلى الأسفل يعيد قراءتها — على الهاتف بدل زرّ التحديث.
  Future<void> _pull() {
    _reload();

    return _future!.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعلانات'),
        actions: [
          const PhoneSyncAction(),
          if (!AppConfig.isPhone)
            IconButton(
              tooltip: 'تحديث',
              icon: const NzIcon(NzIcons.review),
              onPressed: _reload,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const NzIcon(NzIcons.megaphone),
        label: const Text('إعلان جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: _pull,
        child: FutureBuilder<List<AdminAnnouncement>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Scrollable(
                child: EmptyState(
                  message: isOffline(snapshot.error!)
                      ? 'الإعلاناتُ تحتاج اتصالاً.'
                      : messageFor(snapshot.error!),
                  icon: NzIcons.offline,
                  onRetry: _reload,
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final announcements = snapshot.data!;

            if (announcements.isEmpty) {
              return const _Scrollable(
                child: EmptyState(
                  message: 'لا إعلانات بعد.\nما يُنشر هنا يظهر في تطبيقات الطلاب وأولياء الأمور والأساتذة.',
                  icon: NzIcons.megaphone,
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(context.gutter(), 16, context.gutter(), 96),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _card(context, announcements[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AdminAnnouncement announcement) {
    final theme = Theme.of(context);
    final nz = context.nz;
    final audience = [
      for (final key in announcement.audience) AnnouncementsScreen.audiences[key] ?? key,
    ].join('، ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(announcement.title, style: theme.textTheme.titleMedium),
                ),
                StatusBadge(
                  announcement.isPublished ? 'منشور' : 'مسودّة',
                  tone: announcement.isPublished ? StatusTone.success : StatusTone.neutral,
                ),
                RowActionsMenu(
                  actions: [
                    RowAction(
                      icon: NzIcons.edit,
                      label: 'تحرير',
                      onPressed: () => _edit(context, announcement),
                    ),
                    if (announcement.isPublished)
                      RowAction(
                        icon: NzIcons.eyeSlash,
                        label: 'سحب النشر',
                        destructive: true,
                        onPressed: () => _unpublish(context, announcement),
                      ),
                  ],
                ),
              ],
            ),
            Text(
              announcement.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              [
                'إلى: $audience',
                if (announcement.scope == 'circle')
                  '${announcement.scopeIds.length} حلقة'
                else
                  'المعهد كلّه',
                if (announcement.publishedAt != null) formatLongDate(announcement.publishedAt!, withWeekday: false),
                if (announcement.author != null) announcement.author!,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: nz.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [AdminAnnouncement? announcement]) async {
    final deps = AppScope.of(context);
    final circles = await deps.content.loadCurrentCircles();

    if (!context.mounted) {
      return;
    }

    final result = await showDialog<_Draft>(
      context: context,
      builder: (_) => _AnnouncementDialog(announcement: announcement, circles: circles),
    );

    if (result == null || !context.mounted) {
      return;
    }

    final ok = await runConnected(
      context,
      () => deps.content.saveAnnouncement(
        uuid: announcement?.uuid,
        title: result.title,
        body: result.body,
        audience: result.audience,
        circleIds: result.circleIds,
        publish: result.publish,
      ),
      success: result.publish ? 'نُشر الإعلان.' : 'حُفظ الإعلان مسودّة.',
    );

    if (ok) {
      _reload();
    }
  }

  Future<void> _unpublish(BuildContext context, AdminAnnouncement announcement) async {
    final confirmed = await confirmAction(
      context,
      title: 'سحب الإعلان',
      message: 'سيختفي «${announcement.title}» من التطبيقات، ويبقى هنا مسودّةً يُعاد نشرُها بالتحرير.',
      confirmLabel: 'سحب',
      destructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final deps = AppScope.of(context);

    final ok = await runConnected(
      context,
      () => deps.content.unpublishAnnouncement(announcement.uuid),
      success: 'سُحب الإعلان.',
    );

    if (ok) {
      _reload();
    }
  }
}

class _Draft {
  const _Draft({
    required this.title,
    required this.body,
    required this.audience,
    required this.circleIds,
    required this.publish,
  });

  final String title;
  final String body;
  final List<String> audience;
  final List<int> circleIds;
  final bool publish;
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.announcement, required this.circles});

  final AdminAnnouncement? announcement;
  final List<CircleOption> circles;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  late final _title = TextEditingController(text: widget.announcement?.title ?? '');
  late final _body = TextEditingController(text: widget.announcement?.body ?? '');
  late final Set<String> _audience = {...?widget.announcement?.audience};
  late final Set<int> _circles = {
    if (widget.announcement?.scope == 'circle') ...widget.announcement!.scopeIds,
  };
  late bool _allCircles = widget.announcement?.scope != 'circle';
  String? _error;

  @override
  void initState() {
    super.initState();

    if (_audience.isEmpty) {
      _audience.addAll(['students', 'guardians']);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit(bool publish) {
    final title = _title.text.trim();
    final body = _body.text.trim();

    final error = title.isEmpty || body.isEmpty
        ? 'العنوانُ والنصُّ مطلوبان.'
        : _audience.isEmpty
            ? 'اختر فئةً واحدةً على الأقل.'
            : !_allCircles && _circles.isEmpty
                ? 'اختر حلقةً واحدةً على الأقل، أو وجّهه إلى المعهد كلّه.'
                : null;

    if (error != null) {
      setState(() => _error = error);

      return;
    }

    Navigator.of(context).pop(
      _Draft(
        title: title,
        body: body,
        audience: [
          for (final key in AnnouncementsScreen.audiences.keys)
            if (_audience.contains(key)) key,
        ],
        circleIds: _allCircles ? const [] : _circles.toList(),
        publish: publish,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.announcement == null ? 'إعلان جديد' : 'تحرير الإعلان'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.announcement == null,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'النصّ',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            Text('يصل إلى', style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in AnnouncementsScreen.audiences.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _audience.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      selected ? _audience.add(entry.key) : _audience.remove(entry.key);
                    }),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('للمعهد كلّه'),
              subtitle: const Text('أطفئه لتوجيهه إلى حلقاتٍ بعينها'),
              value: _allCircles,
              onChanged: widget.circles.isEmpty
                  ? null
                  : (value) => setState(() => _allCircles = value),
            ),
            if (!_allCircles)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final circle in widget.circles)
                    FilterChip(
                      label: Text(circle.name),
                      selected: _circles.contains(circle.id),
                      onSelected: (selected) => setState(() {
                        selected ? _circles.add(circle.id) : _circles.remove(circle.id);
                      }),
                    ),
                ],
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.nz.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        OutlinedButton(
          onPressed: () => _submit(false),
          child: const Text('حفظ مسودّة'),
        ),
        FilledButton(
          onPressed: () => _submit(true),
          child: const Text('نشر'),
        ),
      ],
    );
  }
}

/// حالةٌ فارغة تقبل السحبَ للتحديث — `RefreshIndicator` يحتاج قائمةً تُسحب.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
  }
}
