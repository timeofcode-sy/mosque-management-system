import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// تفضيلُ طيّ القائمة الجانبية — يُحفظ في ملفٍّ صغير بجانب بيانات التطبيق فيعود كما تركه المشرف.
///
/// لا `shared_preferences` هنا عمداً: تفضيلٌ واحد لا يستحق اعتماداً جديداً. وأيُّ فشلٍ في القراءة
/// أو الكتابة (بيئةُ اختبار، قرصٌ ممتلئ) يُبتلع: الواجهةُ تعمل بالافتراضي ولا تسقط من أجل تفضيل.
class SidebarPrefs {
  const SidebarPrefs._();

  static const _fileName = 'nuzuln_ui.json';
  static const _key = 'sidebar_collapsed';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();

    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<bool> loadCollapsed() async {
    try {
      final file = await _file();

      if (!await file.exists()) {
        return false;
      }

      final json = jsonDecode(await file.readAsString());

      return json is Map && json[_key] == true;
    } on Object {
      return false;
    }
  }

  static Future<void> saveCollapsed(bool collapsed) async {
    try {
      final file = await _file();

      await file.writeAsString(jsonEncode({_key: collapsed}));
    } on Object {
      // التفضيلُ لا يستحق خطأً يراه المستخدم.
    }
  }
}
