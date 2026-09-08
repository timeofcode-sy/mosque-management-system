import 'package:flutter/material.dart';

/// بابٌ قائمٌ في الهيكل ولم تُبنَ شاشتُه بعد.
///
/// م.6.3 تبني **الهيكل**: النافذةَ والدخولَ والتنقّلَ ومبدّلَ المعاهد وشريطَ
/// المزامنة. والشاشاتُ تُملأ في م.6.4–6.6 بابًا بابًا، فتبقى القائمةُ الجانبية
/// كما هي ولا يُعاد بناؤها مع كل شاشة.
///
/// ولماذا بابٌ ظاهرٌ بلا شاشة بدل بابٍ يُضاف حين تُبنى؟ لأن هذه الأبواب هي
/// **عقدُ الصلاحيات** الذي يُختبَر الآن: أن يرى المشرفُ ما يخصّه ولا يرى ما لا
/// يخصّه. ولو أُخّرت إلى شاشاتها لَما اختُبر ترشيحُها قبل أن يكتمل نصفُ المرحلة.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.phase,
    required this.note,
  });

  final String title;

  /// المرحلةُ الفرعية التي تُبنى فيها هذه الشاشة — «م.6.5» مثلاً.
  final String phase;

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text('تُبنى في $phase', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
