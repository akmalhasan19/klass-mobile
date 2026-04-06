<?php

namespace Tests\Feature;

use App\Models\HomepageSection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminHomepageSectionConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_update_homepage_section_configuration_and_mobile_api_uses_it(): void
    {
        $admin = User::factory()->admin()->create();

        $projects = HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => true,
            'data_source' => 'topics',
        ]);

        $freelancers = HomepageSection::create([
            'key' => 'top_freelancers',
            'label' => 'Top Freelancers',
            'position' => 2,
            'is_enabled' => true,
            'data_source' => 'marketplace_tasks',
        ]);

        $archived = HomepageSection::create([
            'key' => 'archived_section',
            'label' => 'Archived Section',
            'position' => 3,
            'is_enabled' => true,
            'data_source' => 'legacy',
        ]);

        $this->actingAs($admin)
            ->get(route('admin.homepage-sections.index'))
            ->assertOk()
            ->assertSeeText('Homepage Configurator')
            ->assertSeeText('Curate the mobile experience: manage sections and recommended projects.')
            ->assertSeeText('Recommended Projects (Admin Curated)')
            ->assertSeeText('Top Distributed System Recommendations by Sub-Subject')
            ->assertSeeText('GET /api/homepage-recommendations')
            ->assertSeeText('No system recommendation has been distributed to more than one user yet.')
            ->assertSeeText('Section Ordering');

        $this->actingAs($admin)
            ->patch(route('admin.homepage-sections.update'), [
                'sections' => [
                    [
                        'id' => $freelancers->id,
                        'label' => 'Freelancer Pilihan',
                        'position' => 1,
                        'is_enabled' => true,
                    ],
                    [
                        'id' => $projects->id,
                        'label' => 'Belajar Minggu Ini',
                        'position' => 2,
                        'is_enabled' => true,
                    ],
                    [
                        'id' => $archived->id,
                        'label' => 'Archived Section',
                        'position' => 3,
                    ],
                ],
            ])
            ->assertRedirect();

        $this->assertDatabaseHas('homepage_sections', [
            'id' => $freelancers->id,
            'label' => 'Freelancer Pilihan',
            'position' => 1,
            'is_enabled' => true,
        ]);

        $this->assertDatabaseHas('homepage_sections', [
            'id' => $projects->id,
            'label' => 'Belajar Minggu Ini',
            'position' => 2,
            'is_enabled' => true,
        ]);

        $this->assertDatabaseHas('homepage_sections', [
            'id' => $archived->id,
            'is_enabled' => false,
        ]);

        $this->assertDatabaseHas('activity_logs', [
            'actor_id' => $admin->id,
            'action' => 'update_homepage_sections',
            'subject_type' => HomepageSection::class,
            'subject_id' => 'bulk',
        ]);

        $this->getJson('/api/homepage-sections')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.key', 'top_freelancers')
            ->assertJsonPath('data.0.label', 'Freelancer Pilihan')
            ->assertJsonPath('data.1.key', 'project_recommendations')
            ->assertJsonPath('data.1.label', 'Belajar Minggu Ini');
    }
}