import 'package:flutter/material.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

import '../di/app_scope.dart';
import 'attendance_screen.dart';
import 'sessions_log_screen.dart';

/// كشفُ حلقات المعهد — **كلُّها لا حلقاتُ صاحب الجهاز**.
///
/// وهذا هو الفرقُ الأول بين السطحين ([APPS-FEATURES.md §4.1](../../../../../docs/APPS-FEATURES.md)):
/// «يفعل كلَّ ما يفعله الأستاذ — لأي حلقةٍ في المعهد لا لحلقاته وحده». والاستعلامُ
/// واحدٌ في `mousqe_core`، والفرقُ **معاملٌ فارغ** لا نسخةٌ ثانية منه.
///
/// والقراءةُ من drift لا من الشبكة: ما يظهر هنا وصل في `sync/pull`، فالكشفُ يُفتح
/// والشبكةُ مقطوعة.
class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// ترشيحٌ بالدوام — معهدٌ بثلاثة دوامات يعرض ثلاثين حلقة، والمشرفُ يعمل في
  /// واحدٍ منها في الساعة الواحدة.
  String? _shift;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حلقات المعهد'),
        actions: [
          IconButton(
            tooltip: 'سجل الجلسات',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SessionsLogScreen(),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<CircleView>>(
        stream: deps.circles.watchCircles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;

          if (all.isEmpty) {
            return EmptyState(
              // حالتان تنتهيان إلى كشفٍ فارغ، ونصٌّ واحد لا يفرّق بينهما يترك
              // المشرفَ يظنّ الجهازَ معطّلاً: لا دورةَ جارية، أو لم تصل بعد.
              message: 'لا حلقات في الدورة الجارية.\n'
                  'إن كانت الدورة قد بدأت للتوّ فزامِن الجهازَ ليصلك كشفُها.',
              icon: Icons.groups_2_outlined,
              onRetry: deps.sync.syncNow,
            );
          }

          final shifts = {for (final circle in all) circle.shiftName}.toList()
            ..sort();
          final circles = all.where(_matches).toList();

          return Column(
            children: [
              _Filters(
                controller: _search,
                shifts: shifts,
                shift: _shift,
                onQuery: (value) => setState(() => _query = value.trim()),
                onShift: (value) => setState(() => _shift = value),
                total: all.length,
                shown: circles.length,
              ),
              const Divider(height: 1),
              Expanded(
                child: circles.isEmpty
                    ? const EmptyState(
                        message: 'لا حلقة تطابق البحث.',
                        icon: Icons.search_off_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: circles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _CircleCard(circle: circles[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// البحثُ يشمل الأستاذَ والقاعة لا اسمَ الحلقة وحده: المشرف يسأل «أين حلقة
  /// الشيخ فلان» أكثر مما يسأل عن اسمها.
  bool _matches(CircleView circle) {
    if (_shift != null && circle.shiftName != _shift) {
      return false;
    }

    if (_query.isEmpty) {
      return true;
    }

    return [
      circle.circleName,
      circle.shiftName,
      circle.room ?? '',
      circle.teachersLabel,
    ].any((field) => field.contains(_query));
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.controller,
    required this.shifts,
    required this.shift,
    required this.onQuery,
    required this.onShift,
    required this.total,
    required this.shown,
  });

  final TextEditingController controller;
  final List<String> shifts;
  final String? shift;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onShift;
  final int total;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'ابحث باسم الحلقة أو الأستاذ أو القاعة',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String?>(
              initialValue: shift,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'الدوام',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الدوامات')),
                for (final name in shifts)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onShift,
            ),
          ),
          Text(
            shown == total ? '$total حلقة' : '$shown من $total',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle});

  final CircleView circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(circle.circleName, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              '${circle.shiftName} · ${circle.shiftStartsAtLabel}',
              if (circle.room != null) _room(circle.room!),
              '${circle.studentsCount} طالباً',
              // حلقةٌ بلا أستاذ ليست خطأً في البيانات بل عملاً ينتظر المشرف،
              // فتُقال صراحةً بدل أن تُترك فراغاً يُقرأ سهواً.
              circle.teachers.isEmpty ? 'بلا أستاذ مسنَد' : circle.teachersLabel,
            ].join(' — '),
          ),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AttendanceScreen(circle: circle, date: DateTime.now()),
          ),
        ),
      ),
    );
  }
}

/// «قاعة 2» لا «قاعة القاعة 2» — نظيرُ ما في تطبيق الأستاذ حرفياً: الحقلُ نصٌّ
/// حرٌّ يكتبه المعهد من اللوحة، فبعضُهم يكتب الرقم وبعضُهم يكتب الاسم كاملاً.
String _room(String room) => room.contains('قاعة') ? room : 'قاعة $room';
