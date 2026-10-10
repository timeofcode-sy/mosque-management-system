import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuzul_ui/nuzul_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand/brand.dart';
import 'developer.dart';

/// ما يختلف بين تطبيقٍ وآخر في «حول التطبيق»: اسمُه على الهاتف وجملةٌ عمّن يخدم.
/// وما سواهما — النظامُ ومزاياه ومطوّرُه — واحدٌ في كل التطبيقات.
class AboutAppInfo {
  const AboutAppInfo({required this.title, required this.summary});

  final String title;
  final String summary;
}

/// يفتح «حول التطبيق» فوق المكدّس الجذري: يُفتح من شريط التطبيق ومن شاشة الدخول
/// معاً، ولا ينبغي أن يحبسه مكدّسُ بابٍ داخلي.
void openAboutApp(BuildContext context, AboutAppInfo app) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => AboutAppScreen(app: app)),
  );
}

void openAboutDeveloper(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const AboutDeveloperScreen()),
  );
}

/// زرُّ «حول» في شريط التطبيق: قائمةٌ ببابين.
class AboutMenuButton extends StatelessWidget {
  const AboutMenuButton({super.key, required this.app});

  final AboutAppInfo app;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AboutPage>(
      tooltip: 'حول',
      icon: const NzIcon(NzIcons.informationCircle),
      onSelected: (page) => switch (page) {
        _AboutPage.app => openAboutApp(context, app),
        _AboutPage.developer => openAboutDeveloper(context),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _AboutPage.app, child: Text('حول التطبيق')),
        PopupMenuItem(value: _AboutPage.developer, child: Text('حول المطوِّر')),
      ],
    );
  }
}

enum _AboutPage { app, developer }

/// رابطا «حول» نصّاً — أسفلَ شاشة الدخول حيث لا شريطَ تطبيق.
class AboutLinks extends StatelessWidget {
  const AboutLinks({super.key, required this.app});

  final AboutAppInfo app;

  @override
  Widget build(BuildContext context) {
    final muted = context.nz.inkMuted;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => openAboutApp(context, app),
          child: const Text('حول التطبيق'),
        ),
        Text('·', style: TextStyle(color: muted)),
        TextButton(
          onPressed: () => openAboutDeveloper(context),
          child: const Text('حول المطوِّر'),
        ),
      ],
    );
  }
}

