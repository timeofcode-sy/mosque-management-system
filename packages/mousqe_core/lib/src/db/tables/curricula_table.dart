import 'package:drift/drift.dart';

/// نظير جدول `curricula` الخادمي — ✅ م.6.5.
///
/// و`instituteId` فارغٌ للمزروع عامّاً (القرآن والحديث والمتون)، كما في
/// [PersonalTraits]. والفرقُ في الحكم لا في الرؤية: العامُّ يُرى ولا يُحرَّر
/// وعاؤه — `SaveCurriculum` على الخادم يرفضه.
@DataClassName('CurriculumRow')
class Curricula extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get slug => text()();
  TextColumn get type => text().withDefault(const Constant('custom'))();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
