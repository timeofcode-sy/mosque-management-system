# وثائق نزلاً

فهرسُ ما في هذا المجلّد، مقسوماً بمن يقرؤه. والبدايةُ لمن لا يعرف النظام:
[README المستودع](../README.md) ثم [ARCHITECTURE.md](ARCHITECTURE.md).

## التشغيل والإصدارات

| الملف | ما فيه |
|---|---|
| [DEPLOYMENT.md](DEPLOYMENT.md) | التشغيلُ محلياً على شبكة المسجد أو على الاستضافة، والجدولة، والنسخ الاحتياطي، وتصديرُ التطبيقات |
| [APP-UPDATES.md](APP-UPDATES.md) | نشرُ إصدارٍ من اللوحة ليصل الأجهزةَ ويُثبَّت من داخل التطبيق — اختياريّاً أو إلزاميّاً — ومفتاحُ التوقيع |
| [VERSION.md](VERSION.md) | سجلُّ كلِّ نسخةٍ خرجت: الإصدارُ والبيتا ورقمُ البناء وأبرزُ التغييرات — يكتبه `scripts/export-apps.ps1` |
| [IMPORT.md](IMPORT.md) | ضمُّ معهدٍ ببياناته القديمة من مصنّف Excel وتصديرُه بالبنية نفسها |

## المرجع التقني

| الملف | ما فيه |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | البنية: الخادمُ والتطبيقاتُ والحزمُ المشتركة وكيف تتكلّم |
| [ERD.md](ERD.md) | نموذجُ البيانات — الجداولُ وعلاقاتُها |
| [API.md](API.md) | عقدُ `/api/v1`: النقاطُ وحرّاسُها وأشكالُ الاستجابة ورموزُ الأخطاء |
| [SYNC-PROTOCOL.md](SYNC-PROTOCOL.md) | المزامنةُ أوف-لاين: الطابور، `sync/pull` و`sync/push`، والتعارضات |
| [CLIENTS.md](CLIENTS.md) | ما يفعله كلُّ تطبيقٍ وما يقرؤه من الخادم |
| [APPS-FEATURES.md](APPS-FEATURES.md) | مزايا التطبيقات شاشةً شاشة لكل دور |
| [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md) | هويةُ «نزلاً» v3 في الويب وFlutter: الرموزُ والسمتان والخطوطُ والمكوّنات |

## الخطة وتاريخها

| الملف | ما فيه |
|---|---|
| [PLAN.md](PLAN.md) | الخطةُ العامة وحالةُ كل مرحلة وسجلُّ تغييراتها |
| [phases/](phases/) | خطةُ العمل المفصَّلة لكل مرحلةٍ قُسِّمت مراحلَ فرعية — **خططٌ لا توثيقُ منفَّذ** |
| [checkpoints/](checkpoints/) | نقطةُ تفتيشٍ لكل مرحلةٍ منفَّذة: ما بُني، ولماذا، وما يحرسه من اختبارات |

### المراحل

| المرحلة | الخطة | نقاط التفتيش |
|---|---|---|
| 1 – 4 | — | [1](checkpoints/CHECKPOINT-PHASE-1.MD) · [2](checkpoints/CHECKPOINT-PHASE-2.MD) · [3](checkpoints/CHECKPOINT-PHASE-3.MD) · [4](checkpoints/CHECKPOINT-PHASE-4.MD) · [4.5](checkpoints/CHECKPOINT-PHASE-4.5.MD) · [4.6](checkpoints/CHECKPOINT-PHASE-4.6.MD) · [4.7](checkpoints/CHECKPOINT-PHASE-4.7.MD) |
| 5 | [PHASE-5-STAGES](phases/PHASE-5-STAGES.MD) | [5.1](checkpoints/CHECKPOINT-PHASE-5.1.MD) · [5.2](checkpoints/CHECKPOINT-PHASE-5.2.MD) · [5.3](checkpoints/CHECKPOINT-PHASE-5.3.MD) · [5.4](checkpoints/CHECKPOINT-PHASE-5.4.MD) |
| 6 | [PHASE-6-STAGES](phases/PHASE-6-STAGES.MD) | [6.1](checkpoints/CHECKPOINT-PHASE-6.1.MD) · [6.2](checkpoints/CHECKPOINT-PHASE-6.2.MD) · [6.3](checkpoints/CHECKPOINT-PHASE-6.3.MD) · [6.4](checkpoints/CHECKPOINT-PHASE-6.4.MD) · [6.5](checkpoints/CHECKPOINT-PHASE-6.5.MD) · [6.6](checkpoints/CHECKPOINT-PHASE-6.6.MD) |
| 7 | [PHASE-7-STAGES](phases/PHASE-7-STAGES.MD) | [7.1](checkpoints/CHECKPOINT-PHASE-7.1.MD) · [7.2](checkpoints/CHECKPOINT-PHASE-7.2.MD) · [7.3](checkpoints/CHECKPOINT-PHASE-7.3.MD) · [7.4](checkpoints/CHECKPOINT-PHASE-7.4.MD) |
| 8 | [PHASE-8-STAGES](phases/PHASE-8-STAGES.MD) | [8.1](checkpoints/CHECKPOINT-PHASE-8.1.MD) · [8.2](checkpoints/CHECKPOINT-PHASE-8.2.MD) |
| 9 | [PHASE-9-STAGES](phases/PHASE-9-STAGES.MD) | [9.1](checkpoints/CHECKPOINT-PHASE-9.1.MD) · [9.2](checkpoints/CHECKPOINT-PHASE-9.2.MD) |

## وثائقُ خارج هذا المجلّد

تبقى بجانب ما تصفه:

| الملف | ما فيه |
|---|---|
| [apps/nuzuln/README.md](../apps/nuzuln/README.md) · [NEXT-STEPS.md](../apps/nuzuln/NEXT-STEPS.md) | تطبيقُ «نزلاً» للهاتف وخطواتُه التالية |
| [design/README.md](../design/README.md) | رموزُ الهوية ومولِّداتُها |
| [packages/nuzul_ui/README.md](../packages/nuzul_ui/README.md) | نظامُ التصميم في Flutter |
| [backend/AGENTS.md](../backend/AGENTS.md) | قواعدُ العمل في الخادم (Laravel Boost) |

## اصطلاحاتُ الكتابة

- بالعربية، والأرقامُ **لاتينية** (0–9) في كل مكان، والمعرّفاتُ والأوامرُ في `code`.
- الجداولُ بفاصل `|---|` بلا مسافات، والفقراتُ أسطرٌ طويلة لا تُكسر — قواعدُ `markdownlint` في
  [`.markdownlint.jsonc`](../.markdownlint.jsonc) على هذا.
- نقطةُ تفتيشٍ جديدة في `checkpoints/` باسم `CHECKPOINT-PHASE-<المرحلة>.MD`، وخطةُ مرحلةٍ في
  `phases/` باسم `PHASE-<المرحلة>-STAGES.MD`.
