import 'dart:convert';

/// نماذجُ العرض لسطح الإدارة اليومية — ✅ م.6.5.
///
/// وهي **كائناتُ قراءةٍ مبنيّةٌ من drift** لا حمولاتُ JSON: نظائرُها في
/// `models/` (`AdminUser` · `RoleOption` · …) لِما لا يصل عبر المزامنة وحده
/// ([CHECKPOINT-PHASE-6.2.MD §7](../../../../../docs/CHECKPOINT-PHASE-6.2.MD)).
/// وما هنا يُجمَّع من صفوفٍ محلية، فلا `freezed` ولا `fromJson`.

/// صفٌّ في كشف الطلاب.
class StudentListEntry {
  const StudentListEntry({
    required this.id,
    required this.uuid,
    required this.fullName,
    required this.status,
    this.registrationNo,
    this.phone,
    this.circleName,
    this.pending = false,
  });

  final int id;
  final String uuid;
  final String fullName;

  /// `active` \| `graduated` \| `suspended` \| `left` — كما في `students.status`.
  final String status;

  final String? registrationNo;
  final String? phone;

  /// اسمُ حلقته في الدورة الجارية، أو `null` لطالبٍ غير مسجَّل بعد.
  final String? circleName;

  /// طالبٌ كُتب على هذا الجهاز ولم تصل عمليتُه الخادمَ بعد — يُعرَض بوسمه، وإلا
  /// بدا للمشرف أن حفظَه ضاع لأنه لا يجد صفَّه في الكشف.
  final bool pending;
}

/// وليُّ أمرٍ في الاستمارة — صفٌّ في `guardians` مربوطٌ بصلة القرابة.
class GuardianDraft {
  const GuardianDraft({this.fullName, this.occupation, this.phone});

  final String? fullName;
  final String? occupation;
  final String? phone;

  bool get isEmpty => (fullName ?? '').trim().isEmpty;

  Map<String, dynamic> toPayload() => {
        'full_name': fullName,
        'occupation': occupation,
        'phone': phone,
      };
}

/// استمارةُ تسجيل الطالب كاملةً — قراءةً وكتابةً.
///
/// **والمراجعُ فيها كلُّها `uuid` لا مفاتيحَ أساسية**: الصفاتُ وبنودُ المناهج
/// والواصفاتُ تصل الجهازَ بمعرّفاتها العالمية وحدها ولا يعرف أرقامَها الداخلية،
/// فحمولةٌ تحمل `trait_ids` كانت ستكون عقداً لا يستطيع أحدٌ الوفاءَ به
/// ([CHECKPOINT-PHASE-6.2.MD §5.1](../../../../../docs/CHECKPOINT-PHASE-6.2.MD)).
class StudentForm {
  const StudentForm({
    this.uuid,
    this.registrationNo,
    this.registrationDate,
    this.registrationDateHijri,
    this.status = 'active',
    this.firstName = '',
    this.fatherName = '',
    this.familyName = '',
    this.birthDate,
    this.birthPlace,
    this.gender,
    this.nationalId,
    this.gradeLevel,
    this.studentJob,
    this.phone,
    this.permanentAddress,
    this.currentAddress,
    this.familyMembersCount,
    this.studentHealthStatus,
    this.familyHealthStatus,
    this.notes,
    this.father = const GuardianDraft(),
    this.mother = const GuardianDraft(),
    this.traitUuids = const <String>{},
    this.memorizedItemUuids = const <String>{},
    this.customFields = const <String, String>{},
    this.courseCircleUuid,
  });

  /// `null` لطالبٍ جديد — ويولّده المستودع عند الحفظ فيُرسَل في نفس الدفعة مع
  /// تسجيله في حلقة، بلا انتظار معرّفٍ من الخادم (م.5.4).
  final String? uuid;

  final String? registrationNo;
  final DateTime? registrationDate;
  final String? registrationDateHijri;
  final String status;
  final String firstName;
  final String fatherName;
  final String familyName;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? gender;
  final String? nationalId;
  final String? gradeLevel;
  final String? studentJob;
  final String? phone;
  final String? permanentAddress;
  final String? currentAddress;
  final int? familyMembersCount;
  final String? studentHealthStatus;
  final String? familyHealthStatus;
  final String? notes;

  final GuardianDraft father;
  final GuardianDraft mother;

  final Set<String> traitUuids;
  final Set<String> memorizedItemUuids;

  /// مفتاحُها `uuid` الواصفة وقيمتُها نصُّ ما كتبه المستخدم.
  final Map<String, String> customFields;

  /// حلقةُ الدورة الجارية التي يُسجَّل فيها — `null` يعني «بلا تسجيلٍ الآن».
  final String? courseCircleUuid;

