# نزلاً (Nuzuln) — نظام إدارة معهد تحفيظ القرآن

<img src="design/logo/nuzuln-icon.svg" alt="نزلاً" width="96" />

مستودع موحّد يضم الباك إند (Laravel 13 + Livewire 4) وتطبيقَي Flutter — **«نزلاً» للهاتف** (الأستاذ وولي الأمر
والطالب في تطبيقٍ واحد) و**برنامج الإدارة** — تعمل كلُّها على **نموذج بيانات واحد**، مع تفقّد يُسجَّل أوف-لاين
ويتزامن دون فقدان بيانات.

**المطوِّر والمالك:** شركة **timeofcode** · **اسم التطبيق:** nuzuln (نزلاً) · معرّفا أندرويد:
`com.timeofcode.nuzuln` (الهاتف) و`com.timeofcode.nuzuln.admin` (الإدارة).

## البنية

| المسار | المحتوى |
|---|---|
| `backend/` | Laravel 13 · Livewire 4 · Flux · Fortify · Spatie Permission — لوحة التحكم + API |
| `apps/nuzuln/` | **تطبيق «نزلاً» للهاتف** (Android) — الأستاذ وولي الأمر والطالب؛ السطحُ يُحسم من دور الحساب عند الدخول ([README](apps/nuzuln/README.md)) |
| `apps/admin_desktop/` | برنامج المشرف (Windows + Android) — إدارة كاملة أوف-لاين، وعلى الهاتف بشريطٍ سفلي |
| `packages/mousqe_core/` | نماذج + drift(SQLite) + محرك المزامنة + عميل API |
| `packages/nuzul_ui/` | هوية نزلاً v3 لـ Flutter: رموز، سمتان (فاتح وليلي)، خطوط، أيقونات، شعار، نقش، مكوّنات Nz |
| `packages/mousqe_ui/` | ثيم التطبيقات فوق nuzul_ui + ودجتس مشتركة (شارات، بطاقات، مزامنة، دخول) + التحديثُ من داخل التطبيق |
| `packages/mousqe_installer/` | إضافةُ أندرويد التي تسلّم ملفَّ التحديث إلى مثبّت النظام |
| `design/` | رموز الهوية (`design-tokens.json`) وشرح المولِّدات والقرارات — المصدر الكامل في `brand-v3/` (غير مُتتبَّع)؛ انظر [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md) |
| `design/logo/` | الشعار السابق وشعار معهد عمر الفاروق للأرشيف |
| `marketing/` | الحزمة التسويقية: عرضٌ تقديمي تفاعلي، ومنشوراتٌ وريلز، وسكتشات، ولقطاتٌ من الموقع والتطبيقين — غير مُتتبَّع في git لحجمه، وأدواتُ توليده في `marketing/_source` |
| `docs/` | الوثائق كلُّها وفهرسُها [docs/README.md](docs/README.md): التشغيلُ والإصدارات (`VERSION.md`) والمرجعُ التقني، وخططُ المراحل في `phases/` ونقاطُ تفتيشها في `checkpoints/` |

## البدء

```bash
# الباك إند
cd backend
composer install && npm install
php artisan migrate:fresh --seed
composer run dev            # serve + queue + vite

# تطبيقات فلاتر
melos bootstrap
melos run test
```

## التحقق قبل أي إنهاء

```bash
cd backend
php artisan test --compact
vendor/bin/pint --dirty --format agent
```

## التصدير والإصدارات

```powershell
.\scripts\export-apps.ps1 -DryRun             # ما الإصدار التالي؟ بلا بناء
.\scripts\export-apps.ps1                     # بيتا جديدة للتطبيقات في dist/beta/<الإصدار>/
.\scripts\export-apps.ps1 -Channel release    # إصدارٌ نهائي (من commit نظيف)
```

كلُّ تصديرٍ ناجح يضيف نسخته إلى [`docs/VERSION.md`](docs/VERSION.md) — رقمٌ واحد للنظام، بقسمين: الإصدار والبيتا.
ثم يُنشر من اللوحة («تحديثات التطبيقات») فيصل الأجهزةَ ويُثبَّت من داخل كل تطبيق: [docs/APP-UPDATES.md](docs/APP-UPDATES.md).

## التشغيل والنشر

محلياً على شبكة مشتركة أو على Hostinger Cloud، وتصدير التطبيقات: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md). وضمُّ معهدٍ ببياناته القديمة: [docs/IMPORT.md](docs/IMPORT.md). وهوية الواجهات ونظام التصميم: [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md).

انظر [`docs/PLAN.md`](docs/PLAN.md) للخطة وحالتها، و[`docs/ERD.md`](docs/ERD.md) لنموذج البيانات، وآخر نقطة تفتيش في
[`docs/checkpoints/`](docs/checkpoints/) لتفاصيل ما نُفِّذ — والفهرسُ كلُّه في [`docs/README.md`](docs/README.md).
