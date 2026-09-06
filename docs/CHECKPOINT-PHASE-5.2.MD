# نقطة تفتيش — المرحلة 5.2: الحزمتان المشتركتان

**التاريخ:** 2026-09-06 · **النطاق:** `packages/mousqe_core` و`packages/mousqe_ui` وحدهما، لا تطبيق ولا شاشة ·
**الاختبارات:** 19/19 تمرّ (14 في `mousqe_core` + 5 في `mousqe_ui`) · **الملفات:** حزمتان جديدتان
بالكامل، زائداً `pubspec.yaml` جذري جديد و`.gitignore` معدَّل.

> الخطة التي نُفِّذت: [PHASE-5-STAGES.MD §3](PHASE-5-STAGES.MD).
> العقود المبنيّ عليها: [API.md](API.md) · [SYNC-PROTOCOL.md](SYNC-PROTOCOL.md).

---

## 1. الغاية

بناء طبقة البيانات المشتركة التي تخدم **الأربعة تطبيقات القادمة** (أستاذ، ديسكتوب، أهل، طالب) قبل أن
تُكتب أول شاشة — نماذج البيانات، المخزن المحلي، عميل الشبكة، محرّك المزامنة، والهوية البصرية. كانت
الحزمتان فارغتين تماماً (لا `pubspec.yaml`)، فهذا بناءٌ من الصفر يتبع عقدَي `API.md` و
`SYNC-PROTOCOL.md` حرفياً.

---

## 2. القرار التصميمي الحاسم: طبقتان مختلفتا الشكل عمداً

`RecordChange::handle` (المرحلة 5.1) يكتب `payload = $model->toArray()` — الصورة **الخام** لعمود
قاعدة البيانات، لا صورة الـ API Resource. معنى ذلك أن صفوف `change_log` تحمل مفاتيح أجنبية بمعرّفات
رقمية داخلية (`student_id`, `attendance_session_id`...) لا بـ`uuid`.

لذلك بُنيت طبقتان منفصلتان في `mousqe_core` عمداً ولا تُدمَجان:

| الطبقة | الشكل | تُقرأ من |
|---|---|---|
| `lib/src/models/*.dart` (freezed) | `uuid` في كل مكان، تطابق `app/Http/Resources/V1/*` | نقاط REST المباشرة (`/bootstrap`, `/teacher/circles`...) |
| `lib/src/db/tables/*.dart` (drift) | `id` رقمي محلي + `uuid` فريد + مفاتيح أجنبية رقمية، تطابق أعمدة الهجرة الخادمية | `change_log` عبر `SyncEngine.pull()` |

**أثر عملي على تسمية الصفوف:** كل جدول drift اسمه صفّ بياناته الافتراضي هو مفرد اسم الجدول
(`Institutes` ⇒ `Institute`)، وهذا يصطدم بالضبط باسم نموذج الـ API المقابل. الحلّ `@DataClassName`
صريح على كل جدول (`InstituteRow`, `CourseRow`, `StudentRow`...) — لم يكن في الخطة الأصلية لأنه
اكتُشف فقط عند أول `flutter analyze` (انظر §4.2).

---

## 3. `mousqe_core`

### 3.1 البنية المنفَّذة

مطابقة لهيكل الخطة حرفياً: عشرة نماذج freezed (زائداً `AttendanceSettings` و`enums.dart` لم تكونا
مذكورتين باسمهما لكنهما ضروريتان لتفكيك حقل `attendance` في `Institute` وتمثيل الحالات النصية بأمان
النوع)، تسعة جداول drift + `pending_operations` + `sync_state`، `ApiClient` بتسع نقاط، `TokenStore`،
`SyncEngine`، `SyncPayloadApplier`، و`LateMinutes`.

### 3.2 `SyncEngine` — العشرة بنود

نُقلت حرفياً كما في [SYNC-PROTOCOL.md §8](SYNC-PROTOCOL.md):

- **`enqueue`** يثبّت `op_uuid` في `pending_operations` قبل أي إرسال.
- **`push`** يحذف من الطابور فقط ما ورد في `applied` أو `skipped`؛ استثناء شبكة (`DioException` بلا
  `ApiException` مرفق) يترك الطابور كما هو لإعادة المحاولة.
