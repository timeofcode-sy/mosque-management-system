# نزلاً (Nuzuln) — نظام إدارة معهد تحفيظ القرآن

<img src="design/logo/nuzuln-icon.svg" alt="نزلاً" width="96" />

مستودع موحّد يضم الباك إند (Laravel 13 + Livewire 4) وأربعة تطبيقات Flutter تعمل على **نموذج بيانات واحد**،
مع تفقّد يُسجَّل أوف-لاين ويتزامن دون فقدان بيانات.

## البنية

| المسار | المحتوى |
|---|---|
| `backend/` | Laravel 13 · Livewire 4 · Flux · Fortify · Spatie Permission — لوحة التحكم + API |
| `apps/teacher/` | تطبيق الأستاذ (Android/iOS) — التفقّد أوف-لاين |
| `apps/admin_desktop/` | برنامج المشرف (Windows + Android) — إدارة كاملة أوف-لاين، وعلى الهاتف بشريطٍ سفلي |
| `apps/guardian/` | تطبيق أولياء الأمور — متابعةُ الأبناء وأذوناتُ الغياب ✅ م.7 |
| `apps/student/` | تطبيق الطالب — حضورُه ورتبتُه ونقاطُه وإعلاناتُه ✅ م.8 |
| `packages/mousqe_core/` | نماذج + drift(SQLite) + محرك المزامنة + عميل API |
| `packages/nuzul_ui/` | هوية نزلاً v3 لـ Flutter: رموز، سمتان (فاتح وليلي)، خطوط، أيقونات، شعار، نقش، مكوّنات Nz |
| `packages/mousqe_ui/` | ثيم التطبيقات فوق nuzul_ui + ودجتس مشتركة (شارات، بطاقات، مزامنة، دخول) |
| `design/` | رموز الهوية (`design-tokens.json`) وشرح المولِّدات والقرارات — المصدر الكامل في `brand-v3/` (غير مُتتبَّع)؛ انظر [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md) |
| `design/logo/` | الشعار السابق وشعار معهد عمر الفاروق للأرشيف |
| `docs/` | `PLAN.md` (الخطة وسجل تغييراتها) · `ERD.md` (نموذج البيانات) · `CHECKPOINT-PHASE-*.MD` (نقطة تفتيش لكل مرحلة منفَّذة) |

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
.\scripts\export-apps.ps1                     # بيتا جديدة للتطبيقات (4 APK + ويندوز) في dist/
.\scripts\export-apps.ps1 -Channel release    # إصدارٌ نهائي (من commit نظيف)
```

كلُّ تصديرٍ ناجح يضيف نسخته إلى [`VERSION.md`](VERSION.md) — رقمٌ واحد للنظام، بقسمين: الإصدار والبيتا.

## التشغيل والنشر

محلياً على شبكة مشتركة أو على Hostinger Cloud، وتصدير التطبيقات: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md). وهوية الواجهات ونظام التصميم: [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md).

انظر `docs/PLAN.md` للخطة وحالتها، و`docs/ERD.md` لنموذج البيانات، وآخر نقطة تفتيش لتفاصيل ما نُفِّذ.
