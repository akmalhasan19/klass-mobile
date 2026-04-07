<?php

namespace App\Services;

use App\Models\Content;
use App\Models\MediaGeneration;
use App\Models\RecommendedProject;
use App\Models\Topic;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class MediaPublicationService
{
    public function publish(MediaGeneration $generation): MediaGeneration
    {
        return DB::transaction(function () use ($generation): MediaGeneration {
            /** @var MediaGeneration $lockedGeneration */
            $lockedGeneration = MediaGeneration::query()
                ->with(['teacher', 'subject', 'subSubject.subject'])
                ->lockForUpdate()
                ->findOrFail($generation->getKey());

            $existingProject = $this->resolveExistingRecommendedProject($lockedGeneration);
            $existingTopic = $this->resolveExistingTopic($lockedGeneration, $existingProject);
            $existingContent = $this->resolveExistingContent($lockedGeneration, $existingProject, $existingTopic);

            $topic = $existingTopic ?? $this->createTopic($lockedGeneration);
            $content = $existingContent ?? $this->createContent($lockedGeneration, $topic);
            $project = $existingProject ?? $this->createRecommendedProject($lockedGeneration, $topic, $content);

            $deliveryPayload = $this->buildDeliveryPayload($lockedGeneration, $topic, $content, $project);

            $lockedGeneration->forceFill([
                'topic_id' => $topic->id,
                'content_id' => $content->id,
                'recommended_project_id' => $project->id,
                'delivery_payload' => $deliveryPayload,
            ])->save();

            return $lockedGeneration->fresh(['topic', 'content', 'recommendedProject', 'subject', 'subSubject.subject']);
        });
    }

    protected function resolveExistingTopic(MediaGeneration $generation, ?RecommendedProject $project): ?Topic
    {
        if ($generation->topic_id) {
            $topic = Topic::query()->find($generation->topic_id);

            if ($topic) {
                return $topic;
            }
        }

        $topicId = data_get($project?->source_payload, 'topic_id')
            ?? data_get($generation->delivery_payload, 'publication.topic.id');

        return $topicId ? Topic::query()->find($topicId) : null;
    }

    protected function resolveExistingContent(
        MediaGeneration $generation,
        ?RecommendedProject $project,
        ?Topic $topic,
    ): ?Content {
        if ($generation->content_id) {
            $content = Content::query()->find($generation->content_id);

            if ($content) {
                return $content;
            }
        }

        $contentId = data_get($project?->source_payload, 'content_id')
            ?? data_get($generation->delivery_payload, 'publication.content.id');

        if ($contentId) {
            $content = Content::query()->find($contentId);

            if ($content) {
                return $content;
            }
        }

        if (! $topic) {
            return null;
        }

        return Content::query()
            ->where('topic_id', $topic->id)
            ->get()
            ->first(fn (Content $content): bool => data_get($content->data, 'media_generation_id') === $generation->id);
    }

    protected function resolveExistingRecommendedProject(MediaGeneration $generation): ?RecommendedProject
    {
        if ($generation->recommended_project_id) {
            $project = RecommendedProject::query()->find($generation->recommended_project_id);

            if ($project) {
                return $project;
            }
        }

        return RecommendedProject::query()
            ->where('source_type', RecommendedProject::SOURCE_AI_GENERATED)
            ->get()
            ->first(fn (RecommendedProject $project): bool => data_get($project->source_payload, 'media_generation_id') === $generation->id);
    }

    protected function createTopic(MediaGeneration $generation): Topic
    {
        return Topic::create([
            'title' => $this->resolvePublicationTitle($generation),
            'teacher_id' => (string) $generation->teacher_id,
            'sub_subject_id' => $generation->sub_subject_id,
            'thumbnail_url' => $generation->thumbnail_url,
            'is_published' => true,
            'order' => 0,
        ]);
    }

    protected function createContent(MediaGeneration $generation, Topic $topic): Content
    {
        return Content::create([
            'topic_id' => $topic->id,
            'type' => 'brief',
            'title' => $this->resolvePublicationTitle($generation),
            'data' => $this->buildContentData($generation, $topic),
            'media_url' => $generation->file_url,
            'is_published' => true,
            'order' => 0,
        ]);
    }

    protected function createRecommendedProject(MediaGeneration $generation, Topic $topic, Content $content): RecommendedProject
    {
        $project = RecommendedProject::create([
            'title' => $this->resolvePublicationTitle($generation),
            'description' => $this->resolvePublicationDescription($generation),
            'thumbnail_url' => $generation->thumbnail_url,
            'project_file_url' => $generation->file_url,
            'ratio' => '16:9',
            'project_type' => 'learning_material',
            'tags' => $this->buildProjectTags($generation),
            'modules' => $this->buildProjectModules($generation),
            'source_type' => RecommendedProject::SOURCE_AI_GENERATED,
            'source_reference' => null,
            'source_payload' => [],
            'display_priority' => 0,
            'is_active' => true,
            'starts_at' => null,
            'ends_at' => null,
            'created_by' => $generation->teacher_id,
            'updated_by' => $generation->teacher_id,
        ]);

        $project->forceFill([
            'source_reference' => (string) $project->id,
            'source_payload' => $this->buildProjectSourcePayload($generation, $topic, $content, $project),
        ])->save();

        return $project->fresh();
    }

    protected function buildContentData(MediaGeneration $generation, Topic $topic): array
    {
        return [
            'media_generation_id' => $generation->id,
            'teacher_id' => (string) $generation->teacher_id,
            'topic_id' => $topic->id,
            'subject_id' => $this->resolveSubjectId($generation),
            'sub_subject_id' => $generation->sub_subject_id,
            'output_type' => $this->resolveOutputType($generation),
            'mime_type' => $generation->mime_type,
            'storage_path' => $generation->storage_path,
            'file_url' => $generation->file_url,
            'thumbnail_url' => $generation->thumbnail_url,
            'summary' => $this->resolvePublicationDescription($generation),
            'teacher_delivery_summary' => data_get($generation->interpretation_payload, 'teacher_delivery_summary'),
            'section_titles' => $this->buildProjectModules($generation),
        ];
    }

    protected function buildProjectSourcePayload(
        MediaGeneration $generation,
        Topic $topic,
        Content $content,
        RecommendedProject $project,
    ): array {
        $taxonomy = $this->buildTaxonomy($generation);

        return [
            'media_generation_id' => $generation->id,
            'source_reference' => (string) $project->id,
            'topic_id' => $topic->id,
            'content_id' => $content->id,
            'teacher_id' => (string) $generation->teacher_id,
            'owner_user_id' => $topic->owner_user_id,
            'subject_id' => $this->resolveSubjectId($generation),
            'sub_subject_id' => $generation->sub_subject_id,
            'taxonomy' => $taxonomy,
            'personalization' => $topic->resolvePersonalizationContext(),
            'output_type' => $this->resolveOutputType($generation),
            'mime_type' => $generation->mime_type,
            'file_url' => $generation->file_url,
            'thumbnail_url' => $generation->thumbnail_url,
            'score' => $this->resolveRecommendationScore($generation),
        ];
    }

    protected function buildDeliveryPayload(
        MediaGeneration $generation,
        Topic $topic,
        Content $content,
        RecommendedProject $project,
    ): array {
        return [
            'media_generation_id' => $generation->id,
            'artifact' => [
                'output_type' => $this->resolveOutputType($generation),
                'storage_path' => $generation->storage_path,
                'file_url' => $generation->file_url,
                'thumbnail_url' => $generation->thumbnail_url,
                'mime_type' => $generation->mime_type,
            ],
            'publication' => [
                'topic' => [
                    'id' => $topic->id,
                    'title' => $topic->title,
                ],
                'content' => [
                    'id' => $content->id,
                    'type' => $content->type,
                    'title' => $content->title,
                    'media_url' => $content->media_url,
                ],
                'recommended_project' => [
                    'id' => (string) $project->id,
                    'source_type' => $project->source_type,
                    'source_reference' => $project->source_reference,
                    'project_file_url' => $project->project_file_url,
                ],
            ],
            'summary' => $this->resolvePublicationDescription($generation),
        ];
    }

    protected function buildProjectModules(MediaGeneration $generation): array
    {
        $sections = data_get($generation->generation_spec_payload, 'sections', []);

        if (is_array($sections) && $sections !== []) {
            $titles = collect($sections)
                ->map(fn (mixed $section): ?string => is_array($section) ? trim((string) data_get($section, 'title')) : null)
                ->filter()
                ->values()
                ->all();

            if ($titles !== []) {
                return $titles;
            }
        }

        $blueprintSections = data_get($generation->interpretation_payload, 'document_blueprint.sections', []);

        return collect(is_array($blueprintSections) ? $blueprintSections : [])
            ->map(fn (mixed $section): ?string => is_array($section) ? trim((string) data_get($section, 'title')) : null)
            ->filter()
            ->values()
            ->all();
    }

    protected function buildProjectTags(MediaGeneration $generation): array
    {
        $tags = [
            data_get($generation->subject, 'name'),
            data_get($generation->subSubject, 'name'),
            strtoupper($this->resolveOutputType($generation)),
        ];

        return collect($tags)
            ->filter(fn (mixed $tag): bool => is_string($tag) && trim($tag) !== '')
            ->map(fn (string $tag): string => trim($tag))
            ->unique()
            ->values()
            ->all();
    }

    protected function buildTaxonomy(MediaGeneration $generation): ?array
    {
        $subject = $generation->subSubject?->subject ?? $generation->subject;
        $subSubject = $generation->subSubject;

        if (! $subSubject) {
            return null;
        }

        return [
            'subject' => $subject ? [
                'id' => $subject->id,
                'name' => $subject->name,
                'slug' => $subject->slug,
            ] : null,
            'sub_subject' => [
                'id' => $subSubject->id,
                'subject_id' => $subSubject->subject_id,
                'name' => $subSubject->name,
                'slug' => $subSubject->slug,
            ],
        ];
    }

    protected function resolveSubjectId(MediaGeneration $generation): ?int
    {
        return $generation->subSubject?->subject_id ?? $generation->subject_id;
    }

    protected function resolveOutputType(MediaGeneration $generation): string
    {
        if (is_string($generation->resolved_output_type) && trim($generation->resolved_output_type) !== '') {
            return trim($generation->resolved_output_type);
        }

        $exportFormat = data_get($generation->generation_spec_payload, 'export_format');

        if (is_string($exportFormat) && trim($exportFormat) !== '') {
            return trim($exportFormat);
        }

        return MediaGeneration::normalizePreferredOutputType($generation->preferred_output_type);
    }

    protected function resolvePublicationTitle(MediaGeneration $generation): string
    {
        $candidates = [
            data_get($generation->generation_spec_payload, 'title'),
            data_get($generation->interpretation_payload, 'document_blueprint.title'),
            data_get($generation->delivery_payload, 'summary.title'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return Str::limit(Str::of($generation->raw_prompt)->squish()->toString(), 120, '');
    }

    protected function resolvePublicationDescription(MediaGeneration $generation): ?string
    {
        $candidates = [
            data_get($generation->interpretation_payload, 'teacher_delivery_summary'),
            data_get($generation->generation_spec_payload, 'summary'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return null;
    }

    protected function resolveRecommendationScore(MediaGeneration $generation): float
    {
        $confidenceScore = data_get($generation->interpretation_payload, 'confidence.score');

        if (is_numeric($confidenceScore)) {
            return round((float) $confidenceScore, 4);
        }

        $candidateScore = data_get($generation->interpretation_payload, 'output_type_candidates.0.score');

        return is_numeric($candidateScore) ? round((float) $candidateScore, 4) : 0.0;
    }
}