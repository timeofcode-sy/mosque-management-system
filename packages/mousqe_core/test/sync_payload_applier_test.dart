import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mousqe_core/src/db/database.dart';
import 'package:mousqe_core/src/sync/sync_payload_applier.dart';

void main() {
  late AppDatabase db;
  late SyncPayloadApplier applier;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = SyncPayloadApplier(db);
  });

  tearDown(() => db.close());

  test('create inserts a new row matched by uuid', () async {
    await applier.apply(
      tableName: 'students',
      operation: 'create',
      rowUuid: 'stu-1',
      payload: {
        'uuid': 'stu-1',
        'institute_id': 1,
        'registration_no': '1001',
        'photo_path': null,
        'first_name': 'محمد',
        'father_name': 'خالد',
        'family_name': 'المصري',
        'status': 'active',
      },
    );

    final row = await (db.select(db.students)..where((t) => t.uuid.equals('stu-1'))).getSingle();
    expect(row.firstName, 'محمد');
    expect(row.instituteId, 1);
  });

  test('update on an existing uuid replaces the row not duplicates it', () async {
    final payload = {
      'uuid': 'stu-1',
      'institute_id': 1,
      'registration_no': '1001',
      'photo_path': null,
      'first_name': 'محمد',
      'father_name': 'خالد',
      'family_name': 'المصري',
      'status': 'active',
    };
    await applier.apply(tableName: 'students', operation: 'create', rowUuid: 'stu-1', payload: payload);

    await applier.apply(
      tableName: 'students',
      operation: 'update',
      rowUuid: 'stu-1',
      payload: {...payload, 'status': 'inactive'},
    );

    final rows = await db.select(db.students).get();
    expect(rows, hasLength(1));
    expect(rows.single.status, 'inactive');
  });

  test('delete removes the row matched by uuid with no payload', () async {
    await applier.apply(
      tableName: 'students',
      operation: 'create',
      rowUuid: 'stu-1',
      payload: {
        'uuid': 'stu-1',
        'institute_id': 1,
        'registration_no': '1001',
        'photo_path': null,
        'first_name': 'محمد',
        'father_name': 'خالد',
        'family_name': 'المصري',
        'status': 'active',
      },
    );

    await applier.apply(tableName: 'students', operation: 'delete', rowUuid: 'stu-1');

    final rows = await db.select(db.students).get();
    expect(rows, isEmpty);
  });
}
