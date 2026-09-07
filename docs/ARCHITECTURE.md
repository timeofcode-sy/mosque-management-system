# معمارية النظام — mousqe

الحالة: **2026-09-07 · محدَّث حتى المرحلة 5.4** — الباك إند واللوحة منفَّذان بالكامل (المراحل 0–5.4)،
والحزمتان المشتركتان وتطبيقُ الأستاذ ✅ منفَّذة؛ وثلاثةُ تطبيقاتٍ ⬜ لم تبدأ (م.6–8).

> هذا الملف هو **الصورة العامة**: من يتكلّم مع من وبأي نمط. التفاصيل في:
> [ERD.md](ERD.md) نموذج البيانات · [PLAN.md](PLAN.md) الخطة والمراحل ·
> [API.md](API.md) عقد الـ API · [SYNC-PROTOCOL.md](SYNC-PROTOCOL.md) المزامنة أوف-لاين ·
> [CLIENTS.md](CLIENTS.md) العلاقات بين التطبيقات.
> لا يُعاد هنا شيءٌ منها — يُربط إليه.

---

## 1. مخطط المكوّنات

```
mousqe/
│
├─ backend/  ✅  Laravel 13 · Livewire 4 · Flux · Tailwind 4 · Sanctum · spatie/permission
│    ├─ routes/web.php    ← اللوحة: 27 شاشة Livewire فوق قاعدة البيانات مباشرة (بلا REST)
│    ├─ routes/api.php    ← /api/v1: 14 نقطة بتوكن Sanctum لعملاء فلاتر
│    ├─ app/Actions/      ← كل كتابة — المصدر المشترك بين اللوحة والـ API
│    ├─ app/Queries/      ← كل قراءة
│    └─ (MySQL/MariaDB إنتاجاً · SQLite تطويراً)
│
├─ packages/  ✅ (م.5.2)
│    ├─ mousqe_core   ← نماذج freezed + drift(SQLite) + SyncEngine + ApiClient + تخزين التوكن
│    └─ mousqe_ui     ← نظام التصميم: design-tokens.json افتراضاً + ألوان المعهد من /bootstrap
│
└─ apps/
     ├─ teacher/     ✅ م.5.3 · Android ────────┐
     ├─ admin_desktop/  ⬜ م.6 · Windows      ├─ REST /api/v1 + مزامنة أوف-لاين
     ├─ guardian/       ⬜ م.7 · Android+iOS  │
     └─ student/        ⬜ م.8 · Android+iOS ─┘
```

مسار البيانات — الكتابة تلتقي في `app/Actions/` مهما كان مصدرها:

```
اللوحة (Livewire)  ─────────────────────► Actions ──► DB
                                             ▲          │
عملاء فلاتر ──► POST /api/v1/sync/push ──► SyncPush ──► change_log
                                                            │
عملاء فلاتر ◄── GET  /api/v1/sync/pull ◄── SyncPull ◄───────┘
```

`change_log` هو القناة التي يقرأ منها العملاء بعضهم من بعض: تفقّدُ الأستاذ أوف-لاين يصل إلى
الديسكتوب عبر هذا الجدول.

> ✅ **م.5.1: صار قناةً بالاتجاهين.** كان `RecordChange` لا يُستدعى إلا من `SyncPush`، فكتابات
> اللوحة (تسجيل طالب، تعديل تفقّد، مراجعة إذن) لا تظهر في `sync/pull` إطلاقاً. صار التسجيلُ أثراً
> بنيوياً: مراقبٌ على كل نموذج ينفّذ `App\Contracts\Syncable` — [SYNC-PROTOCOL.md §2](SYNC-PROTOCOL.md).

> 🔴 **م.5.3: التيّار تيّارُ تغييرات لا لقطةُ حالة.** `SyncPull` يقرأ `change_log` **وحده** ولا يمسّ
> جداول الدومين، فالصفُّ الذي لم يمرّ بالمراقب لا سبيل لأي عميل أن يعرفه — لا في `since=0` ولا
> بعدها. وثلاثةُ مصادر تُنتج صفوفاً كهذه: بياناتُ ما قبل م.5.1، والبذرُ الذي يعطّل التسجيل للسرعة،
> والإدراجُ بالجملة الذي لا يُطلق أحداث Eloquent. يردمها `php artisan sync:backfill-change-log`
> (مُتماثِل، ويجري تلقائياً في نهاية كل بذرة) — [SYNC-PROTOCOL.md §10](SYNC-PROTOCOL.md) البند 9.

---

## 2. نمط الاتصال لكل عميل

