import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import '../widgets/connected_action.dart';
import '../widgets/credentials_dialog.dart';

/// المستخدمون والأدوار — ✅ م.6.5، فوق `GET /admin/users` و`/admin/roles`.
///
/// **وهذه الشاشةُ تقرأ من الشبكة لا من drift** — وهي الوحيدةُ في التطبيق مع
/// «بيانات الدخول» و«التعارضات». والسببُ بنيويّ لا اختيار: `users` جدولٌ **لا
/// يُزامَن عمداً** لأن حمولتَه بيانات دخول لا تُبثّ في تيّارٍ يقرؤه كلُّ جهازٍ في
/// المعهد ([SYNC-PROTOCOL.md §2]). فما لا يصل في `sync/pull` يُقرأ من الشبكة.
///
/// **والحراسةُ في الأفعال لا هنا:** `AssignUserRole::assertAssignable` تمنع
/// إسنادَ دورٍ أعلى من دور المُسنِد على السطحين معاً، ورفضُها يعود 422 برسالته
/// العربية. فالقائمةُ هنا تُرشَّح بالرتبة **تسهيلاً** لا حمايةً.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();

  Future<(List<AdminUser>, List<RoleOption>)>? _future;
  String _query = '';

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

  void _reload() {
    final deps = AppScope.of(context);

    setState(() {
      _future = () async {
        final roles = await deps.admin.loadRoles();
        final users = await deps.admin.loadUsers(search: _query.isEmpty ? null : _query);

        return (users, roles);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمون والأدوار'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          if (deps.session.can('users.invite'))
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
              child: FilledButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('حساب جديد'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _search,
              onSubmitted: (value) {
                _query = value.trim();
                _reload();
              },
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'ابحث بالاسم أو اسم الدخول ثم اضغط Enter',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    _query = _search.text.trim();
                    _reload();
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<(List<AdminUser>, List<RoleOption>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _NetworkError(
                    error: snapshot.error!,
                    onRetry: _reload,
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final (users, roles) = snapshot.data!;

                if (users.isEmpty) {
                  return const EmptyState(
                    message: 'لا مستخدمين مطابقين.',
                    icon: Icons.badge_outlined,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _UserRow(
                    user: users[index],
                    roles: roles,
                    onChanged: _reload,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _invite() async {
    final deps = AppScope.of(context);
    final roles = await deps.admin.loadRoles();

    if (!mounted) {
      return;
    }

    final first = TextEditingController();
    final last = TextEditingController();
    var role = roles.isEmpty ? null : roles.first.name;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('حساب جديد'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                TextField(
                  controller: first,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الأول',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: last,
                  decoration: const InputDecoration(
                    labelText: 'اسم العائلة',
                    border: OutlineInputBorder(),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الدور',
                    border: OutlineInputBorder(),
                  ),
                  // الكتالوجُ من الخادم لا من نسخةٍ في Dart — وما يعرضه هو ما
                  // يحقّ لصاحب الحساب إسنادُه أصلاً.
                  items: [
                    for (final option in roles)
                      DropdownMenuItem(
                        value: option.name,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => role = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: role == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    IssuedCredentials? credentials;

    final ok = await runConnected(
      context,
      () async {
        credentials = await deps.admin.inviteUser(
          firstName: first.text.trim(),
          lastName: last.text.trim(),
          role: role!,
        );
      },
      success: 'أُنشئ الحساب.',
    );

    if (!ok || !mounted) {
      return;
    }

    _reload();

    // **تُعرَض مرّةً واحدة**: لا قناةَ بريدٍ في المشروع، والتسليمُ طباعةٌ ونسخٌ
    // يدوي. ومن أغلق الحوارَ بلا نسخٍ عليه أن يولّد كلمةً جديدة.
    if (credentials != null) {
      await showCredentialsDialog(context, credentials!);
    }
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.roles,
    required this.onChanged,
  });

  final AdminUser user;
  final List<RoleOption> roles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    final theme = Theme.of(context);

    return ListTile(
      title: Row(
        spacing: 8,
        children: [
          Text(user.name),
          if (!user.isActive)
            Chip(
              label: const Text('مقفل', style: TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.errorContainer,
            ),
        ],
      ),
      subtitle: Text(
        [
          user.username ?? 'بلا اسم دخول',
          if (user.roles.isEmpty)
            'بلا دور'
          else
            user.roles
                .map((r) => r.institute == null ? r.label : '${r.label} (${r.institute})')
                .join(' · '),
        ].join(' — '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (deps.session.can('users.manage'))
            IconButton(
              tooltip: 'إسناد دور',
              icon: const Icon(Icons.add_moderator_outlined, size: 18),
              onPressed: () => _assign(context),
            ),
          if (deps.session.can('credentials.manage'))
            IconButton(
              tooltip: 'توليد كلمة مرور جديدة',
              icon: const Icon(Icons.password_outlined, size: 18),
              onPressed: () => _resetPassword(context),
            ),
          if (deps.session.can('users.manage'))
            IconButton(
              tooltip: user.isActive ? 'إقفال الحساب' : 'فتح الحساب',
              icon: Icon(
                user.isActive ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 18,
              ),
              onPressed: () => _toggleActivation(context),
            ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context) async {
    final held = {for (final role in user.roles) role.role};

    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('إسناد دور إلى ${user.name}'),
        children: [
          for (final role in roles)
            SimpleDialogOption(
              onPressed: held.contains(role.name)
                  ? null
                  : () => Navigator.of(dialogContext).pop(role.name),
              child: Text(
                held.contains(role.name) ? '${role.label} (مُسنَد)' : role.label,
              ),
            ),
        ],
      ),
    );

    if (picked == null || !context.mounted) {
      return;
    }

    final ok = await runConnected(
      context,
      () => AppScope.of(context)
          .admin
          .assignRole(userId: user.id, role: picked),
      success: 'أُسند الدور.',
    );

    if (ok) {
      onChanged();
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('توليد كلمة مرور جديدة'),
        content: Text(
          'تُبطَل كلمةُ ${user.name} الحالية فوراً، وتُعرض الجديدةُ مرّةً واحدة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('توليد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    IssuedCredentials? credentials;

    final ok = await runConnected(
      context,
      () async {
        credentials =
            await AppScope.of(context).admin.resetPassword(user.id);
      },
      success: 'وُلّدت كلمةُ مرورٍ جديدة.',
    );

    if (!ok || !context.mounted) {
      return;
    }

    onChanged();

    if (credentials != null) {
      await showCredentialsDialog(context, credentials!);
    }
  }

  Future<void> _toggleActivation(BuildContext context) async {
    final closing = user.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(closing ? 'إقفال الحساب' : 'فتح الحساب'),
        content: Text(
          closing
              // وهو أثرٌ لا يعرفه من لم يقرأ البروتوكول، فيُقال هنا.
              ? 'لن يدخل ${user.name} بعدها، و**يُمسح مخزنُ جهازه** عند أوّل '
                  'محاولةٍ يرفضها الخادم — فما لم يُزامَن من كتاباته يضيع.'
              : 'يعود ${user.name} إلى الدخول بكلمته الحالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(closing ? 'إقفال' : 'فتح'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final ok = await runConnected(
      context,
      () => AppScope.of(context)
          .admin
          .setActivation(userId: user.id, active: !closing),
      success: closing ? 'أُقفل الحساب.' : 'فُتح الحساب.',
    );

    if (ok) {
      onChanged();
    }
  }
}

/// شاشةٌ تقرأ من الشبكة تحتاج حالةَ فشلٍ صريحة — و**تمييزَ الانقطاع من الرفض**:
/// «لا شبكة» عملٌ يُعاد، و«ليس لك ذلك» حكمٌ لا تُجدي إعادتُه.
class _NetworkError extends StatelessWidget {
  const _NetworkError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: isOffline(error)
          ? 'هذا البابُ يحتاج اتصالاً: الحساباتُ لا تُزامَن ولا تُخزَّن على الجهاز.\n'
              'أعِد المحاولة حين تعود الشبكة.'
          : messageFor(error),
      icon: isOffline(error) ? Icons.wifi_off_outlined : Icons.error_outline,
      onRetry: onRetry,
    );
  }
}
