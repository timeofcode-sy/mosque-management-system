import 'package:drift/drift.dart';

import '../api/api_client.dart';
import '../db/database.dart';
import '../models/admin_user.dart';
import 'admin_views.dart';

/// ما كان في لوحة الويب وحدها: الأساتذةُ والإعلاناتُ والواصفاتُ المخصّصة والصفات.
///
/// على تركيب [CatalogRepository] نفسِه: الأساتذةُ والواصفاتُ والصفاتُ جداولُ
/// تُزامَن فتُقرأ من drift، والكتابةُ كلُّها REST يعود أثرُها في `sync/pull`.
/// والإعلاناتُ وحدها لا تصل الإدارةَ في التيّار، فتُقرأ من الشبكة.
class InstituteContentRepository {
  InstituteContentRepository({required AppDatabase db, required ApiClient apiClient})
      : _db = db,
        _api = apiClient;

  final AppDatabase _db;

  final ApiClient _api;

  // ---------------------------------------------------------------- الأساتذة

  Future<List<TeacherEntry>> loadTeachers() async {
    final teachers = await (_db.select(_db.teachers)
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .get();

    return [
      for (final teacher in teachers)
        TeacherEntry(
          uuid: teacher.uuid,
          displayName: teacher.displayName,
          phone: teacher.phone,
          status: teacher.status,
        ),
    ];
  }

  Stream<List<TeacherEntry>> watchTeachers() => _watch(loadTeachers);

  /// الحمولةُ الجزئية لا تمسح ما قبلها: الخادمُ يحدّث الحقولَ المرسَلة وحدها،
  /// فما تحرّره اللوحةُ وحدها (المؤهّلُ والعنوان…) يبقى كما هو.
  Future<void> saveTeacher({
    String? uuid,
    required String displayName,
    String? phone,
    required String status,
  }) {
    final body = <String, dynamic>{
      'display_name': displayName,
      'phone': phone,
      'status': status,
    };

    return uuid == null ? _api.storeTeacher(body) : _api.updateTeacher(uuid, body);
  }

  Future<void> deleteTeacher(String uuid) => _api.deleteTeacher(uuid);

  /// حسابٌ لأستاذٍ بلا حساب — وكلمتُه تعود مرّةً واحدة.
  Future<IssuedCredentials> generateTeacherAccount(String uuid) async {
    final response = await _api.teacherAccount(uuid);
    final body = response.data;

    return IssuedCredentials.fromJson(
      Map<String, dynamic>.from(
        (body is Map ? body['credentials'] : null) as Map? ?? const {},
      ),
    );
  }

  // ---------------------------------------------------------------- الإعلانات

  Future<List<AdminAnnouncement>> loadAnnouncements() async {
    final response = await _api.adminAnnouncements();
    final data = response.data is Map ? response.data['data'] : null;

    return [
      if (data is List)
        for (final row in data)
          if (row is Map) AdminAnnouncement.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// [publish] = false يحفظه مسودّةً لا يراها أحد.
  Future<void> saveAnnouncement({
    String? uuid,
    required String title,
    required String body,
    required List<String> audience,
    List<int> circleIds = const [],
    bool publish = true,
  }) {
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'scope': circleIds.isEmpty ? 'all' : 'circle',
      'scope_ids': circleIds,
      'audience': audience,
      'publish': publish,
    };

    return uuid == null
        ? _api.storeAnnouncement(payload)
        : _api.updateAnnouncement(uuid, payload);
  }

  Future<void> unpublishAnnouncement(String uuid) => _api.unpublishAnnouncement(uuid);

  /// حلقاتُ الدورة الجارية — هدفُ الإعلان الموجَّه. والمعرّفُ معرّفُ `course_circles`
  /// كما يقارنه الخادم في `AnnouncementQuery`.
  Future<List<CircleOption>> loadCurrentCircles() async {
    final course = await (_db.select(_db.courses)
          ..where((t) => t.isCurrent.equals(true))
          ..limit(1))
        .getSingleOrNull();

    if (course == null) {
      return const [];
    }

    final query = _db.select(_db.courseCircles).join([
      innerJoin(_db.circles, _db.circles.id.equalsExp(_db.courseCircles.circleId)),
      innerJoin(_db.shifts, _db.shifts.id.equalsExp(_db.courseCircles.shiftId)),
    ])
      ..where(_db.courseCircles.courseId.equals(course.id))
      ..orderBy([
        OrderingTerm(expression: _db.circles.sortOrder),
        OrderingTerm(expression: _db.shifts.sortOrder),
      ]);

    final rows = await query.get();

    return [
      for (final row in rows)
        CircleOption(
          id: row.readTable(_db.courseCircles).id,
          name: '${row.readTable(_db.circles).name} · ${row.readTable(_db.shifts).name}',
        ),
    ];
  }

  // ---------------------------------------------------------------- الواصفات

  Future<List<CustomFieldDefinition>> loadCustomFields() async {
    final fields = await (_db.select(_db.customFields)
          ..orderBy([
            (t) => OrderingTerm(expression: t.entity),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
        .get();

    return [
      for (final field in fields)
        CustomFieldDefinition(
          uuid: field.uuid,
          entity: field.entity,
          key: field.key,
          label: field.label,
          type: field.type,
          options: CustomFieldView.parseOptions(field.options),
          group: field.group,
          isRequired: field.isRequired,
          isActive: field.isActive,
          sortOrder: field.sortOrder,
        ),
    ];
  }

  Stream<List<CustomFieldDefinition>> watchCustomFields() => _watch(loadCustomFields);

  /// [fieldKey] يُرسَل عند التعديل: القيمُ المخزَّنة معلَّقةٌ على المفتاح، فلا يتغيّر بتغيُّر العنوان.
  Future<void> saveCustomField({
    String? uuid,
    String? fieldKey,
    required String entity,
    required String label,
    required String type,
    List<String> options = const [],
    String? group,
    bool isRequired = false,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    final body = <String, dynamic>{
      'entity': entity,
      'label': label,
      if (fieldKey != null) 'key': fieldKey,
      'type': type,
      'options': options,
      'group': (group?.trim().isEmpty ?? true) ? null : group!.trim(),
      'is_required': isRequired,
      'is_active': isActive,
      'sort_order': sortOrder,
    };

    return uuid == null
        ? _api.storeCustomField(body)
        : _api.updateCustomField(uuid, body);
  }

  Future<void> deleteCustomField(String uuid) => _api.deleteCustomField(uuid);

  // ---------------------------------------------------------------- الصفات

  /// الصفاتُ العامةُ المزروعة ومعها صفاتُ المعهد — والعامّةُ للقراءة وحدها.
  Future<List<TraitView>> loadTraits() async {
    final traits = await (_db.select(_db.personalTraits)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .get();

    return [
      for (final row in traits)
        TraitView(
          uuid: row.uuid,
          name: row.name,
          polarity: row.polarity,
          color: row.color,
          sortOrder: row.sortOrder,
          isActive: row.isActive,
          isGlobal: row.instituteId == null,
        ),
    ];
  }

  Stream<List<TraitView>> watchTraits() => _watch(loadTraits);

  Future<void> saveTrait({
    String? uuid,
    required String name,
    required String polarity,
    String? color,
    int sortOrder = 0,
    bool isActive = true,
  }) {
    final body = <String, dynamic>{
      'name': name,
      'polarity': polarity,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
    };

    return uuid == null ? _api.storeTrait(body) : _api.updateTrait(uuid, body);
  }

  Future<void> deleteTrait(String uuid) => _api.deleteTrait(uuid);

  // ---------------------------------------------------------------- مساعدات

  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();

    await for (final _ in _db.tableUpdates()) {
      yield await read();
    }
  }
}

/// أستاذٌ في القائمة — أعمدةُ العرض المزامَنة وحدها.
class TeacherEntry {
  const TeacherEntry({
    required this.uuid,
    required this.displayName,
    required this.status,
    this.phone,
  });

  final String uuid;
  final String displayName;
  final String? phone;

  /// `active` \| `suspended` \| `left` — كما في `TeacherStatus`.
  final String status;
}

/// إعلانٌ كما تقرؤه الإدارة: منشوراً أو مسودّة.
class AdminAnnouncement {
  const AdminAnnouncement({
    required this.uuid,
    required this.title,
    required this.body,
    required this.scope,
    required this.scopeIds,
    required this.audience,
    this.publishedAt,
    this.author,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) => AdminAnnouncement(
        uuid: json['uuid'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        scope: json['scope'] as String? ?? 'all',
        scopeIds: [
          for (final id in json['scope_ids'] as List? ?? const []) (id as num).toInt(),
        ],
        audience: [
          for (final value in json['audience'] as List? ?? const ['students']) '$value',
        ],
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal(),
        author: json['author'] as String?,
      );

  final String uuid;
  final String title;
  final String body;

  /// `all` \| `circle`.
  final String scope;
  final List<int> scopeIds;

  /// `students` · `guardians` · `teachers`.
  final List<String> audience;

  /// `null` ⇒ مسودّةٌ أو سُحب.
  final DateTime? publishedAt;
  final String? author;

  bool get isPublished => publishedAt != null;
}

/// حلقةٌ في الدورة الجارية — بمعرّف `course_circles` الذي يوجَّه إليه الإعلان.
class CircleOption {
  const CircleOption({required this.id, required this.name});

  final int id;
  final String name;
}

class CustomFieldDefinition {
  const CustomFieldDefinition({
    required this.uuid,
    required this.entity,
    required this.key,
    required this.label,
    required this.type,
    required this.options,
    required this.isRequired,
    required this.isActive,
    required this.sortOrder,
    this.group,
  });

  final String uuid;

  /// `student` \| `teacher` \| `circle`.
  final String entity;
  final String key;
  final String label;

  /// `text` · `textarea` · `number` · `date` · `select` · `multi_select` · `bool`.
  final String type;
  final List<String> options;
  final String? group;
  final bool isRequired;
  final bool isActive;
  final int sortOrder;
}

class TraitView {
  const TraitView({
    required this.uuid,
    required this.name,
    required this.polarity,
    required this.sortOrder,
    required this.isActive,
    required this.isGlobal,
    this.color,
  });

  final String uuid;
  final String name;

  /// `positive` \| `neutral` \| `negative`.
  final String polarity;
  final String? color;
  final int sortOrder;
  final bool isActive;

  /// من الصفات التسع المزروعة لكل المعاهد — تُعرض ولا تُحرَّر من معهد.
  final bool isGlobal;
}