| العميل | المرحلة | نمط الاتصال | أوف-لاين | مخزن محلي |
|---|---|---|---|---|
| **اللوحة** (Livewire) | ✅ 0–5.3 | مكوّنات Livewire فوق نفس القاعدة **مباشرة — بلا REST إطلاقاً** | ✗ | ✗ |
| **الأستاذ** | ✅ م.5.3 | REST `/api/v1` + `sync/push` + `sync/pull` | ✓ كامل | drift/SQLite |
| **الديسكتوب** | ⬜ م.6 | REST `/api/v1` + `sync/push` + `sync/pull` | ✓ كامل | drift/SQLite |
| **الأهل** | ⬜ م.7 | REST `/api/v1` + `sync/pull` فقط (بلا `sync.push`) | ✓ قراءة | drift/SQLite |
| **الطالب** | ⬜ م.8 | REST `/api/v1` + `sync/pull` فقط (بلا `sync.push`) | ✓ قراءة | drift/SQLite |

الأهل والطالب **لا يملكان صلاحية `sync.push`** أصلاً في `RolesAndPermissionsSeeder` — كتابتهما الوحيدة
هي `POST /guardian/excuses` عبر REST مباشر لا عبر طابور المزامنة. خلاصة الصلاحيات في
[ERD.md §7](ERD.md) وحارس كل نقطة في [API.md §2](API.md).

---

## 3. الطبقة المشتركة — الخادم لا يكتب منطقه مرّتين

القاعدة المعتمدة منذ المرحلة 3 ([PLAN.md §5](PLAN.md)): **كل كتابة تمرّ بـ`app/Actions/`، وكل قراءة
بـ`app/Queries/`**. أثرها المعماري أن `sync/push` ليس مساراً موازياً للوحة بل **غلافاً حولها**:
`SyncPush` يحقن أفعال اللوحة نفسها في مُنشئه ويستدعيها.

| نوع عملية `sync/push` | الفعل المستدعى | تستدعيه اللوحة أيضاً |
|---|---|---|
| `attendance.session.open` | `OpenAttendanceSession` | ✅ `pages::attendance.take` |
| `attendance.take` | `TakeAttendance` (بعد `ResolveAttendanceConflicts`) | ✅ `pages::attendance.take` |
| `attendance.teacher.take` | `TakeTeacherAttendance` | ✅ |
| `attendance.session.complete` | `CompleteAttendanceSession` | ✅ |
| `excuse.submit` | `SubmitAbsenceExcuse` | ✅ `pages::excuses.index` — و`POST /guardian/excuses` |
| `recitation.save` | `SaveRecitation` | ✅ `livewire::session-student-recitations` |
| `recitation.delete` | `DeleteRecitation` | ✅ |
| `points.award` | `AwardStudentPoints` | ✅ |

✅ **م.5.1: الاشتراك اكتمل.** كان المشترك **منطق الكتابة** لا **تسجيل التغيير**: `RecordChange`
مستدعىً من `SyncPush` وحده، فالمسار نفسه حين يُسلَك من اللوحة يكتب في الجداول ولا يكتب في
`change_log`. صار التسجيل أثراً بنيوياً على مستوى **النموذج** لا الفعل — `SyncRecorder` +
`RecordsSyncChanges` — فيستوي مصدرُ الكتابة، ولم يعد على كاتبِ فعلٍ جديد أن يتذكّر شيئاً:

```
شاشة Livewire  ┐
sync/push      ├─► app/Actions/ ─► نموذج Syncable ─► مراقب ─► change_log
REST مباشر     ┘                                              (صفٌّ لكل صفّ تغيّر)
أمر artisan    ┘
```

الأصناف المشتركة الأخرى في `app/Support/`: `PointsSettings` · `AttendanceSettings` · `InstituteTheme` ·
`LateMinutes` · `AttendanceRate` · `Quran` · `HijriDate` · `DateRange` · `Credentials` · `SyncRecorder` ·
`SyncScope`. أمّا حسم النطاق فمنفصل عمداً: `PanelScope` للوحة و`ApiScope` للـ API — والفرق بينهما
مقصود (§6 أدناه و[API.md §4](API.md)).

---

## 4. أي دور يصل إلى أيّ سطح

مصفوفة «التطبيق × الأدوار» الكاملة في [CLIENTS.md §1](CLIENTS.md). ما يخصّ المعمارية هنا هو
**السطحان** لا التطبيقات:

| السطح | الحرّاس بالترتيب | من يعبره |
|---|---|---|
| اللوحة (`web`) | `auth` → `verified` → `SetPanelInstituteScope` → `EnsureUserIsActive` → `permission:` لكل مجموعة مسارات | من يملك الصلاحية المطلوبة — عملياً `developer` · `super_admin` · `admin` · `supervisor`، و`teacher` جزئياً |
| الـ API (`api`) | `auth:sanctum` → `EnsureUserIsActive` → `institute.scope` → `permission:`/`role:` | كل حساب له سجلّ `teacher` أو `guardian` أو `student` مرتبط به |

