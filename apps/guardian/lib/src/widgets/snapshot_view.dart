import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mousqe_core/mousqe_core.dart';
import 'package:mousqe_ui/mousqe_ui.dart';

/// يحمل دورةَ قراءةٍ كاملة: تحميلٌ ⇒ خطأٌ برسالته ⇒ محتوىً **مع إعلانِ قِدَمه**.
///
/// 🔑 **هذا الودجت هو موضعُ القاعدة الأولى من [PHASE-7-STAGES.MD §4]**: بيانٌ
/// قديم يُعرض بلا إعلانِ قِدَمه يقرؤه صاحبُه حاضراً. وليُّ الأمر يفتح التطبيق في
/// نفقٍ فيرى حضورَ الأسبوع الماضي، فيطمئنّ إلى رقمٍ عمرُه ستّةُ أيام.
///
/// فوضعُها ههنا لا في كل شاشة: خمسُ شاشاتٍ تقرأ خمسَ قراءات، ولو تُركت لكلِّ
/// واحدةٍ لَنسيتها إحداها — وهي الحالةُ التي لا تظهر في التطوير أصلاً لأن الشبكة
/// عاملةٌ دائماً على مكتب المطوّر.
class SnapshotView<T> extends StatefulWidget {
  const SnapshotView({
    super.key,
    required this.load,
    required this.builder,
    this.emptyMessage,
    this.isEmpty,
  });

  /// يُستدعى عند أول بناء وعند كل سحبٍ للتحديث.
  final Future<Snapshot<T>> Function() load;

  final Widget Function(BuildContext context, T value) builder;

  /// نصُّ الحالة الفارغة — ومعه [isEmpty] الذي يقرّر متى تكون فارغة.
  final String? emptyMessage;
  final bool Function(T value)? isEmpty;

  @override
  State<SnapshotView<T>> createState() => SnapshotViewState<T>();
}

class SnapshotViewState<T> extends State<SnapshotView<T>> {
  Future<Snapshot<T>>? _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.load();
  }

  /// يُستدعى من السحب للتحديث ومن زر «إعادة المحاولة».
  Future<void> reload() async {
    final pending = widget.load();
    setState(() => _pending = pending);

    try {
      // يُنتظر ليبقى `RefreshIndicator` دائراً حتى تنتهي القراءة فعلاً.
      await pending;
    } on Object {
      // ويُبتلع الخطأُ **ههنا وحدَه**: `FutureBuilder` يعرضه في الشجرة برسالته،
      // ورميُه ثانيةً من هذا السياق رميٌ غيرُ ملتقَط يُسقط الإطار.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Snapshot<T>>(
      future: _pending,
      builder: (context, async) {
        if (async.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (async.hasError) {
          return ErrorState(
            message: messageFor(async.error!),
            onRetry: reload,
          );
        }

        final snapshot = async.data!;
        final empty = widget.isEmpty?.call(snapshot.value) ?? false;

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (snapshot.isStale) StaleNotice(fetchedAt: snapshot.fetchedAt),
              if (empty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(
                    message: widget.emptyMessage ?? 'لا شيء بعد.',
                    onRetry: reload,
                  ),
                )
              else
                widget.builder(context, snapshot.value),
            ],
          ),
        );
      },
    );
  }
}

/// «هذه نسخةٌ محفوظة» ومتى قُرئت — لا شريطَ مزامنةٍ ولا طابور.
///
/// تطبيقُ الأستاذ والديسكتوب يعرضان `SyncBar` لأن لهما طابوراً يقول «بقيت ثلاثُ
/// عمليات لم تصل». ولا طابورَ ههنا، فالسؤالُ الذي يهمّ وليَّ الأمر مختلف:
/// **متى قرأ جهازي آخرَ مرّة؟**
class StaleNotice extends StatelessWidget {
  const StaleNotice({super.key, this.fetchedAt});

  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fetchedAt == null
                  ? 'لا اتصال — هذه نسخةٌ محفوظة على الجهاز.'
                  : 'لا اتصال — آخر تحديث ${formatStamp(fetchedAt!)}.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// «اليوم 08:12» · «أمس 19:40» · «2026-09-03 07:55».
///
/// لأن «قبل ٦ أيام» وحدها تُقرأ ولا تُتحقَّق: من يريد أن يعرف إن كان الرقم
/// اليومَ أم لا يحتاج تاريخاً لا مدّة.
String formatStamp(DateTime at) {
  final local = at.toLocal();
  final time = DateFormat('HH:mm').format(local);
  final today = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final difference = DateTime(today.year, today.month, today.day).difference(day).inDays;

  return switch (difference) {
    0 => 'اليوم $time',
    1 => 'أمس $time',
    _ => '${DateFormat('yyyy-MM-dd').format(local)} $time',
  };
}

/// تاريخُ يومٍ بلا وقت — «2026-09-09» تُعرض «الأربعاء 9 أيلول».
String formatDay(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);

  if (parsed == null) {
    return isoDate;
  }

  return DateFormat('EEEE d MMMM', 'ar').format(parsed);
}