- **`pull`** يكرّر `GET /sync/pull` حتى `changes: []`، ويطبّق كل صفحة عبر `SyncPayloadApplier` قبل
  طلب التالية، ويحفظ `last_pulled_seq` محلياً في `sync_state` بعد كل صفحة.
- **`handleAccountLocked`** يستدعي `AppDatabase.clearAll()` (حذف كل الجداول ضمن معاملة واحدة).
- البنود 7 و8 و9 (ترشيح العرض، احترام `editable`، الإحصاءات المشتقّة) بقيت **خارج** الحزمة بالضبط
  كما نصّت الخطة — مسؤولية شاشات 5.3.

### 3.3 `SyncPayloadApplier`

يحوّل `operation` إلى فعل drift: `create`/`update` كلاهما `insert` بـ`onConflict: DoUpdate` **مستهدَفاً
عمود `uuid` صراحةً** (`target: [table.uuid]`) — لا الأساسي `id`. هذا انحراف عن `insertOnConflictUpdate`
البسيطة المذكورة في الخطة (§4.2 يشرح السبب). `delete` يحذف بمطابقة `uuid` بلا قراءة حمولة.

### 3.4 `LateMinutes`

نقلٌ حرفي لـ `backend/app/Support/LateMinutes.php`: نفس الحالات الثلاث التي تعود `null`/`0` (لا دوام،
تفقّدٌ من يوم غير يوم الجلسة، وصولٌ قبل بداية الدوام). اختبار الوحدة يقارن نفس المدخلات والمخرجات في
`backend/tests/Feature/Actions/LateMinutesTest.php`.

---

## 4. الانحرافات عن الخطة — كلّها اكتُشفت عند التنفيذ

الخطة كُتبت باعتماديات بإصدارات (`freezed: ^2.5.7`, `retrofit_generator: ^9.1.5`...) لم تكن
قابلةً للحلّ فعلياً مع أدوات البناء الحالية. أربعة انحرافات، كلّها في الأدوات لا في التصميم:

### 4.1 melos 8 يتطلّب تهيئة داخل `pubspec.yaml` الجذري لا `melos.yaml` مستقلاً

النسخة المتاحة (`melos: 8.6.0`) غيّرت نموذج التهيئة منذ الإصدار 7: قسم `melos:` يجب أن يكون داخل
`pubspec.yaml` الجذري (الذي لم يكن موجوداً أصلاً)، ومعه `workspace:` تسرد الحزم الأعضاء و`melos` كـ
`dev_dependency`. `melos.yaml` المستقل (كان موجوداً من قبل بنطاق `apps/* + packages/*`) نُقل محتواه
بالكامل إلى `pubspec.yaml` وحُذف — `apps/*` استُبعدت من `workspace:` لأنها فارغة تماماً اليوم (لا
`pubspec.yaml` فيها؛ ستُضاف في 5.3) بينما بقيت في قائمة `melos.packages` القديمة لأغراض `melos run`
المستقبلية.

### 4.2 freezed 4.x غيّر شكل التصريح

- الصنف يحتاج `abstract class X with _$X` لا `class X with _$X` — وإلا خطأ توليد.
- `@Freezed(fieldRename: FieldRename.snake)` لم يعد بارامتراً صالحاً على المُنشئ. التسمية بالـ
  snake_case صارت تُضبط عبر `build.yaml` على مستوى الحزمة (`json_serializable: options: field_rename:
  snake`) بدل تكرارها في كل نموذج.
- تصادم أسماء drift/freezed (§2) ظهر فقط بعد أول `flutter analyze` ناجح للنماذج — حُلّ بـ
  `@DataClassName` كما ورد أعلاه.

### 4.3 `Color.r`/`.g`/`.b` تعيد قيماً مُطبَّعة (0.0–1.0) لا بايتات (0–255)

Flutter الحالي غيّر شكل قنوات `Color` إلى أرقام عشرية مُطبَّعة. `MousqeTheme._shade` كانت تستدعي
`base.r.round()` ظانّةً أنها بايت — فتنتج قيماً قريبة من صفر لكل الألوان تقريباً. الإصلاح: `(base.r *
255).round()` قبل الخلط الخطّي. اكتُشف باختبار وحدة قارن الناتج بالقيمة الفعلية من
`InstituteTheme::shade()` في PHP (وليس بقيمة `design-tokens.json` المُعايَرة يدوياً — الاثنان غير
متطابقين تماماً لأن اللوحة الافتراضية مُنسَّقة يدوياً وليست ناتج الخوارزمية على كل درجة؛ التحقّق
الصحيح هو مطابقة **الخوارزمية**، ليس اللوحة الجاهزة).

