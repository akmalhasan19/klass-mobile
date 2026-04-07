<?php

namespace App\Services;

use App\MediaGeneration\MediaGenerationLifecycle;
use App\Models\MediaGeneration;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

class MediaGenerationSubmissionService
{
    public function createOrReuse(
        int $teacherId,
        string $rawPrompt,
        ?string $preferredOutputType = null,
        ?int $subjectId = null,
        ?int $subSubjectId = null,
        array $providerMetadata = [],
    ): MediaGeneration {
        $normalizedPreferredOutputType = MediaGeneration::normalizePreferredOutputType($preferredOutputType);
        $requestFingerprint = MediaGeneration::makeRequestFingerprint(
            teacherId: $teacherId,
            rawPrompt: $rawPrompt,
            preferredOutputType: $normalizedPreferredOutputType,
            subjectId: $subjectId,
            subSubjectId: $subSubjectId,
        );

        return DB::transaction(function () use (
            $teacherId,
            $rawPrompt,
            $normalizedPreferredOutputType,
            $subjectId,
            $subSubjectId,
            $providerMetadata,
            $requestFingerprint,
        ): MediaGeneration {
            $existingGeneration = MediaGeneration::query()
                ->activeDuplicates($teacherId, $requestFingerprint)
                ->lockForUpdate()
                ->recentFirst()
                ->first();

            if ($existingGeneration) {
                return $existingGeneration;
            }

            try {
                return MediaGeneration::create([
                    'teacher_id' => $teacherId,
                    'subject_id' => $subjectId,
                    'sub_subject_id' => $subSubjectId,
                    'raw_prompt' => $rawPrompt,
                    'preferred_output_type' => $normalizedPreferredOutputType,
                    'status' => MediaGenerationLifecycle::QUEUED,
                    'llm_provider' => data_get($providerMetadata, 'llm_provider'),
                    'llm_model' => data_get($providerMetadata, 'llm_model'),
                    'generator_provider' => data_get($providerMetadata, 'generator_provider'),
                    'generator_model' => data_get($providerMetadata, 'generator_model'),
                ]);
            } catch (QueryException $exception) {
                $existingAfterConstraint = MediaGeneration::query()
                    ->activeDuplicates($teacherId, $requestFingerprint)
                    ->recentFirst()
                    ->first();

                if ($existingAfterConstraint) {
                    return $existingAfterConstraint;
                }

                throw $exception;
            }
        });
    }
}