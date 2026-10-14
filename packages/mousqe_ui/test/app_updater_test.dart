import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_installer/mousqe_installer.dart';
import 'package:mousqe_ui/mousqe_ui.dart';
import 'package:mousqe_ui/src/update/windows_update.dart';

/// خادمٌ مزيّف: يجيب `check` بما في [update]، ويخدم الملفَّ [file] مع دعم `Range`.
class _FakeServer implements HttpClientAdapter {
  Map<String, dynamic>? update;
  List<int> file = const [];
  bool supportsRange = true;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path.endsWith('/app-updates/check')) {
      return ResponseBody.fromString(
        jsonEncode({'update': update}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final range = options.headers['Range'] as String?;
    final from = range == null || !supportsRange
        ? 0
        : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    final bytes = Uint8List.fromList(file.sublist(from));

    return ResponseBody.fromBytes(
      bytes,
      from > 0 ? 206 : 200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeInstaller extends ApkInstaller {
  bool allowed = true;
  final List<String> installed = [];

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<bool> openInstallSettings() async => true;

  @override
  Future<void> install(String path) async => installed.add(path);
}

Map<String, dynamic> _update({
  int build = 6,
  bool mandatory = false,
  List<int>? file,
  String? sha,
}) => {
  'uuid': '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b',
  'version': '1.0.0-beta.$build',
  'build_number': build,
  'title': 'التفقّد أسرع',
  'mandatory': mandatory,
  'published_at': '2026-10-14T10:00:00+03:00',
  'file_name': 'nuzuln-mobile-1.0.0-beta.$build-b$build.apk',
  'size': file?.length,
  'sha256': sha ?? (file == null ? null : sha256.convert(file).toString()),
  'download_url': null,
  'download_path': 'app-updates/0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b/download',
  'changes': [
    {
      'version': '1.0.0-beta.$build',
      'build_number': build,
      'title': 'التفقّد أسرع',
      'mandatory': mandatory,
      'notes': ['شريط المزامنة أصغر', 'إصلاح الدخول'],
      'published_at': '2026-10-14T10:00:00+03:00',
    },
  ],
};

void main() {
  late Directory work;
  late _FakeServer server;
  late _FakeInstaller installer;
  String? saved;

  AppUpdater updater({UpdateInstallKind kind = UpdateInstallKind.android}) {
    final dio = Dio()..httpClientAdapter = server;

    return AppUpdater(
      target: 'mobile',
      baseUrl: () => 'https://nuzuln.test/api/v1',
      deviceUuid: () async => '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a50',
      installedVersion: () async =>
          const InstalledVersion(version: '1.0.0-beta.5', build: 5),
      workDirectory: () async => work,
      dio: dio,
      installer: installer,
      installKind: kind,
      read: () async => saved,
      write: (value) async => saved = value,
    );
  }

  setUp(() async {
    work = await Directory.systemTemp.createTemp('nuzuln-update-test');
    server = _FakeServer();
    installer = _FakeInstaller();
    saved = null;
  });

  tearDown(() async {
    if (await work.exists()) {
      await work.delete(recursive: true);
    }
  });

  group('check', () {
    test(
      'reports the installed build and device, and finds the update',
      () async {
        server.update = _update();
        final subject = updater();

        await subject.check(manual: true);

        expect(subject.stage, UpdateStage.available);
        expect(subject.info!.version, '1.0.0-beta.6');
        expect(subject.info!.changes.single.notes, [
          'شريط المزامنة أصغر',
          'إصلاح الدخول',
        ]);
        expect(subject.shouldPrompt, isTrue);
        expect(subject.blocksApp, isFalse);

        final query = server.requests.single.queryParameters;
        expect(query['target'], 'mobile');
        expect(query['build'], 5);
        expect(query['device'], '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a50');
      },
    );

    test('says up to date when the server has nothing newer', () async {
      final subject = updater();

      await subject.check(manual: true);

      expect(subject.stage, UpdateStage.upToDate);
      expect(subject.hasUpdate, isFalse);
    });

    test(
      'a mandatory update blocks the app and is never prompted as optional',
      () async {
        server.update = _update(mandatory: true);
        final subject = updater();

        await subject.check(manual: true);

        expect(subject.blocksApp, isTrue);
        expect(subject.shouldPrompt, isFalse);
      },
    );

    test('later hides an optional update for a day, across launches', () async {
      server.update = _update();
      final subject = updater();
      await subject.check(manual: true);

      await subject.snooze();
      expect(subject.shouldPrompt, isFalse);

      final relaunched = updater();
      await relaunched.load();
      await relaunched.check(manual: true);
      expect(relaunched.shouldPrompt, isFalse);

      // إصدارٌ أحدث من المؤجَّل يُعرض.
      server.update = _update(build: 7);
      await relaunched.check(manual: true);
      expect(relaunched.shouldPrompt, isTrue);
    });

    test(
      'an automatic check stays quiet when the server is unreachable',
      () async {
        final dio = Dio()..httpClientAdapter = _ThrowingAdapter();
        final subject = AppUpdater(
          target: 'mobile',
          baseUrl: () => 'https://nuzuln.test/api/v1',
          installedVersion: () async =>
              const InstalledVersion(version: '1', build: 5),
          dio: dio,
          installKind: UpdateInstallKind.android,
          checkInDebug: true,
        );

        await subject.check();
        expect(subject.stage, UpdateStage.idle);
        expect(subject.error, isNull);

        await subject.check(manual: true);
        expect(subject.stage, UpdateStage.failed);
        expect(subject.error, isNotNull);
      },
    );
  });

  group('download', () {
    final bytes = List<int>.generate(200000, (index) => index % 251);

    test('downloads, verifies the hash and opens the installer', () async {
      server
        ..update = _update(file: bytes)
        ..file = bytes;
      final subject = updater();
      await subject.check(manual: true);

      await subject.download();

      expect(subject.stage, UpdateStage.installing);
      expect(installer.installed, hasLength(1));
      expect(await File(installer.installed.single).readAsBytes(), bytes);
      expect(
        installer.installed.single,
        endsWith('nuzuln-mobile-1.0.0-beta.6-b6.apk'),
      );
      expect(
        server.requests.last.uri.toString(),
        'https://nuzuln.test/api/v1/app-updates/0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b/download',
      );
    });

    test('resumes a partial download with a Range request', () async {
      server
        ..update = _update(file: bytes)
        ..file = bytes;
      final subject = updater();
      await subject.check(manual: true);

      final folder = Directory('${work.path}${Platform.pathSeparator}updates')
        ..createSync();
      File(
        '${folder.path}${Platform.pathSeparator}nuzuln-mobile-1.0.0-beta.6-b6.apk.part',
      ).writeAsBytesSync(bytes.sublist(0, 80000));

      await subject.download();

      expect(server.requests.last.headers['Range'], 'bytes=80000-');
      expect(await File(installer.installed.single).readAsBytes(), bytes);
    });

    test('starts over when the server ignores the range', () async {
      server
        ..update = _update(file: bytes)
        ..file = bytes
        ..supportsRange = false;
      final subject = updater();
      await subject.check(manual: true);

      final folder = Directory('${work.path}${Platform.pathSeparator}updates')
        ..createSync();
      File(
        '${folder.path}${Platform.pathSeparator}nuzuln-mobile-1.0.0-beta.6-b6.apk.part',
      ).writeAsBytesSync(List.filled(500, 7));

      await subject.download();

      expect(await File(installer.installed.single).readAsBytes(), bytes);
    });

    test(
      'a file that does not match the published hash is deleted, not installed',
      () async {
        server
          ..update = _update(file: bytes, sha: 'ab' * 32)
          ..file = bytes;
        final subject = updater();
        await subject.check(manual: true);

        await subject.download();

        expect(subject.stage, UpdateStage.failed);
        expect(installer.installed, isEmpty);
        expect(
          Directory('${work.path}${Platform.pathSeparator}updates').listSync(),
          isEmpty,
        );
      },
    );

    test('asks for the install permission, then installs on return', () async {
      installer.allowed = false;
      server
        ..update = _update(file: bytes)
        ..file = bytes;
      final subject = updater();
      await subject.check(manual: true);

      await subject.download();
      expect(subject.stage, UpdateStage.needsPermission);
      expect(installer.installed, isEmpty);

      installer.allowed = true;
      await subject.onResumed();
      expect(installer.installed, hasLength(1));

      // رجع من المثبّت دون تثبيت: يبقى جاهزاً ليُعاد فتحُ المثبّت.
      await subject.onResumed();
      expect(subject.stage, UpdateStage.ready);
    });

    test('windows hands the archive to the self-update', () async {
      final applied = <String>[];
      server
        ..update = (_update(file: bytes)
          ..['file_name'] = 'nuzuln-admin-desktop-1.0.0-b6-windows.zip')
        ..file = bytes;
      final subject = AppUpdater(
        target: 'admin_desktop',
        baseUrl: () => 'https://nuzuln.test/api/v1',
        installedVersion: () async =>
            const InstalledVersion(version: '1.0.0', build: 5),
        workDirectory: () async => work,
        dio: Dio()..httpClientAdapter = server,
        installKind: UpdateInstallKind.windows,
        applyWindowsUpdate: (archive) async => applied.add(archive.path),
      );
      await subject.check(manual: true);

      await subject.download();

      expect(
        applied.single,
        endsWith('nuzuln-admin-desktop-1.0.0-b6-windows.zip'),
      );
    });
  });

  test('the windows script quotes paths and relaunches the program', () {
    final script = windowsUpdateScript(
      archive: r"C:\Users\O'Neil\AppData\Local\Temp\updates\a.zip",
      staging: r'C:\Temp\staged',
      appDirectory: r'C:\Programs\نزلاً',
      executable: r'C:\Programs\نزلاً\mousqe_admin_desktop.exe',
      log: r'C:\Temp\update.log',
      processId: 4242,
    );

    expect(
      script,
      contains(
        r"$archive = 'C:\Users\O''Neil\AppData\Local\Temp\updates\a.zip'",
      ),
    );
    expect(script, contains(r'$processId = 4242'));
    expect(script, contains('robocopy'));
    expect(script, contains(r'Start-Process -FilePath $exe'));
  });

  test('progress knows its fraction and remaining time', () {
    const progress = DownloadProgress(
      received: 25,
      total: 100,
      bytesPerSecond: 5,
    );

    expect(progress.fraction, 0.25);
    expect(progress.remaining, const Duration(seconds: 15));
    expect(const DownloadProgress(received: 1).fraction, isNull);
  });

  group('screen', () {
    Widget host(AppUpdater subject, {Widget? child}) => MousqeApp(
      theme: MousqeTheme.light(),
      home: AppUpdateScope(
        updater: subject,
        appName: 'نزلاً',
        child: child ?? UpdateScreen(updater: subject),
      ),
    );

    testWidgets('shows the changes and both choices for an optional update', (
      tester,
    ) async {
      server.update = _update(file: [1, 2, 3]);
      final subject = updater();
      await tester.runAsync(() => subject.check(manual: true));

      await tester.pumpWidget(host(subject));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('تحديث التطبيق'), findsOneWidget);
      expect(find.text('التفقّد أسرع'), findsOneWidget);
      expect(find.text('شريط المزامنة أصغر'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
      expect(find.text('تحديث إلزامي'), findsNothing);
    });

    testWidgets('a mandatory update replaces the app and cannot be put off', (
      tester,
    ) async {
      server.update = _update(mandatory: true);
      final subject = updater();
      await tester.runAsync(() => subject.check(manual: true));

      await tester.pumpWidget(
        host(subject, child: const UpdateGate(child: Text('الرئيسية'))),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('الرئيسية'), findsNothing);
      expect(find.text('تحديث إلزامي'), findsOneWidget);
      expect(find.text('لاحقاً'), findsNothing);
      expect(find.byTooltip('إغلاق'), findsNothing);
    });

    testWidgets('the download shows its percentage on thirty strokes', (
      tester,
    ) async {
      final file = List<int>.filled(100, 1);
      final stalled = _StalledServer(
        update: _update(file: file),
        size: file.length,
      );
      final subject = AppUpdater(
        target: 'mobile',
        baseUrl: () => 'https://nuzuln.test/api/v1',
        installedVersion: () async =>
            const InstalledVersion(version: '1.0.0-beta.5', build: 5),
        workDirectory: () async => work,
        dio: Dio()..httpClientAdapter = stalled,
        installer: installer,
        installKind: UpdateInstallKind.android,
      );
      await tester.runAsync(() => subject.check(manual: true));

      await tester.pumpWidget(host(subject));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DownloadStrokes), findsNothing);

      // نصفُ الملف ثم يسكت الخادم: التنزيلُ قائمٌ عند 50%.
      late Future<void> pending;
      await tester.runAsync(() async {
        pending = subject.download();
        stalled.body.add(Uint8List(50));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 400));

      expect(subject.stage, UpdateStage.downloading);
      expect(find.byType(DownloadStrokes), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('إيقاف مؤقّت'), findsOneWidget);

      // الإيقافُ يُبقي ما وصل ويعيد «تحديث الآن».
      await tester.runAsync(() async {
        subject.cancel();
        await stalled.body.close();
        await pending;
      });
      await tester.pump(const Duration(milliseconds: 400));

      expect(subject.stage, UpdateStage.available);
      expect(find.text('تحديث الآن'), findsOneWidget);
    });
  });
}

/// يجيب `check`، ثم يفتح التنزيلَ ويُرسل منه ما يُضاف إلى [body] فقط.
class _StalledServer implements HttpClientAdapter {
  _StalledServer({required this.update, required this.size});

  final Map<String, dynamic> update;
  final int size;
  final StreamController<Uint8List> body = StreamController<Uint8List>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/app-updates/check')) {
      return ResponseBody.fromString(
        jsonEncode({'update': update}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody(
      body.stream,
      200,
      headers: {
        Headers.contentLengthHeader: ['$size'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}
