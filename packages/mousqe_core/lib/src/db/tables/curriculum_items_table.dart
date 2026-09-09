import 'package:drift/drift.dart';

/// نظير جدول `curriculum_items` الخادمي — ✅ م.6.5.
///
/// و`meta` نصُّ JSON كما يصل: فيه `hadiths` لبنود الحديث و`abyat` للمتون
/// و`juz` لأجزاء القرآن — عدّاداتٌ تُشتقّ منها النقاط (م.4.5)، ومفتاحُها يتبع
/// نوعَ المنهج فلا يُفكّ إلى أعمدة.
@DataClassName('CurriculumItemRow')
class CurriculumItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get curriculumId => integer()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get meta => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
