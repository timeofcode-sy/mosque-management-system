import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';

/// النافذة: حجمٌ أدنى، وعنوان، وحالةٌ تصمد بين تشغيلٍ وآخر
/// ([PLAN.md §7](../../../../../docs/PLAN.md)).
///
/// **ولماذا ملفٌّ لا `app_state` في drift؟** لأن مخزن drift يُمسح كاملاً عند
/// الخروج وعند قفل الحساب ([SYNC-PROTOCOL.md §8] البند 10)، فكانت النافذةُ تقفز
/// إلى حجمها الافتراضي كلّما خرج صاحبُها. وحجمُ النافذة صفةُ الجهاز لا صفةُ
/// الحساب الذي دخل منه.
class DesktopWindow with WindowListener {
  DesktopWindow._(this._file, this._state);

  /// أدنى من هذا تنكسر الشاشاتُ ذاتُ القائمة الجانبية + الجدول: القائمةُ 240
  /// بكسلاً وحدها، والجدولُ خلفها يحتاج ما يكفي لأربعة أعمدة وأزرارِ صفّ.
  static const Size minimumSize = Size(1024, 640);

  static const Size defaultSize = Size(1360, 860);

  final File _file;
  _WindowState _state;
  Timer? _debounce;

  /// يُهيّئ النافذة ويعيدها إلى ما كانت عليه، ثم يُظهرها.
  ///
  /// الإظهارُ في النهاية لا في البداية: النافذةُ تُنشأ بحجم المحرّك الافتراضي،
  /// فلو ظهرت قبل ضبطها لَرآها المستخدم تقفز إلى مقاسها أمام عينيه.
  static Future<DesktopWindow> restoreAndShow() async {
    await windowManager.ensureInitialized();

    final file = File(
      p.join((await getApplicationSupportDirectory()).path, 'window.json'),
    );
    final state = _WindowState.read(file);
    final window = DesktopWindow._(file, state);

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: state.size ?? defaultSize,
        minimumSize: minimumSize,
        center: state.position == null,
        title: 'موسقي · ${AppConfig.label}',
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        final position = state.position;
        if (position != null) {
          await windowManager.setPosition(position);
        }

        if (state.maximized) {
          await windowManager.maximize();
        }

        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(window);

    return window;
  }

  @override
  void onWindowResized() => _remember();

  @override
  void onWindowMoved() => _remember();

  @override
  void onWindowMaximize() => _remember();

  @override
  void onWindowUnmaximize() => _remember();

  /// الكتابةُ مؤجَّلةٌ نصفَ ثانية: سحبُ حافّة النافذة يطلق عشراتِ الأحداث في
  /// الثانية، وكتابةُ ملفٍّ لكل واحدٍ منها كتابةٌ على القرص أثناء السحب.
  void _remember() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _write);
  }

  Future<void> _write() async {
    final maximized = await windowManager.isMaximized();

    // مقاسُ نافذةٍ مكبَّرة ليس مقاسَها المستعاد: لو حُفظ لَفتحت الشاشةُ التالية
    // بمقاس الشاشة كاملةً بلا تكبير، فلا يجد المستخدمُ حافّةً يسحبها.
    _state = maximized
        ? _state.copyWith(maximized: true)
        : _WindowState(
            size: await windowManager.getSize(),
            position: await windowManager.getPosition(),
            maximized: false,
          );

    try {
      await _file.writeAsString(jsonEncode(_state.toJson()));
    } on FileSystemException {
      // حالةُ نافذةٍ لم تُحفظ ليست عطباً يُبلَّغ به المستخدم.
    }
  }

  void dispose() {
    _debounce?.cancel();
    windowManager.removeListener(this);
  }
}

class _WindowState {
  const _WindowState({this.size, this.position, this.maximized = false});

  final Size? size;
  final Offset? position;
  final bool maximized;

  static _WindowState read(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final width = (json['width'] as num?)?.toDouble();
      final height = (json['height'] as num?)?.toDouble();
      final x = (json['x'] as num?)?.toDouble();
      final y = (json['y'] as num?)?.toDouble();

      return _WindowState(
        size: width == null || height == null
            ? null
            : Size(
                width.clamp(DesktopWindow.minimumSize.width, double.infinity),
                height.clamp(DesktopWindow.minimumSize.height, double.infinity),
              ),
        position: x == null || y == null ? null : Offset(x, y),
        maximized: json['maximized'] as bool? ?? false,
      );
    } on Object {
      // أوّلُ تشغيل، أو ملفٌّ مشوّه — نافذةٌ افتراضية في وسط الشاشة.
      return const _WindowState();
    }
  }

  _WindowState copyWith({bool? maximized}) => _WindowState(
        size: size,
        position: position,
        maximized: maximized ?? this.maximized,
      );

  Map<String, dynamic> toJson() => {
        'width': size?.width,
        'height': size?.height,
        'x': position?.dx,
        'y': position?.dy,
        'maximized': maximized,
      };
}
