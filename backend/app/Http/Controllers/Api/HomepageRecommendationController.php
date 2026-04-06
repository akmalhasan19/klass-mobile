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
            ->where('key', $this->sectionKey())
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
                    'personalization' => $this->buildPersonalizationMeta($request),
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
                'personalization' => $this->buildPersonalizationMeta($request),
                'source_status' => $snapshot['source_status'],
            ]);
    }

    protected function buildSectionMeta(?HomepageSection $section): array
    {
        return [
            'key' => $this->sectionKey(),
            'label' => $section?->label,
            'enabled' => (bool) $section?->is_enabled,
            'position' => $section?->position,
            'endpoint' => $this->feedEndpoint(),
            'admin_configurator_path' => $this->adminConfiguratorPath(),
        ];
    }

    protected function buildPersonalizationMeta(Request $request): array
    {
        $user = auth('sanctum')->user() ?? $request->user();
        $policyKey = $user ? 'authenticated_without_personalization' : 'guest';
        $policy = (array) config("personalized_project_recommendations.fallbacks.{$policyKey}", []);

        return [
            'policy_version' => (string) config('personalized_project_recommendations.lock_version', 'phase_0_discovery_lock'),
            'audience' => $user ? 'authenticated' : 'guest',
            'mode' => (string) ($policy['mode'] ?? 'default_global_feed'),
            'tracks_assignments' => (bool) ($policy['tracks_assignments'] ?? false),
            'description' => (string) ($policy['description'] ?? ''),
        ];
    }

    protected function sectionKey(): string
    {
        return (string) config('personalized_project_recommendations.homepage.section_key', 'project_recommendations');
    }

    protected function feedEndpoint(): string
    {
        return (string) config('personalized_project_recommendations.homepage.feed_endpoint', '/api/homepage-recommendations');
    }

    protected function adminConfiguratorPath(): string
    {
        return (string) config('personalized_project_recommendations.homepage.admin_configurator_path', '/admin/homepage-sections');
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