/// حول التطبيق: نبذةٌ موجزة ونسختُه، و**الدعمُ الفني والتقني** — اتصالاً أو واتساب،
/// والطريقُ إلى مطوّره.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key, required this.app});

  final AboutAppInfo app;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: NzSpace.s6),
        children: [
          Container(
            color: Brand.ground,
            padding: const EdgeInsets.symmetric(vertical: NzSpace.s6),
            child: Column(
              children: [
                const BrandGlyph(height: 96),
                const SizedBox(height: NzSpace.s3),
                Text(
                  app.title,
                  style: NzType.display3.copyWith(color: NzBrand.star),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NzSpace.s1),
                const _Version(),
              ],
            ),
          ),
          _Section(
            children: [
              Text(app.summary, style: NzType.bodyLg.copyWith(color: c.ink)),
              const SizedBox(height: NzSpace.s3),
              Text(
                '${Brand.name} نظامٌ لإدارة حلقات تحفيظ القرآن الكريم في المساجد والمعاهد، '
                'على الهاتف والحاسوب، حتى دون اتصال.',
                style: NzType.body.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const _Label('الدعم الفني والتقني'),
          _Group(
            children: [
              for (final person in TechnicalSupport.contacts)
                _Row(
                  icon: NzIcons.phone,
                  title: person.name,
                  subtitle: person.phone,
                  ltrSubtitle: true,
                  onTap: () => _reach(context, person),
                  onLongPress: () => _copy(context, person.phone),
                ),
            ],
          ),
          const _Label('المزيد'),
          _Group(
            children: [
              _Row(
                icon: NzIcons.informationCircle,
                title: 'حول المطوِّر',
                subtitle: Developer.name,
                onTap: () => openAboutDeveloper(context),
              ),
              _Row(
                icon: NzIcons.externalLink,
                title: 'موقع ${Brand.name}',
                subtitle: Brand.domain,
                ltrSubtitle: true,
                onTap: () => openLink(context, 'https://${Brand.domain}'),
              ),
              _Row(
                icon: NzIcons.note,
                title: 'تراخيص البرمجيات مفتوحة المصدر',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: app.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: NzSpace.s5),
          const _Ownership(),
        ],
      ),
    );
  }
}

/// اتصالٌ أو واتساب أو نسخُ الرقم — ورقةٌ سفلية لا افتراضٌ عن الطريقة: من في
/// المسجد قد لا يستطيع الكلام، ومن على الحاسوب لا يتّصل منه.
Future<void> _reach(BuildContext context, SupportContact person) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NzSpace.s4),
            child: Column(
              children: [
                Text(person.name, style: NzType.title),
                Text(
                  person.phone,
                  textDirection: TextDirection.ltr,
                  style: NzType.body.copyWith(color: sheet.nz.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: NzSpace.s2),
          ListTile(
            leading: const NzIcon(NzIcons.phone),
            title: const Text('اتصال'),
            onTap: () {
              Navigator.of(sheet).pop();
              openLink(context, person.telUri);
            },
          ),
          ListTile(
            leading: const NzIcon(NzIcons.send),
            title: const Text('مراسلة عبر واتساب'),
            onTap: () {
              Navigator.of(sheet).pop();
              openLink(context, person.whatsappUri);
            },
          ),
          ListTile(
            leading: const NzIcon(NzIcons.copy),
            title: const Text('نسخ الرقم'),
            onTap: () {
              Navigator.of(sheet).pop();
              _copy(context, person.phone);
            },
          ),
          const SizedBox(height: NzSpace.s2),
        ],
      ),
    ),
  );
}

/// حول المطوِّر: الشركةُ وخدماتُها وطرقُ التواصل معها.
class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Scaffold(
      appBar: AppBar(title: const Text('حول المطوِّر')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: NzSpace.s6),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NzSpace.s4,
              NzSpace.s6,
              NzSpace.s4,
              NzSpace.s2,
            ),
            child: Column(
              children: [
                Image.asset(
                  Developer.logoAsset,
                  package: Developer.logoPackage,
                  height: 140,
                  semanticLabel: Developer.name,
                ),
                const SizedBox(height: NzSpace.s3),
                Text(
                  Developer.arabicName,
                  style: NzType.title.copyWith(color: c.ink),
                ),
                Text(
                  Developer.tagline,
                  style: NzType.body.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          _Section(
            children: [
              Text(Developer.about, style: NzType.body.copyWith(color: c.ink)),
              const SizedBox(height: NzSpace.s3),
              Text(
                '${Brand.name} من تطوير ${Developer.name} وملكيّتها.',
                style: NzType.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const _Label('خدماتنا'),
          _Group(
            children: [
              for (final service in Developer.services)
                _Row(icon: NzIcons.star, title: service),
            ],
          ),
          const _Label('تواصل معنا'),
          _Group(
            children: [
              for (final contact in Developer.contacts)
                _Row(
                  icon: _iconOf(contact.kind),
                  title: contact.label,
                  subtitle: contact.value,
                  ltrSubtitle: true,
                  onTap: () => openLink(context, contact.uri),
                  onLongPress: () => _copy(context, contact.value),
                ),
              const _Row(
                icon: NzIcons.home,
                title: 'العنوان',
                subtitle: Developer.address,
              ),
            ],
          ),
          const SizedBox(height: NzSpace.s5),
          const _Ownership(),
        ],
      ),
    );
  }

  static String _iconOf(ContactKind kind) => switch (kind) {
        ContactKind.website => NzIcons.externalLink,
        ContactKind.email => NzIcons.envelope,
        ContactKind.phone => NzIcons.phone,
        ContactKind.whatsapp => NzIcons.phone,
        ContactKind.telegram => NzIcons.send,
        ContactKind.facebook => NzIcons.externalLink,
        ContactKind.instagram => NzIcons.image,
      };
}

/// يفتح الرابطَ في تطبيقه (المتصفّح، البريد، واتساب…)، وإن تعذّر نسخه وأخبر.
///
/// جهازٌ بلا تطبيق بريد، أو حاسوبُ معهدٍ بلا متصفّحٍ مضبوط، لا يُسقط الضغطةَ
/// صامتة: يجد صاحبُه القيمةَ في الحافظة.
Future<void> openLink(BuildContext context, String uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;

  try {
    opened = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    opened = false;
  }

  if (!opened) {
    final value = uri.replaceFirst(RegExp(r'^(mailto|tel):'), '');
    await Clipboard.setData(ClipboardData(text: value));
    messenger?.showSnackBar(
      SnackBar(content: Text('تعذّر فتحُ الرابط، فنُسخ: $value')),
    );
  }
}

/// يعزل نصّاً لاتينياً داخل سطرٍ عربي (LRI … PDI) فلا تُعاد ترتيبُ أجزائه.
String _ltr(String text) => '\u2066$text\u2069';

Future<void> _copy(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: value));
  messenger?.showSnackBar(SnackBar(content: Text('نُسخ: $value')));
}

