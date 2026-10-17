/// إصدارٌ أحدث من المثبَّت كما يصفه الخادم (`GET /app-updates/check`).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.uuid,
    required this.version,
    required this.buildNumber,
    required this.mandatory,
    required this.downloadPath,
    this.title,
    this.publishedAt,
    this.fileName,
    this.size,
    this.sha256,
    this.downloadUrl,
    this.changes = const [],
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
    uuid: json['uuid'] as String,
    version: json['version'] as String,
    buildNumber: (json['build_number'] as num).toInt(),
    title: json['title'] as String?,
    mandatory: json['mandatory'] == true,
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    fileName: json['file_name'] as String?,
    size: (json['size'] as num?)?.toInt(),
    sha256: json['sha256'] as String?,
    downloadUrl: json['download_url'] as String?,
    downloadPath: json['download_path'] as String,
    changes: [
      for (final change in (json['changes'] as List? ?? const []))
        ReleaseChange.fromJson((change as Map).cast<String, dynamic>()),
    ],
  );

  final String uuid;
  final String version;
  final int buildNumber;
  final String? title;

  /// إلزاميٌّ إن كان هو أو أيُّ إصدارٍ فات الجهازَ إلزامياً — يحسبه الخادم.
  final bool mandatory;
  final DateTime? publishedAt;
  final String? fileName;

  /// بالبايت؛ `null` لرابطٍ خارجي لا يعرف الخادمُ حجمَه.
  final int? size;

  /// بصمةُ الملف المرفوع؛ `null` لرابطٍ خارجي.
  final String? sha256;

  /// رابطٌ خارجي مطلق، أو `null` فيُنزَّل من [downloadPath] على الخادم نفسه.
  final String? downloadUrl;

  /// نسبةً إلى عنوان الـ API: `app-updates/<uuid>/download`.
  final String downloadPath;

  /// كلُّ ما فات الجهازَ، الأحدثُ أوّلاً.
  final List<ReleaseChange> changes;
}

/// إصدارٌ واحد في سجلّ التغييرات.
class ReleaseChange {
  const ReleaseChange({
    required this.version,
    required this.buildNumber,
    required this.notes,
    this.title,
    this.mandatory = false,
    this.publishedAt,
  });

  factory ReleaseChange.fromJson(Map<String, dynamic> json) => ReleaseChange(
    version: json['version'] as String,
    buildNumber: (json['build_number'] as num).toInt(),
    title: json['title'] as String?,
    mandatory: json['mandatory'] == true,
    notes: [for (final note in (json['notes'] as List? ?? const [])) '$note'],
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
  );

  final String version;
  final int buildNumber;
  final String? title;
  final bool mandatory;
  final List<String> notes;
  final DateTime? publishedAt;
}

/// النسخةُ المثبَّتة كما بُنيت (`--build-name` و`--build-number`).
class InstalledVersion {
  const InstalledVersion({required this.version, required this.build});

  final String version;
  final int build;
}

/// تقدّمُ التنزيل: ما وصل، والكلّ إن عُرف، والسرعةُ في الثواني الأخيرة.
class DownloadProgress {
  const DownloadProgress({
    required this.received,
    this.total,
    this.bytesPerSecond = 0,
  });

  final int received;
  final int? total;
  final double bytesPerSecond;

  double? get fraction =>
      total == null || total == 0 ? null : (received / total!).clamp(0.0, 1.0);

  /// الوقتُ الباقي بالسرعة الحالية، أو `null` إن لم يُعرف الكلُّ أو توقّفت السرعة.
  Duration? get remaining {
    final total = this.total;

    if (total == null || bytesPerSecond < 1) {
      return null;
    }

    return Duration(seconds: ((total - received) / bytesPerSecond).ceil());
  }
}
