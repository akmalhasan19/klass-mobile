<?php

namespace Tests\Feature;

use App\Jobs\ProcessMediaGenerationJob;
use App\MediaGeneration\MediaGenerationErrorCode;
use App\MediaGeneration\MediaGenerationLifecycle;
use App\Models\MediaGeneration;
use App\Models\SubSubject;
use App\Models\Subject;
use App\Models\User;
use Database\Seeders\SubjectTaxonomySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MediaGenerationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_teacher_can_submit_media_generation_and_poll_its_status(): void
    {
        $this->seed(SubjectTaxonomySeeder::class);

        $teacher = User::factory()->teacher()->create();
        $subSubject = SubSubject::query()->where('slug', 'algebra')->firstOrFail();

        Sanctum::actingAs($teacher);

        $response = $this->postJson('/api/media-generations', [
            'prompt' => 'Buatkan handout aljabar dasar untuk kelas 8.',
            'preferred_output_type' => 'pdf',
            'sub_subject_id' => $subSubject->id,
        ]);

        $response
            ->assertStatus(202)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', MediaGenerationLifecycle::QUEUED)
            ->assertJsonPath('data.preferred_output_type', 'pdf')
            ->assertJsonPath('data.resolved_output_type', null)
            ->assertJsonPath('data.subject_id', $subSubject->subject_id)
            ->assertJsonPath('data.sub_subject_id', $subSubject->id)
            ->assertJsonPath('data.status_meta.lifecycle_version', MediaGenerationLifecycle::VERSION)
            ->assertJsonPath('data.status_meta.is_terminal', false)
            ->assertJsonPath('data.error', null);

        $generationId = $response->json('data.id');

        $this->assertDatabaseHas('jobs', ['queue' => 'media-generation']);
        $queuedJob = DB::table('jobs')->where('queue', 'media-generation')->latest('id')->first();

        $this->assertNotNull($queuedJob);
        $queuedJobPayload = json_decode((string) $queuedJob->payload, true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(ProcessMediaGenerationJob::class, data_get($queuedJobPayload, 'displayName'));
        $this->assertSame(ProcessMediaGenerationJob::class, data_get($queuedJobPayload, 'data.commandName'));
        $this->assertStringContainsString($generationId, (string) data_get($queuedJobPayload, 'data.command'));

        $response->assertJsonPath('data.links.poll', url('/api/media-generations/' . $generationId));

        $this->assertDatabaseHas('media_generations', [
            'id' => $generationId,
            'teacher_id' => $teacher->id,
            'subject_id' => $subSubject->subject_id,
            'sub_subject_id' => $subSubject->id,
            'preferred_output_type' => 'pdf',
            'status' => MediaGenerationLifecycle::QUEUED,
        ]);

        $pollResponse = $this->getJson('/api/media-generations/' . $generationId);

        $pollResponse
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.id', $generationId)
            ->assertJsonPath('data.prompt', 'Buatkan handout aljabar dasar untuk kelas 8.')
            ->assertJsonPath('data.status', MediaGenerationLifecycle::QUEUED);

        $duplicateResponse = $this->postJson('/api/media-generations', [
            'prompt' => '  Buatkan handout aljabar dasar untuk kelas 8.  ',
            'preferred_output_type' => 'pdf',
            'sub_subject_id' => $subSubject->id,
        ]);

        $duplicateResponse
            ->assertStatus(202)
            ->assertJsonPath('data.id', $generationId);

        $this->assertDatabaseCount('media_generations', 1);
        $this->assertDatabaseCount('jobs', 1);
    }

    public function test_media_generation_api_requires_teacher_role_and_owned_generation(): void
    {
        $this->seed(SubjectTaxonomySeeder::class);

        $teacher = User::factory()->teacher()->create();
        $otherTeacher = User::factory()->teacher()->create();
        $admin = User::factory()->admin()->create();
        $subSubject = SubSubject::query()->where('slug', 'thermodynamics')->firstOrFail();

        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'subject_id' => $subSubject->subject_id,
            'sub_subject_id' => $subSubject->id,
            'raw_prompt' => 'Buatkan deck termodinamika.',
            'preferred_output_type' => 'pptx',
            'status' => MediaGenerationLifecycle::QUEUED,
        ]);

        $this->postJson('/api/media-generations', [
            'prompt' => 'Buatkan handout tanpa login.',
        ])->assertUnauthorized();

        Sanctum::actingAs($admin);

        $this->postJson('/api/media-generations', [
            'prompt' => 'Admin mencoba submit.',
        ])
            ->assertForbidden()
            ->assertJsonPath('error.code', MediaGenerationErrorCode::TEACHER_ROLE_REQUIRED);

        Sanctum::actingAs($otherTeacher);

        $this->getJson('/api/media-generations/' . $generation->id)
            ->assertNotFound()
            ->assertJsonPath('error.code', MediaGenerationErrorCode::MEDIA_GENERATION_NOT_FOUND);
    }

    public function test_media_generation_create_validation_returns_stable_error_contract(): void
    {
        $this->seed(SubjectTaxonomySeeder::class);

        $teacher = User::factory()->teacher()->create();
        $subject = Subject::query()->where('slug', 'science')->firstOrFail();
        $subSubject = SubSubject::query()->where('slug', 'algebra')->firstOrFail();

        Sanctum::actingAs($teacher);

        $response = $this->postJson('/api/media-generations', [
            'prompt' => '',
            'preferred_output_type' => 'xlsx',
            'subject_id' => $subject->id,
            'sub_subject_id' => $subSubject->id,
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Validasi gagal.')
            ->assertJsonPath('error.code', MediaGenerationErrorCode::VALIDATION_FAILED)
            ->assertJsonPath('error.retryable', false)
            ->assertJsonValidationErrors(['prompt', 'preferred_output_type', 'sub_subject_id']);
    }

    public function test_failed_media_generation_status_exposes_safe_error_payload_without_raw_stack_trace(): void
    {
        $this->seed(SubjectTaxonomySeeder::class);

        $teacher = User::factory()->teacher()->create();
        $subSubject = SubSubject::query()->where('slug', 'quantum-physics')->firstOrFail();

        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'subject_id' => $subSubject->subject_id,
            'sub_subject_id' => $subSubject->id,
            'raw_prompt' => 'Buatkan modul fisika kuantum.',
            'preferred_output_type' => 'pdf',
            'resolved_output_type' => 'pdf',
            'status' => MediaGenerationLifecycle::FAILED,
            'error_code' => MediaGenerationErrorCode::PUBLICATION_FAILED,
            'error_message' => 'SQLSTATE[23000]: duplicate key value violates unique constraint',
        ]);

        Sanctum::actingAs($teacher);

        $response = $this->getJson('/api/media-generations/' . $generation->id);

        $response
            ->assertOk()
            ->assertJsonPath('data.status', MediaGenerationLifecycle::FAILED)
            ->assertJsonPath('data.status_meta.is_terminal', true)
            ->assertJsonPath('data.error.code', MediaGenerationErrorCode::PUBLICATION_FAILED)
            ->assertJsonPath('data.error.message', MediaGenerationErrorCode::clientMessage(MediaGenerationErrorCode::PUBLICATION_FAILED))
            ->assertJsonPath('data.error.retryable', true);

        $this->assertStringNotContainsString('SQLSTATE', $response->getContent());
    }

    public function test_media_generation_error_code_registry_locks_stable_phase_three_contract(): void
    {
        $this->assertContains(MediaGenerationErrorCode::VALIDATION_FAILED, MediaGenerationErrorCode::all());
        $this->assertContains(MediaGenerationErrorCode::LLM_CONTRACT_FAILED, MediaGenerationErrorCode::all());
        $this->assertContains(MediaGenerationErrorCode::PYTHON_SERVICE_UNAVAILABLE, MediaGenerationErrorCode::all());
        $this->assertContains(MediaGenerationErrorCode::ARTIFACT_INVALID, MediaGenerationErrorCode::all());
        $this->assertContains(MediaGenerationErrorCode::UPLOAD_FAILED, MediaGenerationErrorCode::all());
        $this->assertContains(MediaGenerationErrorCode::PUBLICATION_FAILED, MediaGenerationErrorCode::all());
        $this->assertSame(422, MediaGenerationErrorCode::httpStatus(MediaGenerationErrorCode::VALIDATION_FAILED));
        $this->assertSame(503, MediaGenerationErrorCode::httpStatus(MediaGenerationErrorCode::PYTHON_SERVICE_UNAVAILABLE));
        $this->assertTrue(MediaGenerationErrorCode::retryable(MediaGenerationErrorCode::UPLOAD_FAILED));
        $this->assertFalse(MediaGenerationErrorCode::retryable(MediaGenerationErrorCode::VALIDATION_FAILED));
    }
}