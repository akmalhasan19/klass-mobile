<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\HomepageSection;

class HomepageSectionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $sections = [
            [
                'key' => 'recommended_projects',
                'label' => 'Project Rekomendasi',
                'position' => 1,
                'is_enabled' => true,
                'data_source' => 'api/tasks/recommended'
            ],
            [
                'key' => 'freelancer_feed',
                'label' => 'Freelancer & Guru Tersedia',
                'position' => 2,
                'is_enabled' => true,
                'data_source' => 'api/users/freelancers'
            ],
        ];

        foreach ($sections as $section) {
            HomepageSection::updateOrCreate(
                ['key' => $section['key']],
                $section
            );
        }
    }
}