  bool get isNew => uuid == null;

  String get fullName => [firstName, fatherName, familyName]
      .where((part) => part.trim().isNotEmpty)
      .join(' ');

  StudentForm copyWith({
    String? uuid,
    Object? registrationNo = _keep,
    Object? registrationDate = _keep,
    Object? registrationDateHijri = _keep,
    String? status,
    String? firstName,
    String? fatherName,
    String? familyName,
    Object? birthDate = _keep,
    Object? birthPlace = _keep,
    Object? gender = _keep,
    Object? nationalId = _keep,
    Object? gradeLevel = _keep,
    Object? studentJob = _keep,
    Object? phone = _keep,
    Object? permanentAddress = _keep,
    Object? currentAddress = _keep,
    Object? familyMembersCount = _keep,
    Object? studentHealthStatus = _keep,
    Object? familyHealthStatus = _keep,
    Object? notes = _keep,
    GuardianDraft? father,
    GuardianDraft? mother,
    Set<String>? traitUuids,
    Set<String>? memorizedItemUuids,
    Map<String, String>? customFields,
    Object? courseCircleUuid = _keep,
  }) {
    return StudentForm(
      uuid: uuid ?? this.uuid,
      registrationNo: _or(registrationNo, this.registrationNo),
      registrationDate: _or(registrationDate, this.registrationDate),
      registrationDateHijri: _or(registrationDateHijri, this.registrationDateHijri),
      status: status ?? this.status,
      firstName: firstName ?? this.firstName,
      fatherName: fatherName ?? this.fatherName,
      familyName: familyName ?? this.familyName,
      birthDate: _or(birthDate, this.birthDate),
      birthPlace: _or(birthPlace, this.birthPlace),
      gender: _or(gender, this.gender),
      nationalId: _or(nationalId, this.nationalId),
      gradeLevel: _or(gradeLevel, this.gradeLevel),
      studentJob: _or(studentJob, this.studentJob),
      phone: _or(phone, this.phone),
      permanentAddress: _or(permanentAddress, this.permanentAddress),
      currentAddress: _or(currentAddress, this.currentAddress),
      familyMembersCount: _or(familyMembersCount, this.familyMembersCount),
      studentHealthStatus: _or(studentHealthStatus, this.studentHealthStatus),
      familyHealthStatus: _or(familyHealthStatus, this.familyHealthStatus),
      notes: _or(notes, this.notes),
      father: father ?? this.father,
      mother: mother ?? this.mother,
      traitUuids: traitUuids ?? this.traitUuids,
      memorizedItemUuids: memorizedItemUuids ?? this.memorizedItemUuids,
      customFields: customFields ?? this.customFields,
      courseCircleUuid: _or(courseCircleUuid, this.courseCircleUuid),
    );
  }

  /// حارسٌ يميّز «لم يُمرَّر» من «مُرِّر `null`» في [copyWith] — بدونه لا يمكن
  /// **مسحُ** حقلٍ اختياري، وهو نصفُ ما تفعله استمارةُ تحرير.
  static const Object _keep = Object();

  static T? _or<T>(Object? incoming, T? current) =>
      identical(incoming, _keep) ? current : incoming as T?;
}

/// صفةٌ شخصية معروضةٌ في الاستمارة — عامّةٌ أو خاصّةٌ بالمعهد.
class TraitOption {
  const TraitOption({
    required this.uuid,
    required this.name,
    required this.polarity,
  });

  final String uuid;
  final String name;

  /// `positive` \| `neutral` \| `watch` — يميّز الإيجابيّ عمّا يحتاج متابعة.
  final String polarity;
}

/// بندُ منهجٍ في الكشف والاستمارة.
class CurriculumItemView {
  const CurriculumItemView({
    required this.uuid,
    required this.name,
    required this.code,
    required this.sortOrder,
    this.count,
  });

  final String uuid;
  final String name;
  final String code;
  final int sortOrder;

  /// عدّادُ البند حين يكون لنوعه عدّاد — أحاديثُ الحديث وأبياتُ المتون (م.4.5).
  final int? count;
}

/// منهجٌ ببنوده.
class CurriculumView {
  const CurriculumView({
    required this.uuid,
    required this.name,
    required this.type,
    required this.isGlobal,
    required this.isActive,
    this.description,
    this.items = const [],
  });

  final String uuid;
  final String name;

  /// `quran` \| `hadith` \| `mutun` \| `custom`.
  final String type;

  /// منهجٌ مزروعٌ لكل المعاهد — يُرى ولا يُحرَّر وعاؤه، وتُضاف إليه بنود.
  final bool isGlobal;

  final bool isActive;
  final String? description;
  final List<CurriculumItemView> items;

