import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

/// مظهرُ التطبيق كما يختاره صاحبُ الجهاز: الوضعُ (تلقائي، فاتح، داكن) وحجمُ الخط.
///
/// الحفظُ خارج هذه الحزمة: يمرّر التطبيقُ [read] و[write] (ملفُّ تفضيلاتٍ على الجهاز —
/// `PreferencesFile` في mousqe_core)، فيبقى الاختيارُ بعد الخروج والدخول ولا يُمسح مع
/// بيانات الحساب.
class AppearanceController extends ChangeNotifier {
  AppearanceController({this.read, this.write});

  final Future<String?> Function()? read;
  final Future<void> Function(String value)? write;

  /// مقاساتُ الخط المعروضة — معاملُ تكبيرٍ يُضرب في مقاس النظام.
  static final scales = <double, String>{
    0.9: 'صغير',
    1.0: 'عادي',
    1.15: 'كبير',
    1.3: 'أكبر',
  };

  ThemeMode _mode = ThemeMode.system;
  double _scale = 1.0;

  ThemeMode get mode => _mode;
  double get scale => _scale;

  /// يقرأ الاختيارَ المحفوظ — وما تعذّرت قراءتُه يبقى على الافتراضي.
  Future<void> load() async {
    try {
      final raw = await read?.call();

      if (raw == null || raw.isEmpty) {
        return;
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      _mode = ThemeMode.values.asNameMap()[json['mode']] ?? ThemeMode.system;
      final scale = (json['scale'] as num?)?.toDouble() ?? 1.0;
      _scale = scales.containsKey(scale) ? scale : 1.0;
      notifyListeners();
    } catch (_) {
      // ملفٌّ تالف أو منصّةٌ بلا تخزين: المظهرُ الافتراضي لا عطل.
    }
  }

  set mode(ThemeMode value) {
    if (value != _mode) {
      _mode = value;
      _save();
    }
  }

  set scale(double value) {
    if (value != _scale && scales.containsKey(value)) {
      _scale = value;
      _save();
    }
  }

  void _save() {
    notifyListeners();
    write
        ?.call(jsonEncode({'mode': _mode.name, 'scale': _scale}))
        .catchError((Object _) {});
  }
}

/// المظهرُ من الشجرة — يضعه [MousqeApp].
class Appearance extends InheritedNotifier<AppearanceController> {
  const Appearance({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Appearance>();
    assert(
      scope != null,
      'Appearance غير موجود فوق هذا الموضع — هل التطبيق داخل MousqeApp؟',
    );

    return scope!.notifier!;
  }

  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Appearance>()?.notifier;
}

/// لوحةُ المظهر: الوضعُ وحجمُ الخط، ويُرى الأثرُ لحظةَ الاختيار.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const AppearancePanel(),
  );
}

class AppearancePanel extends StatelessWidget {
  const AppearancePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = Appearance.of(context);
    final c = context.nz;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text('المظهر', style: Theme.of(context).textTheme.titleLarge),
          Text('الوضع', style: NzType.label.copyWith(color: c.inkMuted)),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('تلقائي'),
                icon: NzIcon(NzIcons.desktop, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('فاتح'),
                icon: NzIcon(NzIcons.sun, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('داكن'),
                icon: NzIcon(NzIcons.star, size: 18),
              ),
            ],
            selected: {appearance.mode},
            onSelectionChanged: (selection) =>
                appearance.mode = selection.first,
          ),
          const SizedBox(height: 4),
          Text('حجم الخط', style: NzType.label.copyWith(color: c.inkMuted)),
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: [
              for (final MapEntry(key: scale, value: label)
                  in AppearanceController.scales.entries)
                ButtonSegment(value: scale, label: Text(label)),
            ],
            selected: {appearance.scale},
            onSelectionChanged: (selection) =>
                appearance.scale = selection.first,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'هكذا يبدو النص: ﴿إِنَّا نَحْنُ نَزَّلْنَا الذِّكْرَ وَإِنَّا لَهُ لَحَافِظُونَ﴾',
              style: NzType.body.copyWith(color: c.ink),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