### 4.4 `insertOnConflictUpdate` تستهدف المفتاح الأساسي لا `uuid` افتراضياً

drift الحالي يبني «هدف التعارض» الافتراضي من المفتاح الأساسي (`id` التلقائي)، لا من أي عمود `unique`
آخر. بما أن `id` في كل صفّ **جديد يُدرَج محلياً** يُنشأ تلقائياً (لا يُقرأ من الخادم)، فإن upsert
ثانٍ لنفس `uuid` كان يحاول إدراج صفّ بـ`id` جديد فيصطدم بقيد `unique(uuid)` بدل أن يحدّث الصفّ
القائم. الإصلاح: كل `_upsert` في `SyncPayloadApplier` يستخدم
`insert(entity, onConflict: DoUpdate((_) => entity, target: [table.uuid]))` صراحةً. اكتُشف باختبار
"update on an existing uuid replaces the row not duplicates it".

### 4.5 الخطوط: لا مصدر محلي، أضافها صاحب المشروع يدوياً

الخطة تطلب تضمين Reem Kufi وIBM Plex Sans Arabic كملفات `.ttf` — لم تكونا موجودتين في المستودع ولا
كان هناك اتصال إنترنت لتنزيلهما آلياً. صاحب المشروع نزّلهما من Google Fonts ووضعهما في التنزيلات؛
نُسخت الأوزان اللازمة فقط (Regular/Bold لـ Reem Kufi، وRegular/Medium/Bold لـ IBM Plex Sans Arabic)
إلى `packages/mousqe_ui/lib/src/fonts/` مع ملفَّي ترخيص OFL الأصليَّين.

---

## 5. `mousqe_ui`

`MousqeTheme.fromColors`/`fallback` تطابقان خوارزمية `InstituteTheme::shade()` الخادمية حرفياً (تحقّق
مباشر عبر PHP في نفس الجلسة — انظر §4.3). `MousqeApp` تفرض `ar` وRTL عبر `Directionality` مغلِّفة.
أربعة مكوّنات دنيا: `StatCard`، `AttendanceStatusBadge` (بألوان `design-tokens.json → color.status`
حرفياً)، `SyncStatusIndicator`، و`EmptyState`/`ErrorState`.

---

## 6. التحقّق

- [x] `melos bootstrap` ثم `melos run gen` ثم `melos run analyze` — **بلا أخطاء** على الحزمتين.
- [x] `melos run test` — **19/19** تمرّ: تكرار `op_uuid` بلا أثر مضاعف، إعادة إرسال عند استجابة
      مفقودة، تطبيق `applied`+`skipped` معاً، تكرار السحب حتى صفحة فارغة (`sync_engine_test.dart`
      — 4 اختبارات)؛ `create`/`update`/`delete` على drift (`sync_payload_applier_test.dart` — 3)؛
      `LateMinutes` يطابق `LateMinutesTest.php` (`late_minutes_test.dart` — 7)؛ `MousqeTheme` يطابق
      `InstituteTheme::shade()` الفعلي (`mousqe_theme_test.dart` — 5).
- [x] لا تطبيق ولا شاشة كُتبت — النطاق محصور بالحزمتين كما في الخطة.

---

## 7. ما يبقى للمرحلة 5.3

الحزمتان جاهزتان للاستهلاك. تطبيق الأستاذ (`apps/teacher/`) يبدأ من الصفر أيضاً (لا `pubspec.yaml`)
ويحتاج: تسجيل `apps/teacher` في `workspace:` الجذري، الشاشات الثماني المذكورة في
[PHASE-5-STAGES.MD §4.1](PHASE-5-STAGES.MD)، وتفعيل بنود `SyncEngine` السابعة والثامنة والتاسعة
(ترشيح العرض، قفل `editable`، الإحصاءات المشتقّة) التي تُركت للشاشات عمداً.
