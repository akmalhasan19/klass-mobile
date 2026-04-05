<?php

namespace Tests\Feature;

use App\Http\Resources\RecommendedProjectRecommendationCollection;
use App\Models\Content;
use App\Models\RecommendedProject;
use App\Models\Topic;
use App\Services\RecommendationAggregationService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class RecommendationAggregationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_service_merges_curated_and_topic_sources_into_mobile_payload(): void
    {
        $service = new RecommendationAggregationService();

        $baseTime = CarbonImmutable::parse('2026-04-03 10:00:00');

        $adminProject = RecommendedProject::factory()->create([
            'title' => 'Admin Showcase',
            'display_priority' => 100,
            'source_type' => RecommendedProject::SOURCE_ADMIN_UPLOAD,
            'source_payload' => ['score' => 1.5],
        ]);

        $curatedSystemTopic = RecommendedProject::factory()->create([
            'title' => 'Curated React Topic',
            'description' => 'Override dari source topic lama.',
            'thumbnail_url' => 'https://example.com/react-override.jpg',
            'project_type' => 'web',
            'tags' => ['React'],
            'modules' => ['Hooks', 'State'],
            'source_type' => RecommendedProject::SOURCE_SYSTEM_TOPIC,
            'source_reference' => 'topic-react',
            'source_payload' => ['score' => 4.2],
            'display_priority' => 20,
        ]);

        $topicFromSystem = Topic::unguarded(fn () => Topic::create([
            'id' => 'topic-flutter',
            'title' => 'Belajar Flutter Dasar',
            'teacher_id' => 'teacher-1',
            'thumbnail_url' => 'https://example.com/flutter.jpg',
            'is_published' => true,
            'order' => 1,
        ]));
        DB::table('topics')->where('id', $topicFromSystem->id)->update([
            'created_at' => $baseTime->subDay(),
            'updated_at' => $baseTime->subDay(),
        ]);
        $topicFromSystem->refresh();

        Content::create([
            'topic_id' => $topicFromSystem->id,
            'type' => 'module',
            'title' => 'Routing',
            'data' => ['kind' => 'module'],
            'media_url' => null,
            'is_published' => true,
            'order' => 1,
        ]);

        Content::create([
            'topic_id' => $topicFromSystem->id,
            'type' => 'module',
            'title' => 'State Management',
            'data' => ['kind' => 'module'],
            'media_url' => null,
            'is_published' => true,
            'order' => 2,
        ]);

        $suppressedTopic = Topic::unguarded(fn () => Topic::create([
            'id' => 'topic-react',
            'title' => 'React Lama',
            'teacher_id' => 'teacher-2',
            'thumbnail_url' => 'https://example.com/react.jpg',
            'is_published' => true,
            'order' => 2,
        ]));
        DB::table('topics')->where('id', $suppressedTopic->id)->update([
            'created_at' => $baseTime->subHours(6),
            'updated_at' => $baseTime->subHours(6),
        ]);
        $suppressedTopic->refresh();

        $feed = $service->buildFeed($baseTime);
        $payload = (new RecommendedProjectRecommendationCollection($feed))->response()->getData(true);

        $this->assertCount(3, $feed);
        $this->assertSame((string) $adminProject->id, $feed[0]['id']);
        $this->assertSame((string) $curatedSystemTopic->id, $feed[1]['id']);
        $this->assertSame('system_topic_topic-flutter', $feed[2]['id']);
        $this->assertSame(['Routing', 'State Management'], $feed[2]['modules']);
        $this->assertSame([], $feed[2]['tags']);

        $this->assertSame(3, $payload['meta']['total']);
        $this->assertSame(1, $payload['meta']['source_breakdown'][RecommendedProject::SOURCE_ADMIN_UPLOAD]);
        $this->assertSame(2, $payload['meta']['source_breakdown'][RecommendedProject::SOURCE_SYSTEM_TOPIC]);
        $this->assertArrayNotHasKey('source_payload', $payload['data'][0]);
        $this->assertArrayNotHasKey('source_reference', $payload['data'][0]);
        $this->assertSame('Belajar Flutter Dasar', $payload['data'][2]['title']);
        $this->assertSame(['Routing', 'State Management'], $payload['data'][2]['modules']);
    }

    public function test_service_sorts_by_priority_then_score_then_created_at(): void
    {
        $service = new RecommendationAggregationService();

        $first = RecommendedProject::factory()->create([
            'title' => 'Lower Score',
            'display_priority' => 50,
            'source_type' => RecommendedProject::SOURCE_AI_GENERATED,
            'source_payload' => ['score' => 2.1],
        ]);

        $second = RecommendedProject::factory()->create([
            'title' => 'Higher Score',
            'display_priority' => 50,
            'source_type' => RecommendedProject::SOURCE_AI_GENERATED,
            'source_payload' => ['score' => 9.4],
        ]);

        $third = RecommendedProject::factory()->create([
            'title' => 'Same Score Newer',
            'display_priority' => 50,
            'source_type' => RecommendedProject::SOURCE_AI_GENERATED,
            'source_payload' => ['score' => 9.4],
        ]);

        DB::table('recommended_projects')->where('id', $first->id)->update([
            'created_at' => CarbonImmutable::parse('2026-04-03 08:00:00'),
            'updated_at' => CarbonImmutable::parse('2026-04-03 08:00:00'),
        ]);
        DB::table('recommended_projects')->where('id', $second->id)->update([
            'created_at' => CarbonImmutable::parse('2026-04-03 09:00:00'),
            'updated_at' => CarbonImmutable::parse('2026-04-03 09:00:00'),
        ]);
        DB::table('recommended_projects')->where('id', $third->id)->update([
            'created_at' => CarbonImmutable::parse('2026-04-03 10:00:00'),
            'updated_at' => CarbonImmutable::parse('2026-04-03 10:00:00'),
        ]);

        $feed = $service->buildFeed(CarbonImmutable::parse('2026-04-03 12:00:00'));

        $this->assertSame('Same Score Newer', $feed[0]['title']);
        $this->assertSame('Higher Score', $feed[1]['title']);
        $this->assertSame('Lower Score', $feed[2]['title']);
    }

    public function test_service_filters_visibility_and_handles_empty_sources_safely(): void
    {
        $service = new RecommendationAggregationService();
        $moment = CarbonImmutable::parse('2026-04-03 12:00:00');

        RecommendedProject::factory()->inactive()->create([
            'title' => 'Inactive Item',
        ]);

        RecommendedProject::factory()->scheduled()->create([
            'title' => 'Scheduled Item',
            'starts_at' => $moment->addDay(),
        ]);

        RecommendedProject::factory()->expired()->create([
            'title' => 'Expired Item',
            'ends_at' => $moment->subDay(),
        ]);

        $feed = $service->buildFeed($moment);

        $this->assertCount(0, $feed);

        Topic::unguarded(fn () => Topic::create([
            'id' => 'topic-hidden',
            'title' => 'Topic Hidden by Override',
            'teacher_id' => 'teacher-9',
            'thumbnail_url' => null,
            'is_published' => true,
            'order' => 1,
        ]));

        RecommendedProject::factory()->inactive()->create([
            'title' => 'Inactive Topic Override',
            'source_type' => RecommendedProject::SOURCE_SYSTEM_TOPIC,
            'source_reference' => 'topic-hidden',
        ]);

        $feedAfterOverride = $service->buildFeed($moment);

        $this->assertCount(0, $feedAfterOverride);
    }
}