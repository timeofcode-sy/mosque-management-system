import 'package:flutter/material.dart';
import 'package:nuzul_ui/nuzul_ui.dart';

import 'developer.dart';

/// قسمٌ من وثيقةٍ قانونية: عنوانٌ، ثم فقراتٌ ونقاط.
class LegalSection {
  const LegalSection(this.heading, {this.paragraphs = const [], this.points = const []});

  final String heading;
  final List<String> paragraphs;
  final List<String> points;
}

/// «الخصوصية» أو «الشروط والأحكام» كما تُعرض في «حول التطبيق».
///
/// النصّ هنا لا من الخادم: الوثيقةُ تُقرأ قبل الدخول وبلا شبكة، كبقيّة «حول».
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
    this.showLicenses = false,
  });

  final String title;
  final String updated;
  final String intro;
  final List<LegalSection> sections;

  /// رابطُ تراخيص المكوّنات مفتوحة المصدر في آخر الوثيقة: بعضُها يشترط أن تصحب
  /// إشعاراتُه التطبيق، وموضعُه هنا بعد أن خرج من قائمة «حول».
  final bool showLicenses;
}

const _contact = LegalSection(
  'التواصل معنا',
  paragraphs: [
    '${Developer.name} — ${Developer.address}.',
    'البريد: Contact@timeofcode.com · الهاتف وواتساب: +963 986 209 313',
  ],
);

/// الوثيقتان — **نصُّهما الواحد في التطبيقين**.
abstract final class Legal {
  static const String updated = 'آخر تحديث: 15 تشرين الأول 2026م';

