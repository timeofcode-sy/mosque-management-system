<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Contracts\Filesystem\FileNotFoundException;
use Illuminate\Support\Facades\File;

class GenerateFullProjectCompact extends Command
{
    protected $signature = 'generate:exportProject';

    protected $description = 'Generate FullProject.php to AI';

    /**
     * @throws FileNotFoundException
     */
    public function handle(): void
    {
        $outputPath = base_path('FullProject.php');
        $content = "// === FULL PROJECT COMPACT EXPORT ===\n";

        $sections = [
            'Controllers' => app_path('Http/Controllers'),
            //            'ApiControllers' => app_path('Http/Controllers/Api'),
            'Services' => app_path('Services'),
            'Models' => app_path('Models'),
            'Enums' => app_path('Enums'),
            'Providers' => app_path('Providers'),
            'Resources' => app_path('Http/Resources'),
            'Requests' => app_path('Http/Requests'),
            'Repositories' => app_path('Repositories'),
            'Helpers' => app_path('Helpers'),
            'Middleware' => app_path('Http/Middleware'),
            'Jobs' => app_path('Jobs'),
            'Processors' => app_path('Processors'),
            'Console' => app_path('Console'),
            'Migrations' => database_path('migrations'),
            'Seeders' => database_path('seeders'),
            'Factories' => database_path('factories'),
            'Bootstrap' => base_path('Bootstrap'),
            'Config' => base_path('config'),
            'Routes' => base_path('routes'),
            'Tests' => base_path('Tests'),
            //            'Resources_views_pdf' => base_path('resources/views/pdf'),
            //    'Resources_view' => base_path('resources/views'),
            //    'Resources_view_layouts' => base_path('resources/views/layouts'),
            //    'Resources_view_layouts_main' => base_path('resources/views/layouts_main'),
            //    'Resources_view_main' => base_path('resources/views/main'),
            //    'Resources_view_requests' => base_path('resources/views/requests'),
            //    'Resources_view_services' => base_path('resources/views/services'),
            //    'Resources_view_users' => base_path('resources/views/users'),
            //    'Resources_view_settings' => base_path('resources/views/setting'),
            //    'Lang_ar' => base_path('resources/lang/ar'),
            //    'Lang_en' => base_path('resources/lang/en'),
            'ApiCollections' => base_path('api-collections'),
        ];

        foreach ($sections as $sectionName => $path) {
            if (! File::exists($path)) {
                $this->warn("$sectionName directory not found, skipping...");

                continue;
            }

            $isYamlSection = $sectionName === 'ApiCollections';

            $files = File::allFiles($path);
            $files = array_filter($files, function ($file) use ($sectionName, $isYamlSection) {
                if ($isYamlSection) {
                    return in_array($file->getExtension(), ['yaml', 'yml']);
                }
                if ($sectionName === 'Migrations') {
                    return $file->getExtension() === 'php';
                }

                return $file->getExtension() == 'php';
            });

            usort($files, function ($a, $b) {
                return strcmp($a->getFilename(), $b->getFilename());
            });

            $content .= "\n// === [$sectionName] ===\n";

            foreach ($files as $file) {
                $filename = str_replace(base_path().'/', '', $file->getRealPath());
                $fileContent = File::get($file->getRealPath());

                if ($isYamlSection) {
                    // YAML
                    $fileContent = preg_replace('/#.*$/m', '', $fileContent);
                    $fileContent = preg_replace('/^\s*$(?:\r\n?|\n)/m', '', $fileContent);
                } else {
                    // PHP
                    $fileContent = str_replace(['<?php', '?>'], '', $fileContent);
                    $fileContent = preg_replace('/^use .*;/m', '', $fileContent);
                    $fileContent = preg_replace('/^declare\(.*\);/m', '', $fileContent);
                    $fileContent = preg_replace('/\/\/.*$/m', '', $fileContent);
                    $fileContent = preg_replace('/#.*$/m', '', $fileContent);
                    $fileContent = preg_replace('#/\*.*?\*/#s', '', $fileContent);
                    $fileContent = preg_replace('/^\s*$(?:\r\n?|\n)/m', '', $fileContent);
                    $fileContent = preg_replace('/\s*{\s*/', '{', $fileContent);
                    $fileContent = preg_replace('/\s*}\s*/', '}', $fileContent);
                    $fileContent = preg_replace('/\s*;\s*/', ';', $fileContent);
                    $fileContent = preg_replace('/\s*\(\s*/', '(', $fileContent);
                    $fileContent = preg_replace('/\s*\)\s*/', ')', $fileContent);
                    $fileContent = preg_replace('/\s*,\s*/', ',', $fileContent);
                    $fileContent = preg_replace('/[ ]{2,}/', ' ', $fileContent);
                    $fileContent = preg_replace('/^\s+/m', '', $fileContent);
                }

                $content .= "// ===== $filename =====\n";
                $content .= $fileContent."\n";
            }
        }

        File::put($outputPath, $content);

        $this->info('FullProject.php generated successfully with minified, cleaned, organized content.');
    }
}
