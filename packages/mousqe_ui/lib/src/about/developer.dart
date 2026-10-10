/// المطوِّرُ والمالك — **مصدرُه الواحد في تطبيقات فلاتر**.
///
/// ونظيرُه للموقع واللوحة `backend/config/developer.php`: من يعدّل هنا يعدّل هناك.
abstract final class Developer {
  static const String name = 'Time of Code';
  static const String arabicName = 'تايم أوف كود';
  static const String tagline = 'شركةُ حلولٍ برمجيةٍ ورقمية';

  static const String about =
      'شركةٌ سوريةٌ مقرُّها دمشق، تصمّم المواقعَ وتطوّر تطبيقاتِ الهاتف وتبني الهويّاتِ '
      'البصرية. تؤمن بأن البرمجيةَ الجيّدة تُرى في التفاصيل الصغيرة: أن يعمل التطبيقُ '
      'حين تنقطع الشبكة، وأن يُقرأ بالعربية كما تُقرأ، وأن يحفظ وقتَ من يستعمله.';

  static const String address = 'سوريا - دمشق';

  static const String logoAsset = 'assets/timeofcode_logo.png';
  static const String logoPackage = 'mousqe_ui';

  static const List<String> services = [
    'تصميم المواقع الإلكترونية',
    'تطوير تطبيقات الهاتف المحمول',
    'بناء الهوية البصرية',
    'تصاميم وسائل التواصل الاجتماعي',
    'إدارة صفحات التواصل الاجتماعي',
    'مونتاج الفيديو والموشن غرافيك',
  ];

  static const List<DeveloperContact> contacts = [
    DeveloperContact(
      kind: ContactKind.website,
      label: 'الموقع',
      value: 'timeofcode.com',
      uri: 'https://timeofcode.com',
    ),
    DeveloperContact(
      kind: ContactKind.email,
      label: 'البريد',
      value: 'Contact@timeofcode.com',
      uri: 'mailto:Contact@timeofcode.com',
    ),
    DeveloperContact(
      kind: ContactKind.phone,
      label: 'الهاتف',
      value: '+963 986 209 313',
      uri: 'tel:+963986209313',
    ),
    DeveloperContact(
      kind: ContactKind.whatsapp,
      label: 'واتساب',
      value: '+963 986 209 313',
      uri: 'https://wa.me/963986209313',
    ),
    DeveloperContact(
      kind: ContactKind.telegram,
      label: 'تيليغرام',
      value: '@Time_of_Code',
      uri: 'https://t.me/Time_of_Code',
    ),
    DeveloperContact(
      kind: ContactKind.facebook,
      label: 'فيسبوك',
      value: 'TimeofCode.sy',
      uri: 'https://www.facebook.com/TimeofCode.sy',
    ),
    DeveloperContact(
      kind: ContactKind.instagram,
      label: 'إنستغرام',
      value: '@timeofcode.sy',
      uri: 'https://www.instagram.com/timeofcode.sy',
    ),
  ];
}

/// الدعمُ الفنّي والتقني — من يُتّصل به حين يتعطّل شيءٌ في التطبيق.
///
/// ونظيرُه للموقع `backend/config/developer.php` (`support`).
abstract final class TechnicalSupport {
  static const List<SupportContact> contacts = [
    SupportContact(
      name: 'محمد علاء عبد الرحمن الشحرور',
      phone: '+963 964 630 090',
    ),
    SupportContact(
      name: 'غالب صلاح النن',
      phone: '+963 980 149 515',
    ),
  ];
}

/// شخصٌ في الدعم: اسمُه ورقمُه كما يُقرأ، ومنه يُشتقّ رابطا الاتصال وواتساب.
class SupportContact {
  const SupportContact({required this.name, required this.phone});

  final String name;

  /// بمسافاتٍ للقراءة — `+963 964 630 090`.
  final String phone;

  String get digits => phone.replaceAll(RegExp(r'\D'), '');

  String get telUri => 'tel:+$digits';

  String get whatsappUri => 'https://wa.me/$digits';
}

enum ContactKind { website, email, phone, whatsapp, telegram, facebook, instagram }

/// وسيلةُ تواصل: ما يُعرض ([value]) وما يُفتح ([uri]).
class DeveloperContact {
  const DeveloperContact({
    required this.kind,
    required this.label,
    required this.value,
    required this.uri,
  });

  final ContactKind kind;
  final String label;
  final String value;
  final String uri;
}
