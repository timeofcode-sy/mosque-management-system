import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'child_screen.dart';
import 'excuses_screen.dart';

/// الشاشةُ الأولى: أبناءُ صاحب الحساب في هذا المعهد.
///
/// وهي سببُ **عدم توسيع `/bootstrap`** في م.7.1: اللقطةُ تعطي كلَّ الأدوار
/// الهويّةَ والمعهدَ وثيمَه، وحلقاتُها لا تعني وليَّ الأمر شيئاً — شاشتُه الأولى
/// أبناؤه، ولهم نقطتُهم.
class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final institute = scope.session.snapshot?.institute.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أبنائي'),
        actions: [
          IconButton(
            tooltip: 'أذونات الغياب',
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExcusesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: scope.session.signOut,
          ),
        ],
      ),
      body: SnapshotView<List<GuardianChild>>(
        load: () async => (await scope.repository.children()).ui,
        emptyMessage: 'لا أبناءَ مسجَّلون على هذا الحساب.\n'
            'راجع إدارة المعهد إن كان هذا غيرَ متوقَّع.',
        errorMessageBuilder: messageFor,
        isEmpty: (children) => children.isEmpty,
        builder: (context, children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (institute != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  institute,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            for (final child in children) _ChildCard(child: child),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final GuardianChild child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            child.fullName.characters.first,
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(child.fullName, style: theme.textTheme.titleMedium),
        subtitle: child.registrationNo == null
            ? null
            : Text('رقم المعرف ${child.registrationNo}'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ChildScreen(child: child)),
        ),
      ),
    );
  }
}