  bool get isFixedQuran => type == 'quran';

  String get typeLabel => switch (type) {
        'quran' => 'القرآن الكريم',
        'hadith' => 'الحديث الشريف',
        'mutun' => 'المتون العلمية',
        _ => 'منهج مخصّص',
      };

  /// مفتاحُ العدّاد لهذا النوع — و`null` لنوعٍ بلا عدّاد.
  String? get countLabel => switch (type) {
        'hadith' => 'عدد الأحاديث',
        'mutun' => 'عدد الأبيات',
        _ => null,
      };
}

/// واصفةٌ مخصّصة يعرّفها المشرف — تُقرأ صفّاً وتُرسَم حقلاً.
class CustomFieldView {
  const CustomFieldView({
    required this.uuid,
    required this.label,
    required this.type,
    required this.isRequired,
    this.group,
    this.options = const [],
  });

  final String uuid;
  final String label;

  /// `text` \| `textarea` \| `number` \| `date` \| `boolean` \| `select`.
  final String type;

  final bool isRequired;
  final String? group;
  final List<String> options;

  /// `options` تصل نصَّ JSON كما خُزّنت — قائمةً أو كائناً أو `null`.
  static List<String> parseOptions(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded.map((value) => value.toString()).toList();
      }

      if (decoded is Map) {
        return decoded.values.map((value) => value.toString()).toList();
      }
    } on FormatException {
      return const [];
    }

    return const [];
  }
}

/// إذنُ غيابٍ وارد — يبتّ فيه المشرف وهو في المسجد بلا شبكة (`excuse.review`).
class ExcuseView {
  const ExcuseView({
    required this.uuid,
    required this.studentName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.pending = false,
  });

  final String uuid;
  final String studentName;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;

  /// `pending` \| `approved` \| `rejected`.
  final String status;

  final String? reviewNote;

  /// حُكم عليه على هذا الجهاز ولم يصل الخادمَ بعد.
  final bool pending;

  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'approved' => 'مقبول',
        'rejected' => 'مرفوض',
        _ => 'بانتظار المراجعة',
      };
}

/// دورةٌ في المعهد — الوعاءُ الذي تُصفَّر عنده عدّاداتُ الغياب.
class CourseView {
  const CourseView({
    required this.uuid,
    required this.name,
    required this.startsOn,
    required this.status,
    required this.isCurrent,
    this.endsOn,
    this.shiftsCount = 0,
    this.circlesCount = 0,
  });

  final String uuid;
  final String name;
  final DateTime startsOn;
  final DateTime? endsOn;

  /// `draft` \| `active` \| `finished` \| `archived`.
  final String status;

  final bool isCurrent;
  final int shiftsCount;
  final int circlesCount;

  String get statusLabel => switch (status) {
        'active' => 'جارية',
        'finished' => 'منتهية',
        'archived' => 'مؤرشفة',
        _ => 'مسوّدة',
      };
}

/// دوامٌ في دورة، بأيامه الأسبوعية.
class ShiftView {
  const ShiftView({
    required this.uuid,
    required this.courseUuid,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.weekdays,
    required this.isActive,
    this.circlesCount = 0,
  });

  final String uuid;
  final String courseUuid;
  final String name;

  /// `HH:MM:SS` كما تصل من الخادم.
  final String startsAt;
  final String endsAt;

  /// 0 = الأحد … 6 = السبت، كما في `shift_days.weekday`.
  final List<int> weekdays;

  final bool isActive;
  final int circlesCount;

  String get timeLabel =>
      '${_hhmm(startsAt)} – ${_hhmm(endsAt)}';

  String get weekdaysLabel => weekdays.isEmpty
      ? 'بلا أيام'
      : (weekdays.toList()..sort()).map(weekdayName).join(' · ');

  static String weekdayName(int weekday) => const [
        'الأحد',
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
      ][weekday % 7];

  static String _hhmm(String value) => value.split(':').take(2).join(':');
}

/// هويّةُ الحلقة الثابتة عبر الدورات — لا تشغيلُها ضمن دورة، وذاك صفٌّ آخر.
class CircleDefinitionView {
  const CircleDefinitionView({
    required this.uuid,
    required this.name,
    required this.isActive,
    this.level,
    this.color,
    this.runningIn = const [],
  });

  final String uuid;
  final String name;
  final bool isActive;
  final String? level;
  final String? color;

  /// أسماءُ الدوامات التي شُغّلت فيها في الدورة الجارية — فارغةٌ لحلقةٍ مُعرَّفةٍ
  /// ولم تُشغَّل بعد، وهي حالةٌ يراها المشرف ليشغّلها.
  final List<String> runningIn;

  bool get isRunning => runningIn.isNotEmpty;
}
