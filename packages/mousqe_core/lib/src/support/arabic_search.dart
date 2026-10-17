import 'dart:math' as math;

/// بحثٌ عربيٌّ متسامح — نظيرُ `App\Support\ArabicSearch` في الخادم بالقواعد نفسها، فيعطي البحثُ
/// نفسُه في اللوحة وفي برنامج الإدارة النتائجَ نفسَها.
///
/// «احمد» يجد «أحمد»، و«عبدالرحمن» يجد «عبد الرحمن»، و«زغلول» يجد «الزغلول». والقريبُ بالإملاء
/// («محمود» لـ«محمد») ليس تطابقاً: يُعرض «أقربَ النتائج» حين لا يوجد غيره.
class ArabicSearch {
  const ArabicSearch._();

  static const double exact = 1.0;
  static const double prefix = 0.85;
  static const double contains = 0.7;
  static const double near = 0.55;

  static final _marks = RegExp('[ً-ٰٟـ]');
  static final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _compound = RegExp(r'(^|\s)(عبد|ابو)\s+');
  static final _article = RegExp(r'^ال(?=\p{L}{2})', unicode: true);
  static final _digitsOnly = RegExp(r'^\d+$');

  static const _letters = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ة': 'ه',
    'ى': 'ي',
    'ؤ': 'و',
    'ئ': 'ي', //
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  /// نصٌّ للمقارنة لا للعرض.
  static String normalize(String? text) {
    final buffer = StringBuffer();

    for (final char
        in (text ?? '').toLowerCase().replaceAll(_marks, '').split('')) {
      buffer.write(_letters[char] ?? char);
    }

    return buffer
        .toString()
        .replaceAll(_separators, ' ')
        .replaceAllMapped(_compound, (m) => '${m[1]}${m[2]}')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> words(String? text) {
    final normalized = normalize(text);

    return normalized.isEmpty ? const [] : normalized.split(' ');
  }

  /// مدى تطابق [query] مع [fields]: الدرجةُ متوسّطُ أفضلِ ما تجده كلُّ كلمة، و`complete` أن تجد كلُّ
  /// كلمةٍ نفسَها (كاملةً أو بدايةً أو داخل كلمة) لا قريبةً منها بالإملاء.
  static ({double score, bool complete}) match(
    String query,
    Iterable<String?> fields,
  ) {
    final needles = words(query);

    if (needles.isEmpty) {
      return (score: 1.0, complete: true);
    }

    final haystack = [for (final field in fields) ...words(field)];
    final digits = [
      for (final field in fields) (field ?? '').replaceAll(RegExp(r'\D'), ''),
    ];

    var total = 0.0;
    var complete = true;

    for (final needle in needles) {
      var best = _numeric(needle, digits);

      for (final word in haystack) {
        best = math.max(best, _wordScore(needle, word));
      }

      complete = complete && best >= contains;
      total += best;
    }

    return (score: total / needles.length, complete: complete);
  }

  /// نتائجُ البحث في [items] مرتّبةً بالأقرب، ومعها هل هي «أقربُ النتائج» لا تطابقٌ تامّ.
  static ({List<T> items, bool approximate}) rank<T>(
    List<T> items,
    String query,
    Iterable<String?> Function(T item) fields,
  ) {
    if (words(query).isEmpty) {
      return (items: items, approximate: false);
    }

    final scored = [
      for (final item in items)
        (item: item, result: match(query, fields(item))),
    ];

    var hits = scored.where((entry) => entry.result.complete).toList();
    var approximate = false;

    if (hits.isEmpty) {
      hits = scored.where((entry) => entry.result.score > 0.3).toList();
      approximate = hits.isNotEmpty;
    }

    // ترتيبٌ ثابت: الدرجةُ أولاً، والترتيبُ الأصليّ (أبجديٌّ عادةً) بين المتساوين.
    final order = {for (var i = 0; i < items.length; i++) items[i]: i};
    hits.sort((a, b) {
      final byScore = b.result.score.compareTo(a.result.score);

      return byScore != 0 ? byScore : order[a.item]!.compareTo(order[b.item]!);
    });

    return (
      items: [for (final entry in hits) entry.item],
      approximate: approximate,
    );
  }

  static double _wordScore(String needle, String word) {
    if (needle == word) {
      return exact;
    }

    final bare = word.replaceFirst(_article, '');

    if (needle == bare) {
      return exact - 0.05;
    }

    if (word.startsWith(needle) || bare.startsWith(needle)) {
      return prefix;
    }

    if (needle.length >= 2 && word.contains(needle)) {
      return contains;
    }

    final length = needle.length;
    final allowed = length >= 7 ? 2 : (length >= 4 ? 1 : 0);

    if (allowed > 0) {
      final d = math.min(distance(needle, word), distance(needle, bare));

      if (d <= allowed) {
        return near - 0.1 * d;
      }
    }

    return 0;
  }

  static double _numeric(String needle, List<String> digits) {
    if (!_digitsOnly.hasMatch(needle) || needle.length < 3) {
      return 0;
    }

    for (final number in digits) {
      if (number == needle) {
        return exact;
      }

      if (number.isNotEmpty && number.contains(needle)) {
        return contains;
      }
    }

    return 0;
  }

  /// مسافةُ التحرير بالمحارف.
  static int distance(String a, String b) {
    final source = a.runes.toList();
    final target = b.runes.toList();
    var previous = List<int>.generate(target.length + 1, (i) => i);

    for (var i = 0; i < source.length; i++) {
      final current = [i + 1];

      for (var j = 0; j < target.length; j++) {
        current.add(
          math.min(
            math.min(previous[j + 1] + 1, current[j] + 1),
            previous[j] + (source[i] == target[j] ? 0 : 1),
          ),
        );
      }

      previous = current;
    }

    return previous[target.length];
  }
}