نتيجة معمارية تستحقّ التسجيل: **`admin` و`super_admin` و`developer` لا يعبرون الـ API إطلاقاً** — لا
لأنهم ممنوعون بصلاحية، بل لأن `ApiScope` يحسم المعهد من
`user->teacher ?? user->guardian ?? user->student`، وحساب مدير المعهد لا يحمل أياً من الثلاثة فيُرفض
بـ 422. الـ API مبنيّ لجمهور التطبيقات وحده. و`supervisor` يصله فقط إن كان له سجلّ `teacher` مرتبط.

🔄 **2026-09-07: هذه النتيجة تُنقَض في المرحلة 6 عمداً.** قرارُ صاحب المشروع أن الديسكتوب يخدم
**المشرف ومديرَ المعهد معاً** ([APPS-FEATURES.md §4](APPS-FEATURES.md))، فلم يعد «الاتّكاء على أن
المشرف أستاذٌ أيضاً» طريقاً مقبولاً: ربطُ حسابَي `supervisor` و`admin` بمعهدٍ هو **البندُ الأول في
م.6** ([CLIENTS.md §5](CLIENTS.md) البند 2). وحتى ذلك الحين يبقى الوصفُ أعلاه واقعَ الكود.

---

## 5. تدفّق مرجعي واحد — تفقّد من تطبيق الأستاذ أوف-لاين

المسار الكامل لصفٍّ واحد، بأسماء الأصناف الفعلية:

```
1. الأستاذ · بلا شبكة
   mousqe_core يولّد uuid للجلسة + op_uuid لكل عملية، ويضعها في طابور drift المحلي.

2. عودة الشبكة
   POST /api/v1/sync/push
   { device_uuid, operations: [ {op_uuid, type:"attendance.session.open", …},
                                {op_uuid, type:"attendance.take",        …} ] }

3. الخادم
   auth:sanctum → EnsureUserIsActive → SetApiInstituteScope (يضبط مفتاح فريق spatie)
                → permission:sync.push → SyncController::push → SyncPush
   لكل عملية:  op_uuid موجود في change_log؟  ⇒ skipped (idempotent)
               وإلا: DB::transaction ⇒ ResolveAttendanceConflicts ⇒ TakeAttendance
                     ⇒ مراقبُ Syncable يكتب change_log لكل صفٍّ تغيّر

4. الأثر في القاعدة
   attendances (صفّ لكل طالب) + attendance_sessions.status
   + change_log (صفٌّ لكل صفّ تغيّر، بـ scope_key = "institute:{uuid}")
   + sync_conflicts إن رُفض صفّ (نادر — SYNC-PROTOCOL §5)

5. المشرف على اللوحة
   لا مزامنة أصلاً — pages::attendance.index يقرأ AttendanceBoardQuery من نفس الجداول فوراً.

6. الديسكتوب
   GET /api/v1/sync/pull?since={last_pulled_seq}&app=admin_desktop&device_uuid=…
   ⇒ SyncPull يعيد صفوف change_log ضمن scope_key نفسه ⇒ يحدّث sync_devices.last_pulled_seq
   ⇒ mousqe_core يطبّقها على drift المحلي.

7. ✅ والاتجاه المعاكس يعمل — م.5.1
   لو عدّل المشرفُ الصفَّ نفسه من اللوحة في الخطوة 5، كُتب له صفُّ change_log بحمولة
   صفّ الحضور، فيصل التعديلُ إلى تطبيق الأستاذ وإلى الديسكتوب في سحبهما التالي.
```

الفارق بين الخطوتين 5 و6 هو **جوهر هذه المعمارية**: اللوحة تقرأ الحقيقة مباشرة، والعملاء يقرؤون
تيّار تغييراتها.

---

## 6. القرارات المعمارية

