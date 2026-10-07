import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'empty_state.dart';

/// قراءةٌ جاهزةٌ للعرض: القيمةُ ومتى قُرئت وهل هي طازجة.
///
/// 🔑 **سجلٌّ لا صنفٌ مستورَد** — وهذا هو ما يحفظ حدَّ الحزمة. `Snapshot<T>` يسكن
/// `mousqe_core`، و`mousqe_ui` **لا تعتمد `mousqe_core`** عمداً
/// ([PLAN.md §7](../../../../../docs/PLAN.md)): مكوّناتُها تستقبل حالةً جاهزة.
///
/// وسجلّاتُ Dart **بنيويّةُ المطابقة** لا اسميّة، فما يعيده `Snapshot.ui` يطابق
/// هذا النوعَ بلا أن يعرف أحدُ الطرفين الآخر. وهو الجوابُ عن السؤال الذي تركته
/// م.7.3 مفتوحاً حين بقي `badgeOf` مكرَّراً.
typedef Loaded<T> = ({T value, DateTime? fetchedAt, bool isStale});

/// يحمل دورةَ قراءةٍ كاملة: تحميلٌ ⇒ خطأٌ برسالته ⇒ محتوىً **مع إعلانِ قِدَمه**.
///
/// 🔑 **وهذا الودجت هو موضعُ قاعدة «البيانُ القديم يُعلن قِدَمه»**: بيانٌ يُعرض بلا
/// إعلانِ قِدَمه يقرؤه صاحبُه حاضراً — أبٌ يفتح التطبيق في نفقٍ فيرى حضورَ الأسبوع
/// الماضي، فيطمئنّ إلى رقمٍ عمرُه ستّةُ أيام.
///
/// فوضعُها هنا لا في كل شاشة: تطبيقان يقرآن عشرَ قراءات، ولو تُركت لكلٍّ منها
/// لَنسيتها إحداها — **وهي الحالةُ التي لا تظهر في التطوير أصلاً** لأن الشبكة
/// عاملةٌ دائماً على مكتب المطوّر.
///
/// 🔁 **رُفعت من `apps/guardian/` في م.8.2** حين احتاجها تطبيقُ الطالب.
class SnapshotView<T> extends StatefulWidget {
  const SnapshotView({
    super.key,
    required this.load,
    required this.builder,
    this.emptyMessage,
    this.isEmpty,
    this.errorMessageBuilder,
  });

  /// يُستدعى عند أول بناء وعند كل سحبٍ للتحديث.
  final Future<Loaded<T>> Function() load;

  final Widget Function(BuildContext context, T value) builder;

  /// نصُّ الحالة الفارغة — ومعه [isEmpty] الذي يقرّر متى تكون فارغة.
  final String? emptyMessage;
  final bool Function(T value)? isEmpty;

  /// يحوّل ما يرميه [load] إلى نصٍّ عربيّ صالحٍ للعرض. وبدونه تُعرض رسالةٌ عامّة —
  /// الحزمةُ لا تعرف أخطاء الشبكة، وهي طبقةُ عرضٍ لا طبقةَ بيانات.
  final String Function(Object failure)? errorMessageBuilder;

  @override
  State<SnapshotView<T>> createState() => SnapshotViewState<T>();
}

class SnapshotViewState<T> extends State<SnapshotView<T>> {
  Future<Loaded<T>>? _pending;

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
    return FutureBuilder<Loaded<T>>(
      future: _pending,
      builder: (context, async) {
        if (async.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (async.hasError) {
          return ErrorState(
            message: widget.errorMessageBuilder?.call(async.error!) ??
                'تعذّرت القراءة.',
            onRetry: reload,
          );
        }

        final loaded = async.data!;
        final empty = widget.isEmpty?.call(loaded.value) ?? false;

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (loaded.isStale) StaleNotice(fetchedAt: loaded.fetchedAt),
              if (empty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(
                    message: widget.emptyMessage ?? 'لا شيء بعد.',
                    onRetry: reload,
                  ),
                )
              else
                widget.builder(context, loaded.value),
            ],
          ),
        );
      },
    );
  }
}

/// «هذه نسخةٌ محفوظة» ومتى قُرئت — لا شريطَ مزامنةٍ ولا طابور.
///
/// تطبيقا الأستاذ والديسكتوب يعرضان `SyncBar` لأن لهما طابوراً يقول «بقيت ثلاثُ
/// عمليات لم تصل». ولا طابورَ في تطبيقَي ولي الأمر والطالب، فالسؤالُ الذي يهمّهما
/// مختلف: **متى قرأ جهازي آخرَ مرّة؟**
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
