<?php

namespace App\Queries;

use App\Enums\ReportScope;
use App\Models\Institute;
use App\Models\ReportTemplate;
use Illuminate\Support\Collection;

/**
 * قراءات قوالب التقارير.
 */
class ReportTemplateQuery
{
    /**
     * @return Collection<int, ReportTemplate>
     */
    public function forInstitute(?Institute $institute): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return ReportTemplate::query()
            ->where('institute_id', $institute->id)
            ->orderBy('scope')
            ->orderBy('name')
            ->get();
    }

    /**
     * القوالب المفعّلة ضمن نطاق معيّن — مصدر قائمة الاختيار في شاشة التقارير.
     *
     * @return Collection<int, ReportTemplate>
     */
    public function activeForScope(?Institute $institute, ReportScope $scope): Collection
    {
        return $this->forInstitute($institute)
            ->where('is_active', true)
            ->where('scope', $scope)
            ->values();
    }
}
