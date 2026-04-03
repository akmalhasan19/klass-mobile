<?php

namespace App\Services;

use App\Models\RecommendedProject;
use App\Models\Topic;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;

class RecommendationAggregationService
{
    /**
     * @return Collection<int, array<string, mixed>>
     */
    public function buildFeed(?CarbonInterface $moment = null): Collection
    {
        $moment = $moment ? CarbonImmutable::instance($moment) : CarbonImmutable::now();

        $curatedItems = $this->getVisibleCuratedItems($moment);
        $suppressedSourceKeys = $this->getSuppressedNonAdminSourceKeys();
        $topicItems = $this->getNormalizedTopicItems($suppressedSourceKeys);

        return $curatedItems
            ->concat($topicItems)
            ->sort(fn (array $left, array $right) => $this->compareItems($left, $right))
            ->values();
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    protected function getVisibleCuratedItems(CarbonInterface $moment): Collection
    {
        return RecommendedProject::query()
            ->visibleAt($moment)
            ->get()
            ->map(fn (RecommendedProject $project) => $this->normalizeRecommendedProject($project));
    }

    /**
     * @return array<int, string>
     */
    protected function getSuppressedNonAdminSourceKeys(): array
    {
        return RecommendedProject::query()
            ->whereNotNull('source_reference')
            ->where('source_type', '!=', RecommendedProject::SOURCE_ADMIN_UPLOAD)
            ->get(['source_type', 'source_reference'])
            ->map(fn (RecommendedProject $project) => $this->makeSourceKey($project->source_type, $project->source_reference))
            ->filter()
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @param  array<int, string>  $suppressedSourceKeys
     * @return Collection<int, array<string, mixed>>
     */
    protected function getNormalizedTopicItems(array $suppressedSourceKeys): Collection
    {
        $suppressedLookup = array_fill_keys($suppressedSourceKeys, true);

        return Topic::query()
            ->select([
                'id',
                'title',
                'teacher_id',
                'thumbnail_url',
                'is_published',
                'order',
                'created_at',
                'updated_at',
            ])
            ->where('is_published', true)
            ->with([
                'contents' => fn ($query) => $query
                    ->select([
                        'id',
                        'topic_id',
                        'type',
                        'title',
                        'is_published',
                        'order',
                        'created_at',
                    ])
                    ->where('is_published', true)
                    ->orderBy('order')
                    ->orderByDesc('created_at'),
            ])
            ->get()
            ->reject(function (Topic $topic) use ($suppressedLookup) {
                $sourceKey = $this->makeSourceKey(RecommendedProject::SOURCE_SYSTEM_TOPIC, $topic->id);

                return isset($suppressedLookup[$sourceKey]);
            })
            ->map(fn (Topic $topic) => $this->normalizeTopic($topic));
    }

    /**
     * @return array<string, mixed>
     */
    protected function normalizeRecommendedProject(RecommendedProject $project): array
    {
        $sourcePayload = is_array($project->source_payload) ? $project->source_payload : [];

        return [
            'id' => (string) $project->id,
            'title' => $project->title,
            'description' => $project->description,
            'thumbnail_url' => $project->thumbnail_url,
            'ratio' => $project->ratio ?: '16:9',
            'project_type' => $project->project_type,
            'tags' => $project->tags ?? [],
            'modules' => $project->modules ?? [],
            'source_type' => $project->source_type,
            'source_reference' => $project->source_reference,
            'source_payload' => $sourcePayload,
            'display_priority' => (int) $project->display_priority,
            'score' => $this->extractScore($sourcePayload),
            'visibility' => [
                'is_active' => (bool) $project->is_active,
                'starts_at' => $project->starts_at,
                'ends_at' => $project->ends_at,
            ],
            'created_at' => $project->created_at,
            'updated_at' => $project->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function normalizeTopic(Topic $topic): array
    {
        $modules = $topic->contents
            ->map(function ($content) {
                return $content->title ?: $content->type;
            })
            ->filter()
            ->values()
            ->all();

        return [
            'id' => 'system_topic_' . $topic->id,
            'title' => $topic->title,
            'description' => null,
            'thumbnail_url' => $topic->thumbnail_url,
            'ratio' => '16:9',
            'project_type' => null,
            'tags' => [],
            'modules' => $modules,
            'source_type' => RecommendedProject::SOURCE_SYSTEM_TOPIC,
            'source_reference' => $topic->id,
            'source_payload' => [
                'topic_id' => $topic->id,
                'teacher_id' => $topic->teacher_id,
                'topic_order' => $topic->order,
                'contents_count' => count($modules),
            ],
            'display_priority' => 0,
            'score' => 0.0,
            'visibility' => [
                'is_active' => true,
                'starts_at' => null,
                'ends_at' => null,
            ],
            'created_at' => $topic->created_at,
            'updated_at' => $topic->updated_at,
        ];
    }

    protected function compareItems(array $left, array $right): int
    {
        return ((int) data_get($right, 'display_priority', 0) <=> (int) data_get($left, 'display_priority', 0))
            ?: ((float) data_get($right, 'score', 0) <=> (float) data_get($left, 'score', 0))
            ?: ($this->timestampValue(data_get($right, 'created_at')) <=> $this->timestampValue(data_get($left, 'created_at')))
            ?: strcmp((string) data_get($left, 'id'), (string) data_get($right, 'id'));
    }

    protected function makeSourceKey(?string $sourceType, mixed $sourceReference): ?string
    {
        if (! $sourceType || $sourceReference === null || $sourceReference === '') {
            return null;
        }

        return $sourceType . ':' . $sourceReference;
    }

    /**
     * @param  array<string, mixed>  $sourcePayload
     */
    protected function extractScore(array $sourcePayload): float
    {
        $score = $sourcePayload['score'] ?? 0;

        return is_numeric($score) ? (float) $score : 0.0;
    }

    protected function timestampValue(mixed $value): int
    {
        if ($value instanceof CarbonInterface) {
            return $value->getTimestamp();
        }

        if (is_string($value) && $value !== '') {
            return CarbonImmutable::parse($value)->getTimestamp();
        }

        return 0;
    }
}