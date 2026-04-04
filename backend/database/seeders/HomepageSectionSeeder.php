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
                'key' => 'project_recommendations',
                'label' => 'Project Recommendations',
                'position' => 1,
                'is_enabled' => true,
                'data_source' => 'api/homepage-recommendations'
            ],
            [
                'key' => 'top_freelancers',
                'label' => 'Top Freelancers',
                'position' => 2,
                'is_enabled' => true,
                'data_source' => 'api/marketplace-tasks'
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
