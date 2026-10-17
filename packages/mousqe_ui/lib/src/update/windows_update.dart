import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// يحدّث برنامجَ ويندوز بنفسه: البرنامجُ لا يستبدل ملفّاتٍ يعمل منها، فيكتب نصّاً (PowerShell)
/// ينتظر خروجَه، ويفكّ الأرشيفَ فوق مجلّده، ثم يعيد تشغيله — ويخرج.
///
/// مجلّدٌ لا يُكتب فيه دون صلاحية (Program Files) يطلب النصُّ له صلاحيةَ المسؤول مرّةً، ثم يعيد
/// البرنامجَ بصلاحية صاحبه لا بصلاحية المسؤول. وأيُّ فشلٍ يعيد تشغيلَ النسخة القديمة كما هي،
/// ويُكتب سببُه في `update.log` بجانب الأرشيف.
Future<void> startWindowsUpdate(File archive) async {
  final executable = Platform.resolvedExecutable;
  final work = archive.parent.path;
  final script = File('$work${Platform.pathSeparator}apply-update.ps1');

  // بعلامة BOM: PowerShell 5.1 يقرأ ملفّاً بلا علامة بترميز النظام، فيُفسد مساراً عربياً
  // (مجلّدُ مستخدمٍ اسمُه عربي).
  await script.writeAsBytes([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(
      windowsUpdateScript(
        archive: archive.path,
        staging: '$work${Platform.pathSeparator}staged',
        appDirectory: File(executable).parent.path,
        executable: executable,
        log: '$work${Platform.pathSeparator}update.log',
        processId: pid,
      ),
    ),
  ]);

  await Process.start('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-WindowStyle',
    'Hidden',
    '-File',
    script.path,
  ], mode: ProcessStartMode.detached);

  exit(0);
}

/// نصُّ التحديث — منفصلٌ ليُختبر نصُّه دون تشغيله.
@visibleForTesting
String windowsUpdateScript({
  required String archive,
  required String staging,
  required String appDirectory,
  required String executable,
  required String log,
  required int processId,
}) {
  String quote(String value) => "'${value.replaceAll("'", "''")}'";

  return '''
\$ErrorActionPreference = 'Stop'
\$archive = ${quote(archive)}
\$staging = ${quote(staging)}
\$appDir = ${quote(appDirectory)}
\$exe = ${quote(executable)}
\$log = ${quote(log)}
\$processId = $processId

function Test-Writable([string]\$dir) {
    try {
        \$probe = Join-Path \$dir ('.nuzuln-write-' + [guid]::NewGuid())
        [IO.File]::WriteAllText(\$probe, '')
        Remove-Item -LiteralPath \$probe -Force
        return \$true
    } catch { return \$false }
}

\$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
\$admin = ([Security.Principal.WindowsPrincipal]\$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not (Test-Writable \$appDir) -and -not \$admin) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f \$PSCommandPath)
    exit
}

try {
    Wait-Process -Id \$processId -Timeout 60 -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 700

    if (Test-Path -LiteralPath \$staging) { Remove-Item -LiteralPath \$staging -Recurse -Force }
    Expand-Archive -LiteralPath \$archive -DestinationPath \$staging -Force

    # The archive holds the program folder's contents, or that folder itself.
    \$exeName = Split-Path \$exe -Leaf
    \$source = \$staging
    if (-not (Test-Path -LiteralPath (Join-Path \$source \$exeName))) {
        \$inner = Get-ChildItem -LiteralPath \$staging -Directory | Where-Object { Test-Path -LiteralPath (Join-Path \$_.FullName \$exeName) } | Select-Object -First 1
        if (-not \$inner) { throw "The archive does not contain \$exeName." }
        \$source = \$inner.FullName
    }

    robocopy \$source \$appDir /E /R:10 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if (\$LASTEXITCODE -ge 8) { throw "robocopy failed with exit code \$LASTEXITCODE." }

    Remove-Item -LiteralPath \$staging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath \$archive -Force -ErrorAction SilentlyContinue
    ('updated ' + (Get-Date -Format o)) | Set-Content -LiteralPath \$log -Encoding UTF8
} catch {
    ('failed ' + (Get-Date -Format o) + ' ' + \$_.Exception.Message) | Set-Content -LiteralPath \$log -Encoding UTF8
}

# Back with the owner's rights, not the administrator's: explorer starts it unelevated.
if (\$admin) {
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f \$exe)
} else {
    Start-Process -FilePath \$exe
}
''';
}
