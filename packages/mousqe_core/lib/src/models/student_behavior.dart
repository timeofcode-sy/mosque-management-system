/// الجانبُ السلوكي لطالب — عقدُ `GET /guardian/children/{uuid}/behavior` و`GET /student/me/behavior`
/// (`App\Queries\StudentBehaviorQuery`)، ويبنيه الأستاذُ من drift بالشكل نفسه.
class StudentBehavior {
  const StudentBehavior({
    this.positive = 0,
    this.negative = 0,
    this.neutral = 0,
    this.behaviorPoints = 0,
    this.notes = const [],
    this.traits = const [],
    this.points = const [],
  });

  factory StudentBehavior.fromJson(Map<String, dynamic> json) {
    final summary =
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {};

    List<Map<String, dynamic>> rows(String key) => [
      for (final row in json[key] as List<dynamic>? ?? const [])
        (row as Map).cast<String, dynamic>(),
    ];

    return StudentBehavior(
      positive: (summary['positive'] as num?)?.toInt() ?? 0,
      negative: (summary['negative'] as num?)?.toInt() ?? 0,
      neutral: (summary['neutral'] as num?)?.toInt() ?? 0,
      behaviorPoints: (summary['behavior_points'] as num?)?.toDouble() ?? 0,
      notes: [
        for (final row in rows('notes'))
          BehaviorNote(
            date: DateTime.tryParse(row['date'] as String? ?? ''),
            polarity: row['polarity'] as String?,
            note: row['note'] as String? ?? '',
            circle: row['circle'] as String?,
          ),
      ],
      traits: [
        for (final row in rows('traits'))
          BehaviorTrait(
            name: row['name'] as String? ?? '',
            polarity: row['polarity'] as String? ?? 'neutral',
            note: row['note'] as String?,
          ),
      ],
      points: [
        for (final row in rows('points'))
          BehaviorPoint(
            date: DateTime.tryParse(row['date'] as String? ?? ''),
            points: (row['points'] as num?)?.toDouble() ?? 0,
            note: row['note'] as String?,
          ),
      ],
    );
  }

  /// ملاحظاتُ ثناء، وتنبيه، ومجرّدة.
  final int positive;
  final int negative;
  final int neutral;

  /// مجموعُ نقاط السلوك (قد يكون سالباً).
  final double behaviorPoints;

  /// الأحدثُ أولاً.
  final List<BehaviorNote> notes;
  final List<BehaviorTrait> traits;
  final List<BehaviorPoint> points;

  bool get isEmpty => notes.isEmpty && traits.isEmpty && points.isEmpty;
}

/// ملاحظةُ أستاذٍ في التفقّد.
class BehaviorNote {
  const BehaviorNote({
    required this.note,
    this.date,
    this.polarity,
    this.circle,
  });

  final DateTime? date;

  /// `positive` \| `negative` \| `null` (ملاحظةٌ مجرّدة).
  final String? polarity;
  final String note;
  final String? circle;
}

/// صفةٌ شخصية، وملاحظةُ من وصفه بها.
class BehaviorTrait {
  const BehaviorTrait({required this.name, required this.polarity, this.note});

  final String name;

  /// `positive` \| `negative` \| `neutral`.
  final String polarity;
  final String? note;
}

/// نقاطُ سلوكٍ منحها أستاذ.
class BehaviorPoint {
  const BehaviorPoint({required this.points, this.date, this.note});

  final DateTime? date;
  final double points;
  final String? note;
}
