import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mousqe_installer/mousqe_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_info.dart';
import 'windows_update.dart';

/// أين بلغ التحديث.
enum UpdateStage {
  /// لم يُسأل الخادمُ بعد، أو سُئل تلقائياً فلم يُجب (لا يُزعج صاحبَ الجهاز بخطأٍ لم يطلبه).
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// يُطابَق حجمُ الملف وبصمتُه بما نشره الخادم.
  verifying,

  /// نُزّل وتُحقّق منه، وينتظر التثبيت.
  ready,

  /// أندرويد يحتاج إذنَ «تثبيت التطبيقات غير المعروفة» لهذا التطبيق.
  needsPermission,

  /// مثبّتُ النظام مفتوح (أندرويد)، أو البرنامجُ يُغلق ليُستبدل (ويندوز).
  installing,
  failed,
}

/// كيف يصير الملفُّ المنزَّل هو التطبيقَ العامل.
enum UpdateInstallKind {
  /// APK يُسلَّم إلى مثبّت النظام ([ApkInstaller]).
  android,

  /// مجلّدُ البرنامج مضغوطاً، يُفكّ فوق المجلّد الحالي بعد إغلاقه ([startWindowsUpdate]).
  windows,
  unsupported,
}

/// تحديثُ التطبيق من داخله: يسأل الخادمَ عن إصدارٍ أحدث، وينزّله بتقدّمٍ وسرعةٍ ظاهرين ويستأنف ما
/// انقطع، ويتحقّق من بصمته، ثم يثبّته.
///
/// كائنٌ واحد لكل تطبيق يعيش ما عاش، فإغلاقُ شاشة التحديث لا يوقف تنزيلاً جارياً.
class AppUpdater extends ChangeNotifier {
  AppUpdater({
    required this.target,
    required String Function() baseUrl,
    Future<String?> Function()? deviceUuid,
    Future<InstalledVersion?> Function()? installedVersion,
    Future<Directory> Function()? workDirectory,
    Dio? dio,
    ApkInstaller installer = const ApkInstaller(),
    UpdateInstallKind? installKind,
    Future<void> Function(File archive)? applyWindowsUpdate,
    this.read,
    this.write,
    this.beforeRestart,
    bool? checkInDebug,
  }) : _baseUrl = baseUrl,
       _deviceUuid = deviceUuid,
       _installedVersion = installedVersion ?? _readInstalledVersion,
       _workDirectory = workDirectory ?? getTemporaryDirectory,
       _dio = dio ?? Dio(),
       _installer = installer,
       installKind = installKind ?? _platformKind(),
       _applyWindowsUpdate = applyWindowsUpdate ?? startWindowsUpdate,
       _checkInDebug =
           checkInDebug ?? const bool.fromEnvironment('NUZULN_UPDATE_CHECK');

  /// هدفُ التحديث على الخادم: `mobile` أو `admin_android` أو `admin_desktop`.
  final String target;

  final UpdateInstallKind installKind;

  /// حفظُ «لاحقاً» بين التشغيلات — ملفُّ تفضيلاتٍ يمرّره التطبيق (`PreferencesFile`).
  final Future<String?> Function()? read;
  final Future<void> Function(String value)? write;

  /// يُستدعى قبل أن يُغلق برنامجُ ويندوز نفسَه ليُستبدل — إغلاقُ قاعدة البيانات مثلاً.
  final Future<void> Function()? beforeRestart;

  final String Function() _baseUrl;
  final Future<String?> Function()? _deviceUuid;
  final Future<InstalledVersion?> Function() _installedVersion;
  final Future<Directory> Function() _workDirectory;
  final Dio _dio;
  final ApkInstaller _installer;
  final Future<void> Function(File archive) _applyWindowsUpdate;
  final bool _checkInDebug;

  /// ما بين سؤالين تلقائيين للخادم حين يعود التطبيقُ إلى الواجهة.
  static const Duration checkInterval = Duration(hours: 6);

  /// «لاحقاً» يؤجّل العرضَ التلقائي لإصدارٍ اختياري يوماً كاملاً.
  static const Duration snoozeFor = Duration(hours: 24);

  UpdateStage _stage = UpdateStage.idle;
  AppUpdateInfo? _info;
  InstalledVersion? _installed;
  DownloadProgress? _progress;
  String? _error;
  File? _file;
  DateTime? _lastCheck;
  CancelToken? _cancel;
  int? _snoozedBuild;
  DateTime? _snoozedUntil;

