import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// ملفُّ تفضيلاتٍ صغير على الجهاز (المظهر…) — خارج قاعدة drift عمداً: الخروجُ يمسح بياناتِ الحساب
/// (`clearAll`)، والوضعُ وحجمُ الخط لصاحب الجهاز لا للحساب.
class PreferencesFile {
  PreferencesFile(this.name);

  final String name;

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();

    return File('${directory.path}${Platform.pathSeparator}$name');
  }

  /// محتواه، أو `null` إن لم يُكتب بعد أو تعذّرت قراءتُه.
  Future<String?> read() async {
    try {
      final file = await _file();

      return await file.exists() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  }
}
