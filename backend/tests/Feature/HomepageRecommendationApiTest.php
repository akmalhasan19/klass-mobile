<?php

namespace Tests\Feature;

use App\Models\Content;
use App\Models\HomepageSection;
use App\Models\RecommendedProject;
use App\Models\Topic;
use App\Models\User;
use App\Services\RecommendationAggregationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Collection;
use Laravel\Sanctum\Sanctum;
use Mockery\MockInterface;
use Tests\TestCase;

class HomepageRecommendationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_endpoint_returns_mixed_recommendation_feed_when_section_is_enabled(): void
    {
        HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => true,
            'data_source' => 'recommended_projects',
        ]);

        RecommendedProject::factory()->create([
            'title' => 'Admin Showcase',
            'display_priority' => 100,
            'source_type' => RecommendedProject::SOURCE_ADMIN_UPLOAD,
        ]);

        $topic = Topic::unguarded(fn () => Topic::create([
            'id' => 'topic-api',
            'title' => 'Topic Recommendation',
            'teacher_id' => 'teacher-api',
            'thumbnail_url' => 'https://example.com/topic-api.jpg',
            'is_published' => true,
            'order' => 1,
        ]));

        Content::create([
            'topic_id' => $topic->id,
            'type' => 'module',
            'title' => 'Topic Module',
            'data' => ['mode' => 'api'],
            'media_url' => null,
            'is_published' => true,
            'order' => 1,
        ]);

        $this->getJson('/api/homepage-recommendations')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('meta.section.key', 'project_recommendations')
            ->assertJsonPath('meta.section.enabled', true)
            ->assertJsonPath('meta.section.endpoint', '/api/homepage-recommendations')
            ->assertJsonPath('meta.section.admin_configurator_path', '/admin/homepage-sections')
            ->assertJsonPath('meta.personalization.policy_version', 'phase_0_discovery_lock')
            ->assertJsonPath('meta.personalization.audience', 'guest')
            ->assertJsonPath('meta.personalization.mode', 'default_global_feed')
            ->assertJsonPath('meta.source_breakdown.admin_upload', 1)
            ->assertJsonPath('meta.source_breakdown.system_topic', 1)
            ->assertJsonPath('meta.source_status.admin_upload.state', 'ok')
            ->assertJsonPath('meta.source_status.system_topic.state', 'ok')
            ->assertJsonPath('data.0.title', 'Admin Showcase')
            ->assertJsonPath('data.1.id', 'system_topic_topic-api');
    }

    public function test_public_endpoint_uses_aggregation_service_and_supports_limit_and_source_context(): void
    {
        HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => true,
            'data_source' => 'recommended_projects',
        ]);

        $this->mock(RecommendationAggregationService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('buildFeedSnapshot')
                ->once()
                ->andReturn([
                    'items' => collect([
                        [
                            'id' => '1',
                            'title' => 'Injected Admin Project',
                            'description' => 'Injected by mocked aggregation service.',
                            'thumbnail_url' => null,
                            'ratio' => '16:9',
                            'project_type' => 'mobile',
                            'tags' => ['Flutter'],
                            'modules' => ['Auth'],
                            'source_type' => RecommendedProject::SOURCE_ADMIN_UPLOAD,
                            'source_reference' => null,
                            'source_payload' => ['score' => 9.9],
                            'display_priority' => 99,
                            'visibility' => [
                                'is_active' => true,
                                'starts_at' => null,
                                'ends_at' => null,
                            ],
                            'created_at' => now(),
                            'updated_at' => now(),
                        ],
                        [
                            'id' => 'system_topic_mocked',
                            'title' => 'Injected Topic Project',
                            'description' => null,
                            'thumbnail_url' => null,
                            'ratio' => '16:9',
                            'project_type' => null,
                            'tags' => [],
                            'modules' => [],
                            'source_type' => RecommendedProject::SOURCE_SYSTEM_TOPIC,
                            'source_reference' => 'topic-mocked',
                            'source_payload' => ['topic_id' => 'topic-mocked'],
                            'display_priority' => 0,
                            'visibility' => [
                                'is_active' => true,
                                'starts_at' => null,
                                'ends_at' => null,
                            ],
                            'created_at' => now()->subMinute(),
                            'updated_at' => now()->subMinute(),
                        ],
                    ]),
                    'source_status' => [
                        RecommendedProject::SOURCE_ADMIN_UPLOAD => ['state' => 'ok'],
                        RecommendedProject::SOURCE_SYSTEM_TOPIC => ['state' => 'ok', 'suppressed_count' => 0],
                        RecommendedProject::SOURCE_AI_GENERATED => ['state' => 'empty'],
                    ],
                ]);
        });

        $this->getJson('/api/homepage-recommendations?limit=1&include_source_context=1')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('meta.limit.requested', 1)
            ->assertJsonPath('meta.limit.applied', 1)
            ->assertJsonPath('meta.source_status.system_topic.state', 'ok')
            ->assertJsonPath('data.0.title', 'Injected Admin Project')
            ->assertJsonPath('data.0.source_payload.score', 9.9);
    }

    public function test_public_endpoint_returns_empty_feed_when_project_section_is_disabled(): void
    {
        HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => false,
            'data_source' => 'recommended_projects',
        ]);

        RecommendedProject::factory()->create([
            'title' => 'Hidden Admin Project',
        ]);

        $this->getJson('/api/homepage-recommendations')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.total', 0)
            ->assertJsonPath('meta.section.enabled', false)
            ->assertJsonPath('meta.personalization.audience', 'guest')
            ->assertJsonPath('meta.source_status.admin_upload.state', 'not_evaluated')
            ->assertJsonPath('meta.source_status.system_topic.state', 'not_evaluated');
    }

    public function test_public_endpoint_reports_phase_zero_fallback_policy_for_authenticated_requests(): void
    {
        HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => true,
            'data_source' => 'recommended_projects',
        ]);

        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->getJson('/api/homepage-recommendations')
            ->assertOk()
            ->assertJsonPath('meta.personalization.policy_version', 'phase_0_discovery_lock')
            ->assertJsonPath('meta.personalization.audience', 'authenticated')
            ->assertJsonPath('meta.personalization.mode', 'default_global_feed')
            ->assertJsonPath('meta.personalization.tracks_assignments', false)
            ->assertJsonPath(
                'meta.personalization.description',
                'Serve the current safe mixed homepage feed when subject profile or authored-topic signals are still insufficient.'
            );
    }

    public function test_public_endpoint_stays_safe_when_non_admin_source_normalization_fails(): void
    {
        HomepageSection::create([
            'key' => 'project_recommendations',
            'label' => 'Project Recommendations',
            'position' => 1,
            'is_enabled' => true,
            'data_source' => 'recommended_projects',
        ]);

        RecommendedProject::factory()->create([
            'title' => 'Only Admin Project',
            'source_type' => RecommendedProject::SOURCE_ADMIN_UPLOAD,
            'display_priority' => 100,
        ]);

        $this->app->instance(RecommendationAggregationService::class, new class extends RecommendationAggregationService
        {
            /**
             * @param  array<int, string>  $suppressedSourceKeys
             * @return Collection<int, array<string, mixed>>
             */
            protected function getNormalizedTopicItems(array $suppressedSourceKeys): Collection
            {
                throw new \RuntimeException('Topic normalization failed.');
            }
        });

        $this->getJson('/api/homepage-recommendations')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('meta.source_status.admin_upload.state', 'ok')
            ->assertJsonPath('meta.source_status.system_topic.state', 'failed')
            ->assertJsonPath('data.0.title', 'Only Admin Project');
    }
}