  UpdateStage get stage => _stage;
  AppUpdateInfo? get info => _info;
  InstalledVersion? get installed => _installed;
  DownloadProgress? get progress => _progress;
  String? get error => _error;

  bool get hasUpdate => _info != null;
  bool get isMandatory => _info?.mandatory ?? false;

  /// إصدارٌ إلزاميّ فات الجهاز: لا يعمل التطبيقُ حتى يُحدَّث.
  bool get blocksApp => isMandatory;

  bool get isBusy => const {
    UpdateStage.checking,
    UpdateStage.downloading,
    UpdateStage.verifying,
    UpdateStage.installing,
  }.contains(_stage);

  /// يُعرض تلقائياً: إصدارٌ اختياري متاح لم يؤجّله صاحبُ الجهاز.
  bool get shouldPrompt {
    final info = _info;

    if (info == null || info.mandatory || _stage != UpdateStage.available) {
      return false;
    }

    final until = _snoozedUntil;

    return !(_snoozedBuild == info.buildNumber &&
        until != null &&
        DateTime.now().isBefore(until));
  }

  /// يقرأ التأجيلَ المحفوظ — قبل أول سؤال.
  Future<void> load() async {
    try {
      final raw = await read?.call();

      if (raw == null || raw.isEmpty) {
        return;
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      _snoozedBuild = (json['snoozed_build'] as num?)?.toInt();
      _snoozedUntil = DateTime.tryParse(json['snoozed_until'] as String? ?? '');
    } catch (_) {
      // ملفٌّ تالف: لا تأجيل، وهو الأسلم.
    }
  }

  /// يسأل الخادم. السؤالُ التلقائي ([manual] = false) صامتٌ إن فشل، ولا يجري في نسخة التطوير
  /// إلا بـ`--dart-define=NUZULN_UPDATE_CHECK=true` — فلا يحجب تحديثٌ إلزاميّ من يطوّر التطبيق.
  Future<void> check({bool manual = false}) async {
    if (isBusy || (!manual && kDebugMode && !_checkInDebug)) {
      return;
    }

    final previous = _info;
    _stage = UpdateStage.checking;
    _error = null;
    notifyListeners();

    try {
      final installed = _installed ??= await _installedVersion();

      if (installed == null) {
        _info = null;
        _stage = UpdateStage.upToDate;
        return;
      }

      final device = await _deviceUuid?.call();
      final response = await _dio.get<dynamic>(
        '${_base()}/app-updates/check',
        queryParameters: {
          'target': target,
          'build': installed.build,
          'version': installed.version,
          if (device != null && device.isNotEmpty) 'device': device,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final body = response.data;
      final update = body is Map ? body['update'] : null;
      _info = update is Map
          ? AppUpdateInfo.fromJson(update.cast<String, dynamic>())
          : null;

      if (_info?.buildNumber != previous?.buildNumber) {
        _file = null;
        _progress = null;
      }

      _stage = switch (_info) {
        null => UpdateStage.upToDate,
        _ when _file != null => UpdateStage.ready,
        _ => UpdateStage.available,
      };
    } catch (_) {
      _info = previous;
      _stage = previous != null
          ? UpdateStage.available
          : (manual ? UpdateStage.failed : UpdateStage.idle);
      if (manual) {
        _error = 'تعذّر الوصول إلى الخادم للتحقق من التحديثات. تأكّد من الاتصال ثم أعد المحاولة.';
      }
    } finally {
      _lastCheck = DateTime.now();
      notifyListeners();
    }
  }

  /// يسأل إن مضى على آخر سؤالٍ [checkInterval].
  Future<void> checkIfStale() async {
    final last = _lastCheck;

    if (last == null || DateTime.now().difference(last) >= checkInterval) {
      await check();
    }
  }

  /// «لاحقاً»: لا يُعرض هذا الإصدار تلقائياً قبل [snoozeFor]. والإلزاميّ لا يؤجَّل.
  Future<void> snooze() async {
    final info = _info;

    if (info == null || info.mandatory) {
      return;
    }

    _snoozedBuild = info.buildNumber;
    _snoozedUntil = DateTime.now().add(snoozeFor);
    notifyListeners();

    try {
      await write?.call(
        jsonEncode({
          'snoozed_build': _snoozedBuild,
          'snoozed_until': _snoozedUntil!.toIso8601String(),
        }),
      );
    } catch (_) {
      // التأجيلُ في الذاكرة يكفي هذه الجلسة.
    }
  }

  /// ينزّل الإصدار ثم يتحقّق منه ثم يثبّته. ما انقطع يُستأنف من حيث وقف (`Range`).
  Future<void> download() async {
    final info = _info;

    if (info == null ||
        _stage == UpdateStage.downloading ||
        _stage == UpdateStage.verifying) {
      return;
    }

    _stage = UpdateStage.downloading;
    _error = null;
    _progress = DownloadProgress(received: 0, total: info.size);
    notifyListeners();

    final cancel = _cancel = CancelToken();
    RandomAccessFile? sink;

    try {
      final directory = Directory(
        '${(await _workDirectory()).path}${Platform.pathSeparator}updates',
      );
      await directory.create(recursive: true);

      final name = _fileName(info);
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      final part = File('${file.path}.part');
      await _sweep(directory, keep: {file.path, part.path});

      // ملفٌّ كاملٌ من محاولةٍ سابقة يُتحقّق منه ولا يُنزَّل ثانيةً.
      if (await file.exists()) {
        await _verifyAndInstall(file, info);
        return;
      }

      var offset = await part.exists() ? await part.length() : 0;

      final response = await _dio.get<ResponseBody>(
        _downloadUrl(info),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {if (offset > 0) 'Range': 'bytes=$offset-'},
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 45),
          validateStatus: (status) =>
              status != null && (status < 300 || status == 416),
        ),
      );

      final status = response.statusCode ?? 200;
      final length = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );

      if (status != 416) {
        // 200 بدل 206: الخادمُ (أو الرابطُ الخارجي) لا يستأنف — يبدأ الملفُّ من أوّله.
        if (status != 206) {
          offset = 0;
        }

        final total = info.size ?? (length == null ? null : offset + length);
        sink = await part.open(
          mode: offset > 0 ? FileMode.append : FileMode.write,
        );

        var received = offset;
        final meter = _SpeedMeter()..add(received);
        var shown = DateTime.fromMillisecondsSinceEpoch(0);

        await for (final chunk in response.data!.stream) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          meter.add(received);

          final now = DateTime.now();
          if (now.difference(shown) >= const Duration(milliseconds: 150)) {
            shown = now;
            _progress = DownloadProgress(
              received: received,
              total: total,
              bytesPerSecond: meter.bytesPerSecond,
            );
            notifyListeners();
          }
        }

        await sink.close();
        sink = null;
        _progress = DownloadProgress(
          received: received,
          total: total ?? received,
        );
      }

      // 416: ما طُلب بعد آخر بايتٍ عندنا لا وجود له — الجزءُ المحفوظ هو الملفُّ كلُّه.
      await part.rename(file.path);
      await _verifyAndInstall(file, info);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        _stage = UpdateStage.available;
      } else {
        _fail(_networkMessage(error));
      }
    } on FileSystemException {
      _fail(
        'تعذّر حفظ التحديث على الجهاز — تحقّق من المساحة الفارغة ثم أعد المحاولة.',
      );
    } catch (_) {
      _fail('تعذّر تنزيل التحديث. أعد المحاولة بعد قليل.');
    } finally {
      await sink?.close();
      if (identical(_cancel, cancel)) {
        _cancel = null;
      }
      notifyListeners();
    }
  }

  /// يوقف التنزيل ويُبقي ما وصل منه — «تحديث الآن» بعدها يستأنف.
  void cancel() => _cancel?.cancel();

  /// يثبّت الملفَّ المنزَّل المتحقَّق منه.
  Future<void> install() async {
    final file = _file;

    if (file == null || !await file.exists()) {
      _file = null;
      _stage = _info == null ? UpdateStage.idle : UpdateStage.available;
      notifyListeners();
      return;
    }

    switch (installKind) {
      case UpdateInstallKind.android:
        if (!await _installer.canInstall()) {
          _stage = UpdateStage.needsPermission;
          notifyListeners();
          return;
        }

        _stage = UpdateStage.installing;
        notifyListeners();

        try {
          await _installer.install(file.path);
        } catch (_) {
          _fail('تعذّر فتح مثبّت النظام. أعد المحاولة.');
          notifyListeners();
        }
      case UpdateInstallKind.windows:
        _stage = UpdateStage.installing;
        notifyListeners();

        try {
          await beforeRestart?.call();
          await _applyWindowsUpdate(file);
        } catch (_) {
          _fail('تعذّر بدء التحديث. أغلق البرنامج وافتحه ثم أعد المحاولة.');
          notifyListeners();
        }
      case UpdateInstallKind.unsupported:
        _fail('لا يدعم هذا الجهاز التحديث من داخل التطبيق.');
        notifyListeners();
    }
  }

  /// يفتح إعدادَ «تثبيت التطبيقات غير المعروفة» — والعودةُ منه تُكمل التثبيت ([onResumed]).
  Future<void> openInstallSettings() => _installer.openInstallSettings();

  /// يعود التطبيق إلى الواجهة: من إعداد الإذن، أو من مثبّتٍ أُغلق دون تثبيت، أو بعد غيابٍ طويل.
  Future<void> onResumed() async {
    switch (_stage) {
      case UpdateStage.needsPermission:
        if (await _installer.canInstall()) {
          await install();
        }
      case UpdateStage.installing when installKind == UpdateInstallKind.android:
        // لو ثُبّت التحديثُ لَما عاد هذا التطبيقُ نفسُه: المثبّتُ أُغلق دون تثبيت.
        _stage = UpdateStage.ready;
        notifyListeners();
      default:
        await checkIfStale();
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _verifyAndInstall(File file, AppUpdateInfo info) async {
    _stage = UpdateStage.verifying;
    notifyListeners();

    final size = info.size;
    if (size != null && await file.length() != size) {
      await file.delete();
      _fail('وصل الملفُّ ناقصاً. أعد المحاولة لتنزيله من جديد.');
      return;
    }

    final expected = info.sha256?.toLowerCase();
    if (expected != null && expected.isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;

      if (digest.toString() != expected) {
        await file.delete();
        _fail(
          'الملفُّ الذي وصل لا يطابق ما نُشر، فحُذف. أعد المحاولة لتنزيله من جديد.',
        );
        return;
      }
    }

    _file = file;
    _stage = UpdateStage.ready;
    notifyListeners();

    await install();
  }

  void _fail(String message) {
    _error = message;
    _stage = UpdateStage.failed;
  }

  String _base() {
    final base = _baseUrl();

    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  String _downloadUrl(AppUpdateInfo info) {
    final external = info.downloadUrl;

    return external != null && external.isNotEmpty
        ? external
        : '${_base()}/${info.downloadPath}';
  }

  String _fileName(AppUpdateInfo info) {
    final extension = installKind == UpdateInstallKind.windows ? 'zip' : 'apk';
    final given = info.fileName;
    final name = given != null && given.toLowerCase().endsWith('.$extension')
        ? given
        : 'nuzuln-$target-b${info.buildNumber}.$extension';

    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  }

  /// ملفّاتُ تحديثاتٍ سابقة لا حاجة إليها — لا تبقى تأكل مساحةَ الجهاز.
  Future<void> _sweep(Directory directory, {required Set<String> keep}) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is File && !keep.contains(entity.path)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // التنظيفُ تحسينٌ لا شرط.
    }
  }

  static String _networkMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'توقّف التنزيل لبطء الاتصال. أعد المحاولة — يُستأنف من حيث وقف.',
    DioExceptionType.badResponse =>
      'الخادم لم يُرسل ملفَّ التحديث. أعد المحاولة بعد قليل.',
    _ => 'انقطع الاتصال أثناء التنزيل. أعد المحاولة — يُستأنف من حيث وقف.',
  };

  static UpdateInstallKind _platformKind() {
    if (kIsWeb) {
      return UpdateInstallKind.unsupported;
    }

    if (Platform.isAndroid) {
      return UpdateInstallKind.android;
    }

    return Platform.isWindows
        ? UpdateInstallKind.windows
        : UpdateInstallKind.unsupported;
  }

  static Future<InstalledVersion?> _readInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber);

      return build == null
          ? null
          : InstalledVersion(version: info.version, build: build);
    } catch (_) {
      return null;
    }
  }
}

/// السرعةُ في الثواني الثلاث الأخيرة لا منذ البداية: ما يراه صاحبُ الجهاز سرعةُ شبكته الآن.
class _SpeedMeter {
  final List<(DateTime, int)> _samples = [];

  static const Duration _window = Duration(seconds: 3);

  void add(int received) {
    final now = DateTime.now();
    _samples.add((now, received));
    _samples.removeWhere((sample) => now.difference(sample.$1) > _window);
  }

  double get bytesPerSecond {
    if (_samples.length < 2) {
      return 0;
    }

    final (startedAt, startBytes) = _samples.first;
    final (endedAt, endBytes) = _samples.last;
    final seconds = endedAt.difference(startedAt).inMicroseconds / 1e6;

    return seconds <= 0 ? 0 : (endBytes - startBytes) / seconds;
  }
}
