import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../config.dart';
import '../di/app_scope.dart';
import '../widgets/adaptive.dart';
import '../widgets/connected_action.dart';
import '../widgets/credentials_dialog.dart';
import '../widgets/sync_bar.dart';

/// بطاقاتُ الدخول — ✅ م.6.5، فوق `GET /admin/credentials`.
///
/// **وما تعرضه محصورٌ بالرتبة على الخادم**: المشرفُ يبلغ بطاقاتِ الطلاب وأولياء
/// الأمور ولا يبلغ بطاقاتِ الحسابات الإدارية. والحصرُ هناك لا هنا — الطلبُ يصل
/// الخادمَ كيفما بُنيت الواجهة.
///
/// و`password` يعود `null` **لمن بدّل كلمته بنفسه**: النسخةُ المقروءة تُمسح
/// حينها فلا يبقى لأحدٍ اطّلاعٌ على ما اختاره — أو لحسابٍ وُلّد بلا كلمة ولم
/// تُصدَر له بعد. وذلك يُقال في السطر صراحةً بدل أن يُترك فراغاً يُقرأ عطلاً.
///
/// صفٌّ مضغوطٌ لكل حساب (الاسمُ والفئة، ثم اسمُ الدخول وكلمتُه في سطر) في قائمةٍ تُبنى
/// على مهلها — لا بطاقاتٌ واسعة ولا ترقيمُ صفحات. وعلى الهاتف تُحدَّث بسحبها إلى الأسفل.
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _search = TextEditingController();

  Future<List<CredentialCard>>? _future;
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    final deps = AppScope.of(context);
    final future = deps.admin.loadCredentials(
      role: _role,
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
    );

    // بقوسين لا بسهم: الإسنادُ بالسهم يُرجع المستقبلَ نفسَه، و`setState` يرفض دالّةً تُرجع Future.
    setState(() {
      _future = future;
    });

    return future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final canReset = AppScope.of(context).session.can('credentials.manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات الدخول'),
        actions: [
          const PhoneSyncAction(),
          // على الحاسوب زرُّ تحديث؛ وعلى الهاتف تُسحب القائمةُ إلى الأسفل كما في كل تطبيق.
          if (!AppConfig.isPhone)
            IconButton(
              tooltip: 'تحديث',
              icon: const NzIcon(NzIcons.review),
              onPressed: _reload,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _reload(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const NzIcon(NzIcons.search, size: 20),
                      hintText: context.isCompact
                          ? 'ابحث بالاسم'
                          : 'ابحث بالاسم ثم اضغط Enter',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'الفئة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: 'student', child: Text('الطلاب')),
                      DropdownMenuItem(
                        value: 'guardian',
                        child: Text('أولياء الأمور'),
                      ),
                      DropdownMenuItem(
                        value: 'teacher',
                        child: Text('الأساتذة'),
                      ),
                    ],
                    onChanged: (value) {
                      _role = value;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<CredentialCard>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Scrollable(
                      child: EmptyState(
                        message: isOffline(snapshot.error!)
                            ? 'البطاقاتُ لا تُخزَّن على الجهاز — تحتاج اتصالاً.'
                            : messageFor(snapshot.error!),
                        icon: NzIcons.offline,
                        onRetry: _reload,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final cards = snapshot.data!;

                  if (cards.isEmpty) {
                    return const _Scrollable(
                      child: EmptyState(
                        message: 'لا بطاقاتِ دخولٍ مطابقة.',
                        icon: NzIcons.key,
                      ),
                    );
                  }

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            '${cards.length} حساباً',
                            style: NzType.caption.copyWith(
                              color: context.nz.inkMuted,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverGrid.builder(
                          // عمودٌ على الهاتف، وعمودان فثلاثةٌ كلّما اتّسعت النافذة.
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 520,
                                mainAxisExtent: 92,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: cards.length,
                          itemBuilder: (context, index) => _Row(
                            card: cards[index],
                            canReset: canReset,
                            onChanged: _reload,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالةٌ فارغة تُسحب أيضاً — `RefreshIndicator` لا يعمل على ما لا يُمرَّر.
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

class _Row extends StatelessWidget {
  const _Row({
    required this.card,
    required this.canReset,
    required this.onChanged,
  });

  final CredentialCard card;
  final bool canReset;
  final Future<void> Function() onChanged;

  static const _roles = {
    'student': 'طالب',
    'guardian': 'ولي أمر',
    'teacher': 'أستاذ',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.nz;
    final password = card.password;

    return Material(
      color: c.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NzRadius.md),
        side: BorderSide(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          card.name,
                          style: NzType.label.copyWith(
                            color: c.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _roles[card.role] ?? card.role,
                        style: NzType.caption.copyWith(color: c.bronzeInk),
                      ),
                      if (!card.isActive) ...[
                        const SizedBox(width: 6),
                        NzIcon(NzIcons.lockClosed, size: 14, color: c.danger),
                      ],
                    ],
                  ),
                  if (card.detail != null)
                    Text(
                      card.detail!,
                      textDirection: TextDirection.ltr,
                      style: NzType.caption.copyWith(color: c.inkMuted),
                    ),
                  const SizedBox(height: 2),
                  // اسمُ الدخول وكلمتُه في سطرٍ واحد، باليسار لأنهما لاتينيّان.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: card.username ?? 'بلا اسم دخول',
                          style: NzType.label.copyWith(color: c.ink),
                        ),
                        TextSpan(
                          text: '   ',
                          style: NzType.label.copyWith(color: c.inkMuted),
                        ),
                        TextSpan(
                          text: password ?? 'لم تُصدَر أو بدّلها صاحبها',
                          style: password == null
                              ? NzType.caption.copyWith(color: c.inkMuted)
                              : NzType.label.copyWith(
                                  color: c.primary,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (password != null)
              IconButton(
                tooltip: 'نسخ اسم الدخول وكلمة المرور',
                icon: const NzIcon(NzIcons.copy, size: 20),
                onPressed: () => _copy(context, password),
              ),
            if (canReset)
              IconButton(
                tooltip: 'تبديل كلمة المرور',
                icon: const NzIcon(NzIcons.key, size: 20),
                onPressed: () => _changePassword(context),
              ),
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext context, String password) {
    Clipboard.setData(ClipboardData(text: '${card.username ?? ''}\n$password'));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('نُسخ دخولُ ${card.name}.')));
  }

  /// كلمةٌ يكتبها المشرف، أو ثمانيةُ أرقام يولّدها الخادم إن تُرك الحقل فارغاً — كما في اللوحة.
  /// وتحتاج اتصالاً: الكلمةُ سرٌّ لا يُصفّ في طابورٍ أوف-لاين.
  Future<void> _changePassword(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _PasswordDialog(name: card.name),
    );

    if (password == null || !context.mounted) {
      return;
    }

    IssuedCredentials? issued;

    final ok = await runConnected(context, () async {
      issued = await AppScope.of(context).admin
          .resetPassword(card.id, password: password.isEmpty ? null : password);
    }, success: 'بُدّلت كلمة المرور.');

    if (!ok || !context.mounted) {
      return;
    }

    await onChanged();

    if (issued != null && context.mounted) {
      await showCredentialsDialog(context, issued!);
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.name});

  final String name;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isNotEmpty && value.length < 8) {
      setState(() => _error = 'ثمانيةُ محارفَ على الأقل، أو اتركه فارغاً.');
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('كلمة مرور ${widget.name}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تُبطَل الكلمةُ الحالية فوراً. اكتب كلمةً جديدة، أو اترك الحقل فارغاً '
              'ليولّد النظامُ ثمانيةَ أرقام.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.visiblePassword,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'كلمة مرور جديدة (اختياري)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('تبديل')),
      ],
    );
  }
}
