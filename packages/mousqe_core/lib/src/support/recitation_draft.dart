import '../models/enums.dart';
import 'quran.dart';

/// قواعدُ مدى التسميع، مجرَّدةً من أيّ واجهة.
///
/// **لماذا هنا لا في الشاشة؟** لأن شاشتين تحتاجانها: نموذجُ الأستاذ على الهاتف
/// وحوارُ المشرف على الديسكتوب. وهي القاعدةُ نفسُها في
/// [ARCHITECTURE.md §6](../../../../../docs/ARCHITECTURE.md): «ما يحتاجه الاثنان
/// من **منطق** يُرفع إلى `mousqe_core` ولا يُنسخ بين التطبيقات» — وما بقي في كل
/// تطبيقٍ رسمُ الحقول لا حكمُها.
///
/// ### المدى يُختار من جزء لا من المصحف كلّه
///
/// الأستاذ يسمّع **داخل جزء**، فاختيارُ الجزء أولاً يقصر «من سورة» على سوره،
/// و«إلى سورة» على ما بعد السورة المختارة منه — وهو نفسُ ما تفعله شاشةُ الجلسة في
/// اللوحة، فلا يفترق النموذجان.
///
/// **ولا أسطرَ ولا نقاطَ تُحسب هنا.** الخادم يحسبهما من المدى ويجمّدهما وقت
/// التسجيل ([API.md §6](../../../../../docs/API.md))، فحسابُهما في العميل يخلق
/// مصدرَ حقيقةٍ ثانياً يختلف عن الأول عند أوّل تعديلٍ في جدول الأسطر.
class RecitationDraft {
  RecitationDraft({
    RecitationType type = RecitationType.hifz,
    RecitationGrade? grade = RecitationGrade.excellent,
    int? juz,
    int? fromSurah,
    int? fromAyah,
    int? toSurah,
    int? toAyah,
    this.notes,
    this.uuid,
  }) : type = type,
       grade = grade,
       _juz = juz ?? _juzFor(juz, fromSurah, toSurah),
       _fromSurah = fromSurah ?? Quran.surahsOfJuz(juz ?? 30).first {
    _toSurah = toSurah ?? _fromSurah;
    _fromAyah = fromAyah ?? 1;
    _toAyah = toAyah ?? Quran.ayahs(_toSurah);
  }

  /// مسوّدةٌ من تسميعٍ مسجَّل — تُفتح لتصحيحه.
  ///
  /// والجزءُ المسجَّل يُحترم ما دام يسع طرفَي المدى؛ وإلا فُتحت على جزءٍ يسعهما،
  /// فلا تُسقط القائمةُ المقيَّدة نصفَ مدىً سُجّل قبل هذا القيد أو من عميلٍ آخر.
  factory RecitationDraft.from({
    required String uuid,
    required RecitationType type,
    required RecitationGrade? grade,
    required int fromSurah,
    required int fromAyah,
    required int toSurah,
    required int toAyah,
    int? juz,
    String? notes,
  }) {
    return RecitationDraft(
      uuid: uuid,
      type: type,
      grade: grade,
      juz: _juzFor(juz, fromSurah, toSurah),
      fromSurah: fromSurah,
      fromAyah: fromAyah,
      toSurah: toSurah,
      toAyah: toAyah,
      notes: notes,
    );
  }

  /// معرّفُ التسميع المصحَّح — و`null` يعني تسجيلاً جديداً يولّد الجهازُ معرّفه.
  ///
  /// الحالتان **عمليةٌ واحدة على السلك** (`recitation.save`)، والخادم يفرّق
  /// بينهما بالمعرّف وحده ([API.md §6](../../../../../docs/API.md)).
  final String? uuid;

  RecitationType type;
  RecitationGrade? grade;
  String? notes;

  int _juz;
  int _fromSurah;
  late int _toSurah;
  late int _fromAyah;
  late int _toAyah;

  bool get isEditing => uuid != null;

  int get juz => _juz;
  int get fromSurah => _fromSurah;
  int get toSurah => _toSurah;
  int get fromAyah => _fromAyah;
  int get toAyah => _toAyah;

  /// سورُ الجزء الجاري — قائمةُ «من سورة».
  List<int> get fromSurahOptions => Quran.surahsOfJuz(_juz);

  /// ما لا يسبق «من سورة» داخل الجزء — قائمةُ «إلى سورة».
  List<int> get toSurahOptions => Quran.surahsOfJuzFrom(_juz, _fromSurah);

  /// تغييرُ الجزء يُعيد المدى إلى أوّل سورةٍ فيه كاملةً — فسورةُ الجزء السابق لم
  /// تعد في القائمة، وتركُها مختارةً يعني حفظَ مدىً لا يعرضه النموذج.
  void pickJuz(int juz) {
    _juz = juz;
    _fromSurah = Quran.surahsOfJuz(juz).first;
    _toSurah = _fromSurah;
    _fromAyah = 1;
    _toAyah = Quran.ayahs(_toSurah);
  }

  /// «إلى سورة» لا تسبق «من سورة»: تغييرُ الأولى يجرّ الثانية معها.
  void pickFromSurah(int surah) {
    _fromSurah = surah;

    if (!Quran.surahsOfJuzFrom(_juz, surah).contains(_toSurah)) {
      _toSurah = surah;
      _toAyah = Quran.ayahs(_toSurah);
    }
  }

  void pickToSurah(int surah) {
    _toSurah = surah;
    _toAyah = Quran.ayahs(surah);
  }

  void setFromAyah(int? ayah) => _fromAyah = ayah ?? _fromAyah;

  void setToAyah(int? ayah) => _toAyah = ayah ?? _toAyah;

  /// حدُّ رقم الآية بحدّ سورتها — يُتحقَّق محلياً لأن رفضه من الخادم يأتي بعد ساعات.
  String? fromAyahError(String? value) => _ayahError(value, _fromSurah);

  /// وداخل السورة الواحدة لا تسبق «إلى آية» «من آية» — وعبر سورتين لا معنى
  /// للمقارنة أصلاً: الترتيب تحسمه السورتان لا رقما الآيتين.
  String? toAyahError(String? value, String fromValue) {
    final error = _ayahError(value, _toSurah);

    if (error != null || _fromSurah != _toSurah) {
      return error;
    }

    final from = int.tryParse(fromValue.trim());
    final to = int.tryParse((value ?? '').trim());

    return from != null && to != null && to < from
        ? 'لا تسبق «من آية» ($from)'
        : null;
  }

  static String? _ayahError(String? value, int surah) {
    final total = Quran.ayahs(surah);
    final ayah = int.tryParse((value ?? '').trim());

    return ayah == null || ayah < 1 || ayah > total ? 'بين 1 و$total' : null;
  }

  static int _juzFor(int? juz, int? fromSurah, int? toSurah) {
    if (fromSurah == null || toSurah == null) {
      return juz ?? 30;
    }

    final recorded = Quran.surahsOfJuz(juz ?? 0);

    return recorded.contains(fromSurah) && recorded.contains(toSurah)
        ? juz!
        : Quran.juzSpanning(fromSurah, toSurah);
  }
}
