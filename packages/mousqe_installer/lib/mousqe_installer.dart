import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// مثبّتُ أندرويد: يسلّم ملفَّ APK نزّله التطبيقُ إلى مثبّت النظام.
///
/// التطبيقُ المثبَّت من خارج المتجر لا يحدّث نفسَه صامتاً: يعرض أندرويد تأكيدَه، ويسأل قبلها
/// مرّةً عن إذن «تثبيت التطبيقات غير المعروفة» لهذا التطبيق ([canInstall]، [openInstallSettings]).
/// وعلى غير أندرويد كلُّها لا تفعل شيئاً — ويندوز يُحدَّث بنصٍّ في التطبيق نفسه.
class ApkInstaller {
  const ApkInstaller();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.timeofcode.nuzuln/installer',
  );

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// هل يحقّ للتطبيق أن يطلب تثبيتَ حزمة؟ (أندرويد 8 فما فوق يسأل لكل تطبيق.)
  Future<bool> canInstall() async {
    if (!_supported) {
      return false;
    }

    return await channel.invokeMethod<bool>('canInstall') ?? false;
  }

  /// يفتح إعدادَ «تثبيت التطبيقات غير المعروفة» لهذا التطبيق.
  Future<bool> openInstallSettings() async {
    if (!_supported) {
      return false;
    }

    return await channel.invokeMethod<bool>('openInstallSettings') ?? false;
  }

  /// يفتح مثبّتَ النظام على [path] — ملفٌّ في مجلّد `updates/` داخل ذاكرة التطبيق المؤقتة
  /// (`getTemporaryDirectory()`)، وهو وحده ما يشاركه مزوّدُ الملفات.
  Future<void> install(String path) async {
    if (!_supported) {
      throw UnsupportedError('التثبيت من داخل التطبيق على أندرويد وحده.');
    }

    await channel.invokeMethod<bool>('install', {'path': path});
  }
}
