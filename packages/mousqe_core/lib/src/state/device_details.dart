import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// وصفُ الجهاز الذي يُرسَل مع تسجيله — لإحصاءات المطوّر في «الأجهزة المزامِنة».
///
/// نوعُه وصانعُه وطرازُه ونسخةُ نظامه ومقاسُ شاشته ونسخةُ التطبيق: ما يكفي لمعرفة
/// أيِّ الأجهزة يحمل التطبيق وأيِّ نسخ أندرويد يجب أن تبقى مدعومة. **ولا شيءَ يعرّف
/// صاحبَه**: لا اسمُ الحاسوب ولا اسمُ المستخدم ولا معرّفُ العتاد.
///
/// وكلُّ حقلٍ محاولة: ما تعذّرت قراءتُه يُترك، والتسجيلُ لا يسقط بسببه.
class DeviceDetails {
  const DeviceDetails._();

  static Future<Map<String, Object?>> collect() async {
    final details = <String, Object?>{
      'platform': Platform.operatingSystem,
      'device_type': _deviceType(),
      'screen': _screen(),
      'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
    };

    try {
      final package = await PackageInfo.fromPlatform();
      details['app_version'] = package.version;
      details['app_build'] = int.tryParse(package.buildNumber);
    } on Object {
      // نسخةٌ مجهولة خيرٌ من تسجيلٍ لا يتمّ.
    }

    try {
      details.addAll(await _hardware());
    } on Object {
      // كما فوق: الوصفُ تكميلٌ لا شرط.
    }

    details.removeWhere((_, value) => value == null || value == '');

    return details;
  }

  static Future<Map<String, Object?>> _hardware() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;

      return {
        'manufacturer': info.manufacturer,
        'brand': info.brand,
        'model': info.model,
        'os_version': 'Android ${info.version.release}',
        'sdk_int': info.version.sdkInt,
        'is_physical': info.isPhysicalDevice,
      };
    }

    if (Platform.isIOS) {
      final info = await plugin.iosInfo;

      return {
        'manufacturer': 'Apple',
        'model': info.utsname.machine,
        'os_version': '${info.systemName} ${info.systemVersion}',
        'is_physical': info.isPhysicalDevice,
      };
    }

    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;

      return {
        'model': info.productName,
        'os_version': [
          'Windows',
          if (info.displayVersion.isNotEmpty) info.displayVersion,
          '(${info.buildNumber})',
        ].join(' '),
        'memory_mb': info.systemMemoryInMegabytes,
      };
    }

    return const {};
  }

  /// `phone` · `tablet` · `desktop` — والفاصلُ أقصرُ أضلاع الشاشة: 600dp كما في Material.
  static String _deviceType() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return 'desktop';
    }

    final display = PlatformDispatcher.instance.displays.firstOrNull;

    if (display == null || display.devicePixelRatio == 0) {
      return 'phone';
    }

    final size = display.size / display.devicePixelRatio;

    return size.shortestSide >= 600 ? 'tablet' : 'phone';
  }

  /// `411x914` بالنقاط المنطقية — أصغرُ الضلعين أولاً، فلا يتغيّر بتدوير الجهاز.
  static String? _screen() {
    final display = PlatformDispatcher.instance.displays.firstOrNull;

    if (display == null || display.devicePixelRatio == 0) {
      return null;
    }

    final size = display.size / display.devicePixelRatio;

    return '${size.shortestSide.round()}x${size.longestSide.round()}';
  }
}
