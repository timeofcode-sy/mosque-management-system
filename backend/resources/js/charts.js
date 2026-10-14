/**
 * مخططات اللوحة: ApexCharts خلف مكوّن Alpine واحد `nzChart`.
 *
 * الألوان لا تُكتب هنا: تُقرأ من رموز الهوية (CSS variables) لحظةَ الرسم، فتتبع ثيم المعهد
 * والوضع الفاتح والليلي. ويُعاد الرسم متى تبدّل صنف `dark` على الجذر، فلا يبقى مخططٌ فاتحٌ
 * في صفحةٍ أُظلمت.
 *
 * الزمن يجري من اليمين إلى اليسار كما يُقرأ السطر العربي: أقدم يومٍ على اليمين، والمحور
 * الرأسيّ على اليمين معه.
 */
// المكتبة (~500KB) تُحمَّل عند أول مخططٍ في الصفحة لا مع كل صفحة.
let library = null;
const apex = () => (library ??= import('apexcharts').then((module) => module.default));

const token = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

/** أسماء الألوان في إعداد المخطط ← رموز الهوية. */
const COLORS = {
    primary: '--primary',
    bronze: '--bronze-ink',
    present: '--success',
    absent: '--danger',
    late: '--warning',
    excused: '--info',
    danger: '--danger',
    muted: '--ink-muted',
};

const color = (name) => token(COLORS[name] ?? name) || name;

const isDark = () => document.documentElement.classList.contains('dark');

const number = (value, digits = 1) =>
    Number(value).toLocaleString('en-US', { maximumFractionDigits: digits });

function base() {
    const font = getComputedStyle(document.body).fontFamily;

    return {
        chart: {
            fontFamily: font,
            foreColor: token('--ink-muted'),
            background: 'transparent',
            toolbar: { show: false },
            zoom: { enabled: false },
            parentHeightOffset: 0,
            animations: {
                enabled: true,
                speed: 700,
                animateGradually: { enabled: true, delay: 60 },
                dynamicAnimation: { enabled: true, speed: 400 },
            },
        },
        theme: { mode: isDark() ? 'dark' : 'light' },
        grid: {
            borderColor: token('--line'),
            strokeDashArray: 4,
            padding: { left: 20, right: 12 },
        },
        tooltip: { theme: isDark() ? 'dark' : 'light', style: { fontFamily: font } },
        legend: { fontFamily: font, labels: { colors: token('--ink') } },
        dataLabels: { enabled: false },
    };
}

/**
 * منحنى نسبةٍ يومية: النقاط [{label, value, detail}]. يومٌ بلا قياس (value = null) لا يُرسم أصلاً:
 * الخطّ يصل أيامَ التفقّد بعضَها ببعض، فلا يهبط إلى الصفر في العطل ولا يتقطّع.
 */
function trend(config) {
    // الأقدم يميناً: تُعكس السلسلة ويُنقل المحور الرأسي إلى اليمين.
    const points = config.points.filter((point) => point.value !== null && point.value !== undefined).reverse();
    const main = color(config.color ?? 'primary');

    return {
        ...base(),
        chart: { ...base().chart, type: 'area', height: config.height ?? 240 },
        series: [{ name: config.name ?? 'نسبة الحضور', data: points.map((point) => point.value) }],
        colors: [main],
        stroke: { curve: 'smooth', width: 3 },
        fill: {
            type: 'gradient',
            gradient: {
                type: 'vertical',
                shade: isDark() ? 'dark' : 'light',
                shadeIntensity: 0,
                gradientToColors: [main],
                opacityFrom: 0.38,
                opacityTo: 0.02,
                stops: [0, 100],
            },
        },
        markers: {
            size: 4,
            strokeWidth: 2,
            strokeColors: main,
            colors: [token('--surface-raised')],
            hover: { size: 7 },
        },
        xaxis: {
            categories: points.map((point) => point.label),
            tickAmount: Math.min(Math.max(points.length - 1, 1), 8),
            labels: { rotate: 0, hideOverlappingLabels: true, style: { fontSize: '11px' } },
            axisBorder: { show: false },
            axisTicks: { show: false },
            tooltip: { enabled: false },
        },
        yaxis: {
            opposite: true,
            min: 0,
            max: config.max ?? 100,
            tickAmount: 4,
            labels: { formatter: (value) => `${number(value, 0)}${config.unit ?? '%'}` },
        },
        tooltip: {
            ...base().tooltip,
            x: { show: true },
            y: {
                formatter: (value, { dataPointIndex }) => {
                    if (value === null || value === undefined) {
                        return 'لا تفقّد';
                    }

                    const detail = points[dataPointIndex]?.detail;

                    return `${number(value)}${config.unit ?? '%'}${detail ? ` · ${detail}` : ''}`;
                },
            },
        },
        noData: { text: config.emptyText ?? 'لا بيانات' },
    };
}

/**
 * دونات توزيع: الشرائح [{label, value, color}]، ومجموعها في الوسط.
 */
function donut(config) {
    const segments = config.segments.filter((segment) => segment.value > 0);
    const total = segments.reduce((sum, segment) => sum + segment.value, 0);

    return {
        ...base(),
        chart: { ...base().chart, type: 'donut', height: config.height ?? 280 },
        series: segments.map((segment) => segment.value),
        labels: segments.map((segment) => segment.label),
        colors: segments.map((segment) => color(segment.color)),
        stroke: { width: 3, colors: [token('--surface-raised')] },
        legend: { ...base().legend, position: 'bottom', horizontalAlign: 'center', itemMargin: { horizontal: 10, vertical: 4 } },
        plotOptions: {
            pie: {
                expandOnClick: true,
                donut: {
                    size: '68%',
                    labels: {
                        show: true,
                        value: {
                            color: token('--ink'),
                            fontSize: '26px',
                            fontWeight: 600,
                            formatter: (value) => number(value, 0),
                        },
                        total: {
                            show: true,
                            showAlways: true,
                            label: config.totalLabel ?? 'المجموع',
                            color: token('--ink-muted'),
                            formatter: () => number(total, 0),
                        },
                    },
                },
            },
        },
        tooltip: {
            ...base().tooltip,
            y: { formatter: (value) => `${number(value, 0)} · ${number((value / total) * 100)}%` },
        },
    };
}

const BUILDERS = { trend, donut };

function register(Alpine) {
    Alpine.data('nzChart', (config) => ({
        chart: null,
        observer: null,

        init() {
            this.render();

            // يُعاد الرسم بألوان الوضع الجديد متى تبدّل الفاتح والليلي.
            this.observer = new MutationObserver(() => this.render());
            this.observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
        },

        async render() {
            const ApexCharts = await apex();

            this.chart?.destroy();
            this.chart = new ApexCharts(this.$refs.canvas, BUILDERS[config.type](config));
            this.chart.render();
        },

        destroy() {
            this.observer?.disconnect();
            this.chart?.destroy();
        },
    }));
}

// Livewire يُطلق Alpine عند DOMContentLoaded، وهذه الوحدة تُنفَّذ قبله.
document.addEventListener('alpine:init', () => register(window.Alpine));
