<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegenerateMediaGenerationRequest;
use App\Http\Requests\StoreMediaGenerationRequest;
use App\Http\Resources\MediaGenerationResource;
use App\Http\Traits\ApiResponseTrait;
use App\Jobs\ProcessMediaGenerationJob;
use App\MediaGeneration\MediaGenerationApiException;
use App\Models\MediaGeneration;
use App\Models\User;
use App\Services\MediaGenerationSubmissionService;
use Illuminate\Contracts\Bus\Dispatcher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MediaGenerationController extends Controller
{
    use ApiResponseTrait;

    public function store(
        StoreMediaGenerationRequest $request,
        MediaGenerationSubmissionService $submissionService,
        Dispatcher $dispatcher,
    ): JsonResponse {
        $teacher = $this->requireTeacher($request);
        $attributes = $request->generationAttributes();

        $generation = $submissionService->createOrReuse(
            teacherId: $teacher->id,
            rawPrompt: $attributes['prompt'],
            preferredOutputType: $attributes['preferred_output_type'],
            subjectId: $attributes['subject_id'],
            subSubjectId: $attributes['sub_subject_id'],
        );

        if ($generation->wasRecentlyCreated) {
            $dispatcher->dispatch(new ProcessMediaGenerationJob($generation->id));
        }

        $generation->loadMissing(['subject', 'subSubject.subject', 'topic', 'content', 'recommendedProject']);

        return $this->accepted(
            new MediaGenerationResource($generation),
            $generation->wasRecentlyCreated
                ? 'Permintaan media generation diterima dan siap diproses.'
                : 'Permintaan identik yang masih aktif ditemukan. Gunakan generation yang sama untuk polling status.'
        );
    }

    public function show(Request $request, string $mediaGeneration): JsonResponse
    {
        $teacher = $this->requireTeacher($request);

        $generation = MediaGeneration::query()
            ->with(['subject', 'subSubject.subject', 'topic', 'content', 'recommendedProject'])
            ->whereKey($mediaGeneration)
            ->where('teacher_id', $teacher->id)
            ->first();

        if (! $generation) {
            throw MediaGenerationApiException::notFound();
        }

        return $this->success(
            new MediaGenerationResource($generation),
            'Status media generation berhasil diambil.'
        );
    }

    public function regenerate(
        RegenerateMediaGenerationRequest $request,
        MediaGenerationSubmissionService $submissionService,
        Dispatcher $dispatcher,
        string $mediaGeneration
    ): JsonResponse {
        $teacher = $this->requireTeacher($request);

        $parentGeneration = MediaGeneration::query()
            ->whereKey($mediaGeneration)
            ->where('teacher_id', $teacher->id)
            ->first();

        if (! $parentGeneration) {
            throw MediaGenerationApiException::notFound();
        }

        if (! $parentGeneration->isTerminal()) {
            return $this->error(
                'Media generation belum selesai dan tidak dapat diregenerasi saat ini.',
                422
            );
        }

        $additionalPrompt = $request->validated('additional_prompt');

        $newGeneration = $submissionService->createRegeneration($parentGeneration, $additionalPrompt);

        $dispatcher->dispatch(new ProcessMediaGenerationJob($newGeneration->id));

        $newGeneration->loadMissing(['subject', 'subSubject.subject', 'topic', 'content', 'recommendedProject']);

        return $this->accepted(
            new MediaGenerationResource($newGeneration),
            'Permintaan regenerasi media diterima dan sedang diproses.'
        );
    }

    protected function requireTeacher(Request $request): User
    {
        /** @var User|null $user */
        $user = $request->user();

        if (! $user || ! $user->isTeacher()) {
            throw MediaGenerationApiException::teacherRoleRequired();
        }

        return $user;
    }
}