  static const LegalDocument privacy = LegalDocument(
    title: 'سياسة الخصوصية',
    updated: updated,
    intro:
        '«نزلاً» نظامٌ لإدارة حلقات تحفيظ القرآن الكريم في المساجد والمعاهد، تطوّره وتملكه شركة '
        '${Developer.name} في دمشق. ويحترم خصوصيةَ الطلاب وأوليائهم والأساتذة والعاملين في المعاهد. '
        'توضّح هذه السياسة ما يُجمع من بيانات، ولماذا، ومن يطّلع عليها، وكيف تُحمى.',
    sections: [
      LegalSection(
        'البيانات التي نجمعها',
        points: [
          'بيانات الحساب: الاسم واسم المستخدم وكلمة المرور، ورقم الهاتف إن أُدخل.',
          'بيانات الطالب التي يُدخلها المعهد عند التسجيل: الاسم والنسب وتاريخ الولادة والعنوان '
              'والصف الدراسي وبيانات الأهل، والوضع الصحي إن رأى المعهد إدخاله.',
          'بيانات الحلقة: الحضور والغياب والتأخّر، والتسميع وتقديراته، والنقاط، وملاحظات السلوك، '
              'وأعذار الغياب.',
          'بيانات الجهاز: نوعه ونظام تشغيله وإصدار التطبيق، ورمز الإشعارات لإيصال التنبيهات.',
        ],
        paragraphs: [
          'ولا يجمع «نزلاً» موقعك الجغرافي، ولا يصل إلى صورك أو جهات اتصالك أو الكاميرا أو الميكروفون.',
        ],
      ),
      LegalSection(
        'كيف نستخدم البيانات',
        points: [
          'تسجيل الحضور والتسميع والنقاط، وحساب النسب والترتيب.',
          'إطلاع وليّ الأمر على حضور ابنه وحفظه وسلوكه، والطالب على نفسه.',
          'إعداد التقارير والإحصاءات لإدارة المعهد.',
          'إرسال الإشعارات، كقبول عذر الغياب أو رفضه.',
          'الدعم الفنّي وإصلاح الأعطال وتحسين النظام.',
        ],
      ),
      LegalSection(
        'من يطّلع على البيانات',
        points: [
          'كلٌّ يرى ما يخصّه: وليّ الأمر يرى أبناءه، والطالب يرى نفسه، والأستاذ يرى حلقاته، وإدارة '
              'المعهد ترى معهدها، ومشرف المعاهد يرى المعاهد المسندة إليه.',
          'فريق الدعم في ${Developer.name}، للصيانة وحلّ المشكلات وحدها.',
          'خدمة Firebase من Google، لإيصال الإشعارات إلى الهاتف، ولا يُرسل إليها إلا ما يلزم لذلك.',
        ],
        paragraphs: [
          'لا نبيع البيانات ولا نؤجّرها، ولا نشاركها مع أي جهةٍ لأغراضٍ تجارية أو إعلانية، ولا نكشفها '
              'إلا بطلبٍ نظاميٍّ من جهةٍ مختصّة وفق القانون.',
        ],
      ),
      LegalSection(
        'أين تُحفظ البيانات',
        points: [
          'على خادم «نزلاً»، أو على خادم المعهد في شبكته المحلية، بحسب ما يختاره المعهد.',
          'ونسخةٌ على جهازك ليعمل التطبيق دون إنترنت، تُمسح عند تسجيل الخروج أو إيقاف الحساب.',
          'تبقى البيانات ما دام المعهد يستعمل النظام، وللمعهد أن يطلب تصديرها أو حذفها.',
        ],
      ),
      LegalSection(
        'كيف نحمي البيانات',
        points: [
          'اتصالٌ مشفّر بين التطبيق والخادم.',
          'كلمات المرور محفوظةٌ مشفّرةً لا تُقرأ.',
          'لكل دورٍ صلاحياتٌ محدّدة، ولا يُعطى أحدٌ أكثر مما يحتاجه.',
          'إيقاف الحساب يقطع الدخول فوراً ويمسح بياناته من الجهاز.',
          'نسخٌ احتياطيّة دوريّة.',
        ],
      ),
      LegalSection(
        'بيانات الأطفال',
        paragraphs: [
          'أكثر طلاب الحلقات دون الثامنة عشرة. يُدخل المعهدُ بياناتهم بعلم أوليائهم، ولا يُطلب من الطالب '
              'إلا اسم المستخدم وكلمة المرور اللذان يسلّمهما له المعهد، ولا يرى إلا بياناته.',
        ],
      ),
      LegalSection(
        'حقوقك',
        points: [
          'الاطّلاع على بياناتك وبيانات أبنائك.',
          'طلب تصحيح ما كان خطأً.',
          'طلب حذف حسابك أو بياناتك بعد انتهاء علاقتك بالمعهد.',
          'الاعتراض على أي استعمالٍ يخالف هذه السياسة.',
        ],
        paragraphs: ['تُقدَّم الطلبات إلى إدارة المعهد، أو إلينا مباشرةً عبر وسائل التواصل أدناه.'],
      ),
      LegalSection(
        'التعديلات على هذه السياسة',
        paragraphs: [
          'قد نحدّث هذه السياسة حين يتغيّر النظام أو القانون، ونُعلن التعديل داخل التطبيق، ويُعدّ '
              'استمرارك في استعماله قبولاً به.',
        ],
      ),
      _contact,
    ],
  );

