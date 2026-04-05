<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RecommendedProjectRecommendationCollection;
use App\Models\HomepageSection;
use App\Models\RecommendedProject;
use App\Services\RecommendationAggregationService;
use Illuminate\Http\Request;

class HomepageRecommendationController extends Controller
{
    public function __construct(
        protected RecommendationAggregationService $recommendationAggregationService,
    ) {
    }

    public function index(Request $request): RecommendedProjectRecommendationCollection
    {
        $validated = $request->validate([
            'limit' => 'nullable|integer|min:1|max:50',
        ]);

        $section = HomepageSection::query()
            ->where('key', 'project_recommendations')
            ->first();

        $requestedLimit = isset($validated['limit']) ? (int) $validated['limit'] : null;

        if ($section !== null && ! $section->is_enabled) {
            return (new RecommendedProjectRecommendationCollection(collect()))
                ->withContextMeta([
                    'section' => $this->buildSectionMeta($section),
                    'limit' => [
                        'requested' => $requestedLimit,
                        'applied' => 0,
                    ],
                    'source_status' => $this->notEvaluatedSourceStatus(),
                ]);
        }

        $snapshot = $this->recommendationAggregationService->buildFeedSnapshot();
        $items = $snapshot['items'];

        if ($requestedLimit !== null) {
            $items = $items->take($requestedLimit)->values();
        }

        return (new RecommendedProjectRecommendationCollection($items))
            ->withContextMeta([
                'section' => $this->buildSectionMeta($section),
                'limit' => [
                    'requested' => $requestedLimit,
                    'applied' => $items->count(),
                ],
                'source_status' => $snapshot['source_status'],
            ]);
    }

    protected function buildSectionMeta(?HomepageSection $section): array
    {
        return [
            'key' => 'project_recommendations',
            'label' => $section?->label,
            'enabled' => (bool) $section?->is_enabled,
            'position' => $section?->position,
        ];
    }

    /**
     * @return array<string, array<string, string>>
     */
    protected function notEvaluatedSourceStatus(): array
    {
        return [
            RecommendedProject::SOURCE_ADMIN_UPLOAD => ['state' => 'not_evaluated'],
            RecommendedProject::SOURCE_SYSTEM_TOPIC => ['state' => 'not_evaluated'],
            RecommendedProject::SOURCE_AI_GENERATED => ['state' => 'not_evaluated'],
        ];
    }
}