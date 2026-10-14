/// تسميعٌ في سجلّ الطالب — عقدُ `GET /student/me/recitations` و`GET /guardian/children/{uuid}/recitations`
/// (`App\Queries\RecitationLogQuery`): الأحدثُ أولاً، بأسماء السور والتقدير جاهزةً من الخادم.
class RecitationLogEntry {
  const RecitationLogEntry({
    required this.uuid,
    this.date,
    this.type,
    this.typeLabel,
    this.grade,
    this.gradeLabel,
    this.fromSurah,
    this.fromAyah,
    this.toSurah,
    this.toAyah,
    this.lines = 0,
    this.points = 0,
    this.notes,
  });

  factory RecitationLogEntry.fromJson(Map<String, dynamic> json) => RecitationLogEntry(
        uuid: json['uuid'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        type: json['type'] as String?,
        typeLabel: json['type_label'] as String?,
        grade: json['grade'] as String?,
        gradeLabel: json['grade_label'] as String?,
        fromSurah: json['from_surah_name'] as String?,
        fromAyah: (json['from_ayah'] as num?)?.toInt(),
        toSurah: json['to_surah_name'] as String?,
        toAyah: (json['to_ayah'] as num?)?.toInt(),
        lines: (json['lines'] as num?)?.toDouble() ?? 0,
        points: (json['points'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
      );

  /// `{"data": [...]}` — والغلافُ نفسُه في النقطتين.
  static List<RecitationLogEntry> listFromJson(Map<String, dynamic> json) => [
        for (final row in json['data'] as List<dynamic>? ?? const [])
          RecitationLogEntry.fromJson((row as Map).cast<String, dynamic>()),
      ];

  final String uuid;
  final DateTime? date;

  /// `memorization` \| `review` … كما في `RecitationType`، و[typeLabel] عنوانُه العربي.
  final String? type;
  final String? typeLabel;

  /// `excellent` \| `very_good` … كما في `RecitationGrade`، و[gradeLabel] عنوانُه العربي.
  final String? grade;
  final String? gradeLabel;

  final String? fromSurah;
  final int? fromAyah;
  final String? toSurah;
  final int? toAyah;
  final double lines;
  final double points;
  final String? notes;

  /// «الملك 1 – 15» أو «الملك 20 – القلم 10» — والسورةُ لا تتكرّر إن لم تتغيّر.
  String get range {
    if (fromSurah == null) {
      return '—';
    }

    final start = '$fromSurah${fromAyah == null ? '' : ' $fromAyah'}';

    if (toSurah == null) {
      return start;
    }

    final end = toSurah == fromSurah
        ? '${toAyah ?? ''}'
        : '$toSurah${toAyah == null ? '' : ' $toAyah'}';

    return end.isEmpty ? start : '$start – $end';
  }
}