| القرار | لماذا |
|---|---|
| **اللوحة Livewire مباشرة لا فوق `/api/v1`** | اللوحة متّصلة دائماً وتعمل على الخادم نفسه؛ إقحام طبقة REST بينها وبين قاعدتها كان سيُضاعف سطح الاختبار ويُدخل تسلسلاً وفكَّ تسلسل بلا مقابل. والاشتراك المطلوب فعلاً — منطق الكتابة — محقَّق أصلاً بـ`app/Actions/` (§3) |
| **Flutter Desktop لا Electron للديسكتوب** | ≈٧٠٪ من كود تطبيق الأستاذ يُعاد استخدامه ([PLAN.md §9](PLAN.md)) وينضمّ إلى نفس `mousqe_core` و`mousqe_ui`؛ Electron كان يعني محرّك مزامنة ثانياً بلغة ثانية لنفس البروتوكول |
| **مستودع موحّد** | الباك إند والتطبيقات يتشاركان **نموذج بيانات واحداً** وملف توكنات تصميم واحداً؛ فصلهما كان سيجعل كل تعديل في [ERD.md](ERD.md) تغييراً متزامناً على مستودعين |
| **`design-tokens.json` مصدراً واحداً للألوان** | يُولَّد منه `@theme` في Tailwind و`ThemeData` في `mousqe_ui` ⇒ تطابق بصري مضمون بين الويب والتطبيقات بلا مزامنة يدوية |
| **ثلاثة ألوان لكل معهد فوق التوكنات** 🔄 م.5.1 | التوكنات صارت **الافتراضيَّ لا المفروض**: `institutes.settings['theme']` يحمل ثلاثة ألوان يُدخلها مديرُ المعهد، ويشتقّ منها `InstituteTheme` سلالمَ التدرّج كاملة. ولماذا ثلاثة لا لوحة كاملة؟ لأن من يُدخلها ليس مصمّماً — والاشتقاق الخوارزمي يمنع تبايناً غيرَ مقروء. تُبثّ في `/bootstrap` وفي `sync/pull` معاً، فتُدخَل مرّةً وتتوحّد بها خمسةُ أسطح ([API.md §3.4](API.md)) |
| **دقائق التأخير تُحسب في `TakeAttendance` لا في الشاشة** 🔄 م.5.1 | نفس مبدأ §3: الحسابُ في الفعل المشترك فيستوي مصدرُ الكتابة — لوحةٌ وتطبيقٌ ودفعةُ مزامنة تعطي الرقم نفسه لنفس الحدث. والمرجع `shifts.starts_at` لا لحظةُ فتح الجلسة، فلا يصير «تأخيرُ الطالب» تابعاً لتأخير أستاذه ([API.md §6](API.md)) |
| **`ApiScope` يرفض بدل أن يخمّن** | نظير `PanelScope` لكن **بلا سقوط افتراضي إلى «أوّل معهد نشط»**: توكنٌ بلا معهد مرتبط يُرفض صراحةً. التخمين على اللوحة يُصحّحه المستخدم بمبدّل المعاهد، وعلى الـ API يكتب بيانات في معهد خطأ بلا أن يلاحظ أحد |
| **`change_log` قناة واحدة لا قناتان** | كل كتابة تمرّ بـ`RecordChange` فلا تلزم آلية بثّ ثانية. ✅ **اكتمل في م.5.1** — والتسجيل صار على النموذج لا على الفعل، فكاتبُ فعلٍ جديد لا يحتاج أن يتذكّر شيئاً (§3) |
| **`/bootstrap` منفصل عن `sync/pull`** | أول تشغيل يحتاج لقطةً صغيرة تُبنى بها الشاشة الأولى فوراً، لا مئات صفوف `change_log` من الصفر — [API.md §3](API.md) |

قرارات المرحلة 4.6 حول هرم الأدوار وحماية اللوحة في [CHECKPOINT-PHASE-4.6.MD](CHECKPOINT-PHASE-4.6.MD)،
وقرارات المرحلة 4.7 حول الحسابات المولَّدة والدخول باسم المستخدم في
[CHECKPOINT-PHASE-4.7.MD](CHECKPOINT-PHASE-4.7.MD).

---

## 7. نقاط مؤجَّلة تمسّ المعمارية

لا يُكرَّر هنا الجدول — الكامل في [PLAN.md §13](PLAN.md). وما يمسّ المعمارية منه تحديداً:

| البند | الأثر المعماري |
|---|---|
| **واتساب** ⬜ | يحتاج `MessageDriver` + جدول قوالب (حُذف `report_templates` في م.4.5). مكوّن خادم جديد لا يمسّ العملاء — [PLAN.md §11](PLAN.md) |
| **Firebase / FCM** ⬜ | البنية جاهزة نصفها: `devices.fcm_token` يُكتب فعلاً من `POST /devices/register` عبر `RegisterDevice`، ولا مُرسِل بعد. مطلوب قبل م.7 |
| **iOS** ⬜ | يتطلب حساب Apple Developer وجهاز macOS؛ نبدأ بأندرويد. لا أثر على الباك إند |
| **الاستضافة وقاعدة الإنتاج** ⬜ | تُحسم قبل م.9. الانتقال من SQLite إلى MySQL يمسّ الخادم وحده — العملاء يبقون على drift محلياً |
