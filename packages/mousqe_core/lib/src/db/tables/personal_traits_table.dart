import 'package:drift/drift.dart';

/// نظير جدول `traits` الخادمي — ✅ م.6.5. والاسمُ هنا `personal_traits` لأن
/// `traits` كلمةٌ محجوزة في Dart كما هي في PHP — نفسُ سبب `PersonalTrait`.
///
/// و`instituteId` **قد يكون فارغاً**: الصفاتُ التسع مزروعةٌ عامةً لكل المعاهد،
/// ولكل معهدٍ أن يضيف صفاته. فالاستمارةُ تعرض العامَّ ومعهدَها معاً.
@DataClassName('PersonalTraitRow')
class PersonalTraits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get instituteId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get slug => text()();
  TextColumn get polarity => text().withDefault(const Constant('neutral'))();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  String get tableName => 'personal_traits';
}