  static const LegalDocument terms = LegalDocument(
    title: 'الشروط والأحكام',
    updated: updated,
    intro: 'باستعمالك «نزلاً» توافق على هذه الشروط، فاقرأها بعناية. وإن لم توافق عليها فلا تستعمل التطبيق.',
    showLicenses: true,
    sections: [
      LegalSection(
        'نطاق الشروط',
        paragraphs: [
          'تسري هذه الشروط على تطبيق «نزلاً» للهاتف، وبرنامج الإدارة، وموقع nuzuln.com. وإن كنت دون الثامنة '
              'عشرة فاستعمالك لها بعلم وليّ أمرك وإدارة معهدك.',
        ],
      ),
      LegalSection(
        'الحساب',
        paragraphs: [
          'يُنشئ المعهد حسابك ويسلّمك اسم المستخدم وكلمة المرور. أنت مسؤولٌ عن حفظهما، فلا تُعطِهما لغيرك، '
              'وإن ظننت أن أحداً عرفهما فأبلغ إدارة المعهد لتغييرهما. وللمعهد أن يوقف الحساب عند انتهاء '
              'التسجيل أو مخالفة هذه الشروط.',
        ],
      ),
      LegalSection(
        'الاستعمال المسموح',
        paragraphs: [
          'استعمل «نزلاً» لمتابعة الحلقات وما يتّصل بها: الحضور والتسميع والنقاط والأعذار والإعلانات والتقارير.',
        ],
      ),
      LegalSection(
        'الاستعمال الممنوع',
        points: [
          'محاولة الوصول إلى بياناتٍ لا تخصّك أو إلى حساب غيرك.',
          'إدخال بياناتٍ كاذبة أو مسيئة، أو ما يخالف الشريعة أو الآداب العامة.',
          'تعطيل النظام أو التلاعب به أو نسخه أو إعادة بيعه.',
          'استعماله لأغراضٍ تجارية أو دعائية لا صلة لها بالحلقات.',
        ],
      ),
      LegalSection(
        'المحتوى ودقّة البيانات',
        paragraphs: [
          'المعهد مسؤولٌ عن صحّة ما يُدخله من بيانات الطلاب والحلقات، والأستاذ عمّا يسجّله من حضورٍ وتسميعٍ '
              'وملاحظات، ويُرجى أن تكون الملاحظات بأسلوبٍ تربويٍّ يحفظ كرامة الطالب. وبيانات كل معهدٍ ملكٌ له.',
        ],
      ),
      LegalSection(
        'الملكية الفكرية',
        paragraphs: [
          'النظام وتصميمه واسمه وشعاره ملكٌ لشركة ${Developer.name}، ولا يجوز نسخه أو تعديله أو توزيعه إلا '
              'بإذنٍ مكتوب. أما النصوص الشرعية فمن تراث الأمة.',
        ],
      ),
      LegalSection(
        'توفّر الخدمة والتحديثات',
        paragraphs: [
          'نسعى إلى أن يعمل النظام دائماً، ويعمل التطبيق دون إنترنت ثم يرسل ما سجّلته حين يعود الاتصال. وقد '
              'يتوقّف مؤقتاً للصيانة أو لظروفٍ خارجة عن إرادتنا. وتصل التحديثات من داخل التطبيق، وقد يلزم '
              'بعضها لمتابعة الاستعمال.',
        ],
      ),
      LegalSection(
        'حدود المسؤولية',
        paragraphs: [
          'يُقدَّم النظام أداةً تعين على إدارة الحلقات، ولا نتحمّل مسؤولية قراراتٍ بُنيت على بياناتٍ أُدخلت '
              'خطأً، ولا ما ينتج عن ضياع جهازك أو مشاركة كلمة مرورك.',
        ],
      ),
      LegalSection(
        'التعديلات والقانون',
        paragraphs: [
          'قد نعدّل هذه الشروط ونُعلن التعديل داخل التطبيق، ويُعدّ استمرار الاستعمال قبولاً بها. وتخضع هذه '
              'الشروط لقوانين الجمهورية العربية السورية.',
        ],
      ),
      _contact,
    ],
  );
}

void openLegal(BuildContext context, LegalDocument document) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
  );
}

/// شاشةُ وثيقةٍ قانونية: مقدّمة، ثم أقسامٌ مرقّمة، ثم تاريخُ آخر تحديث.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final c = context.nz;

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NzSpace.s4, NzSpace.s4, NzSpace.s4, NzSpace.s6),
        children: [
          Text(document.intro, style: NzType.bodyLg.copyWith(color: c.ink)),
          for (final (i, section) in document.sections.indexed) ...[
            const SizedBox(height: NzSpace.s5),
            Text('${i + 1}. ${section.heading}', style: NzType.title.copyWith(color: c.ink)),
            for (final point in section.points)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: NzSpace.s2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 9, end: NzSpace.s2),
                      child: Container(width: 6, height: 6, color: c.bronzeInk),
                    ),
                    Expanded(child: Text(point, style: NzType.body.copyWith(color: c.ink))),
                  ],
                ),
              ),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(top: NzSpace.s2),
                child: Text(paragraph, style: NzType.body.copyWith(color: c.ink)),
              ),
          ],
          const SizedBox(height: NzSpace.s5),
          Text(document.updated, style: NzType.caption.copyWith(color: c.inkMuted)),
          if (document.showLicenses)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => showLicensePage(context: context, applicationName: 'نزلاً'),
                child: const Text('تراخيص المكوّنات مفتوحة المصدر'),
              ),
            ),
        ],
      ),
    );
  }
}
