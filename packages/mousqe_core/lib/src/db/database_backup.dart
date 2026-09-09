import 'dart:io';

import 'package:path/path.dart' as p;

import 'database.dart';

/// نسخةٌ احتياطية محلية من ملفّ drift — ✅ م.6.6.
///
/// ### 🔑 لماذا `VACUUM INTO` لا نسخُ الملفّ؟
///
/// الاتصالُ مفتوحٌ والتطبيقُ يعمل، فنسخُ `mousqe_admin.sqlite` بـ`File.copy`
/// يلتقط قاعدةً **في منتصف معاملة**: صفحاتٌ في سجلّ الكتابة المسبقة (WAL) لم
/// تُدمَج بعد، فتخرج نسخةٌ تُفتح ثم تشكو من تلفٍ لا يظهر إلا حين يُحتاج إليها —
/// وهو أسوأُ أنواع النسخ الاحتياطي: نسخةٌ يظنّها صاحبُها موجودة.
///
/// و`VACUUM INTO` يكتب **لقطةً متّسقة** من داخل المحرّك نفسِه: يحترم المعاملات،
/// ويدمج WAL، ويخرج بملفٍّ مضغوطٍ يُفتح وحده.
///
/// ### 🔑 وما الذي تُنقذه هذه النسخة أصلاً؟
///
/// **ليست مصدرَ الحقيقة، ولا يُستعاد منها المعهد.** مخزنُ drift مرآةُ تيّارٍ
/// يُبثّ من الخادم ([ARCHITECTURE.md §5](../../../../../docs/ARCHITECTURE.md))،
/// فاستعادةُ لقطةٍ قديمة فوقه تعني مؤشّرَ سحبٍ يشير إلى ماضٍ ومخزناً يخالف
/// الخادم — وطريقُ الإصلاح الصحيح لِما فسد هو **المسحُ وإعادةُ السحب**، وثمنُه
/// دورةٌ واحدة كما في تبديل المعهد (م.6.3).
///
/// فما تحفظه هذه النسخة شيءٌ واحدٌ لا يملكه غيرُها: **`pending_operations`** —
/// كتاباتٌ صفّها صاحبُ الجهاز ولم تصل الخادمَ بعد. جهازٌ يُسرَق أو قرصٌ يعطب
/// وفي طابوره تفقّدُ ثلاثة أيام يفقدها بلا رجعة، لأنها ليست في أيّ مكانٍ آخر.
/// ولذلك تقول شاشتُها كم في الطابور قبل أن تنسخ، **ولذلك لا زرَّ «استعادة»**:
/// ما يُستعاد يُقرأ منه لا يُكتب فوقه.
class DatabaseBackup {
  const DatabaseBackup._();

  /// امتدادٌ خاصّ لا `.sqlite`: نسخةٌ في مجلّد المستخدم يجب أن تُقرأ على أنها
  /// نسخةٌ لا قاعدةٌ عاملة، فلا يفتحها أحدٌ ظانّاً أنه يفتح مخزنَ التطبيق.
  static const extension = '.mousqe-backup.sqlite';

  /// يكتب لقطةً في [directory] ويعيد ملفَّها.
  ///
  /// والاسمُ زمنيّ بالدقيقة — فلا نسخةٌ تدهس أختَها، ولا `VACUUM INTO` يسقط لأن
  /// الهدفَ موجود (وهو يرفض الكتابةَ فوق ملفٍّ قائم).
  static Future<File> write(
    AppDatabase db, {
    required Directory directory,
    DateTime? at,
  }) async {
    await directory.create(recursive: true);

    final file = File(p.join(directory.path, nameFor(at ?? DateTime.now())));

    // المسارُ يُمرَّر متغيّراً لا مُدرَجاً في النصّ: مسارُ ويندوز فيه شرطاتٌ
    // مائلة وقد يحمل فاصلةً عليا في اسم المستخدم.
    await db.customStatement('VACUUM INTO ?', [file.path]);

    return file;
  }

  /// النسخُ الموجودة في [directory]، **الأحدثُ أوّلاً** — لا يعنيها ما عداها.
  static Future<List<File>> list(Directory directory) async {
    if (!directory.existsSync()) {
      return const [];
    }

    final files = [
      for (final entity in directory.listSync())
        if (entity is File && entity.path.endsWith(extension)) entity,
    ];

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    return files;
  }

  static String nameFor(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');

    return 'mousqe-${at.year}-${two(at.month)}-${two(at.day)}'
        '-${two(at.hour)}${two(at.minute)}$extension';
  }
}