/// رقمُ النسخة كما بُني التطبيق (`--build-name` و`--build-number`)، أو لا شيء
/// حيث لا يُقرأ — في الاختبار مثلاً.
class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo?>(
      future: _read(),
      builder: (context, snapshot) {
        final info = snapshot.data;

        if (info == null || info.version.isEmpty) {
          return const SizedBox(height: 22);
        }

        final build = info.buildNumber.isEmpty ? '' : ' · بناء ${info.buildNumber}';

        // `1.0.0-beta.4` في سطرٍ عربيّ تنقلب أجزاؤه («beta.4-1.0.0») ما لم يُعزَل.
        return Text(
          'الإصدار ${_ltr(info.version)}$build',
          textDirection: TextDirection.rtl,
          style: NzType.body.copyWith(color: NzBrand.bronze),
        );
      },
    );
  }

  static Future<PackageInfo?> _read() async {
    try {
      return await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
  }
}

class _Ownership extends StatelessWidget {
  const _Ownership();

  @override
  Widget build(BuildContext context) {
    return Text(
      'جميع الحقوق محفوظة ${_ltr('© ${DateTime.now().year} ${Developer.name}')}',
      textAlign: TextAlign.center,
      style: NzType.caption.copyWith(color: context.nz.inkMuted),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NzSpace.s4,
        NzSpace.s5,
        NzSpace.s4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        NzSpace.s5,
        NzSpace.s5,
        NzSpace.s5,
        NzSpace.s2,
      ),
      child: Text(
        text,
        style: NzType.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: context.nz.inkMuted,
        ),
      ),
    );
  }
}

/// بطاقةٌ بحدٍّ تجمع صفوفاً يفصل بينها خطّ — كبطاقات «المزيد» في الإدارة.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NzSpace.s4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(NzRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.ltrSubtitle = false,
    this.onTap,
    this.onLongPress,
  });

  final String icon;
  final String title;
  final String? subtitle;

  /// بريدٌ ورقمٌ وعنوانُ موقع تُقرأ من اليسار — وفي سطرٍ عربيّ تنقلب رموزُها.
  final bool ltrSubtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NzSpace.s3,
            vertical: NzSpace.s2,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.bronzeSoft,
                  borderRadius: BorderRadius.circular(NzRadius.sm),
                ),
                child: NzIcon(icon, size: 22, color: c.bronzeInk),
              ),
              const SizedBox(width: NzSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: NzType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle case final String text)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          text,
                          textDirection:
                              ltrSubtitle ? TextDirection.ltr : null,
                          style: NzType.caption.copyWith(color: c.inkMuted),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                NzIcon(NzIcons.chevronLeft, size: 18, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
