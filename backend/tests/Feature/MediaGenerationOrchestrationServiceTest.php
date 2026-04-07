<?php

namespace Tests\Feature;

use App\MediaGeneration\MediaArtifactMetadataContract;
use App\MediaGeneration\MediaGenerationErrorCode;
use App\MediaGeneration\MediaGenerationLifecycle;
use App\MediaGeneration\MediaGenerationServiceException;
use App\MediaGeneration\MediaGenerationSpecContract;
use App\MediaGeneration\MediaPromptInterpretationSchema;
use App\Models\MediaGeneration;
use App\Models\User;
use App\Services\MediaGenerationDecisionService;
use App\Services\MediaPromptInterpretationService;
use App\Services\PythonMediaGeneratorClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class MediaGenerationOrchestrationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_prompt_interpretation_service_calls_llm_and_persists_normalized_and_audit_payloads(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan handout pecahan untuk kelas 5 dengan contoh dan latihan singkat.',
            'preferred_output_type' => 'auto',
            'status' => MediaGenerationLifecycle::INTERPRETING,
        ]);

        config([
            'services.media_generation.interpreter.base_url' => 'https://llm.example',
            'services.media_generation.interpreter.api_key' => 'test-api-key',
            'services.media_generation.interpreter.model' => 'gpt-5.4',
            'services.media_generation.interpreter.provider' => 'llm-gateway',
        ]);

        Http::fake([
            'https://llm.example/*' => Http::response([
                'choices' => [
                    [
                        'message' => [
                            'content' => json_encode($this->validInterpretationPayload(), JSON_THROW_ON_ERROR),
                        ],
                    ],
                ],
            ], 200),
        ]);

        $result = (new MediaPromptInterpretationService())->interpret($generation);

        $this->assertSame('llm-gateway', $result->llm_provider);
        $this->assertSame('gpt-5.4', $result->llm_model);
        $this->assertSame(MediaPromptInterpretationSchema::VERSION, data_get($result->interpretation_payload, 'schema_version'));
        $this->assertFalse((bool) data_get($result->interpretation_audit_payload, 'response.used_fallback'));
        $this->assertSame(
            'Buatkan handout pecahan untuk kelas 5 dengan contoh dan latihan singkat.',
            data_get($result->interpretation_audit_payload, 'request.input.teacher_prompt')
        );
        $this->assertSame(
            MediaPromptInterpretationSchema::VERSION,
            data_get($result->interpretation_audit_payload, 'response.normalized_payload.schema_version')
        );

        Http::assertSent(function (Request $request): bool {
            $payload = json_decode($request->body(), true, 512, JSON_THROW_ON_ERROR);

            return $request->url() === 'https://llm.example/v1/interpret'
                && ($request->header('Authorization')[0] ?? null) === 'Bearer test-api-key'
                && data_get($payload, 'input.teacher_prompt') === 'Buatkan handout pecahan untuk kelas 5 dengan contoh dan latihan singkat.'
                && str_contains((string) data_get($payload, 'instruction'), 'Return exactly one JSON object.');
        });
    }

    public function test_prompt_interpretation_service_falls_back_when_llm_returns_partial_contract(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan handout pecahan untuk kelas 5.',
            'preferred_output_type' => 'pdf',
            'status' => MediaGenerationLifecycle::INTERPRETING,
        ]);

        config([
            'services.media_generation.interpreter.base_url' => 'https://llm.example',
        ]);

        Http::fake([
            'https://llm.example/*' => Http::response([
                'choices' => [
                    [
                        'message' => [
                            'content' => '{"schema_version":"media_prompt_understanding.v1","teacher_prompt":"partial only"}',
                        ],
                    ],
                ],
            ], 200),
        ]);

        $result = (new MediaPromptInterpretationService())->interpret($generation);

        $this->assertTrue((bool) data_get($result->interpretation_payload, 'fallback.triggered'));
        $this->assertSame('pdf', data_get($result->interpretation_payload, 'constraints.preferred_output_type'));
        $this->assertTrue((bool) data_get($result->interpretation_audit_payload, 'response.used_fallback'));
        $this->assertSame(
            MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
            data_get($result->interpretation_audit_payload, 'response.fallback_error.error_code')
        );
    }

    public function test_output_decision_service_prioritizes_teacher_override_and_builds_generation_spec(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan handout pecahan untuk kelas 5 dengan contoh dan latihan singkat.',
            'preferred_output_type' => 'pptx',
            'status' => MediaGenerationLifecycle::CLASSIFIED,
            'interpretation_payload' => $this->validInterpretationPayload(),
        ]);

        $result = (new MediaGenerationDecisionService())->resolve($generation);

        $this->assertSame('pptx', $result->resolved_output_type);
        $this->assertSame('teacher_override', data_get($result->decision_payload, 'decision_source'));
        $this->assertSame('pptx', data_get($result->generation_spec_payload, 'export_format'));
        $this->assertSame('slide', data_get($result->generation_spec_payload, 'page_or_slide_structure.unit_type'));
    }

    public function test_output_decision_service_uses_deterministic_keyword_signals_for_auto_resolution(): void
    {
        $teacher = User::factory()->teacher()->create();
        $payload = $this->validInterpretationPayload();
        $payload['output_type_candidates'] = [
            [
                'type' => 'docx',
                'score' => 0.60,
                'reason' => 'Editable worksheet remains possible.',
            ],
            [
                'type' => 'pdf',
                'score' => 0.60,
                'reason' => 'Printable handout also fits well.',
            ],
        ];
        $payload['resolved_output_type_reasoning'] = 'Both document formats are plausible for this handout request.';
        $payload['teacher_prompt'] = 'Buatkan handout printable pecahan untuk kelas 5.';

        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => $payload['teacher_prompt'],
            'preferred_output_type' => 'auto',
            'status' => MediaGenerationLifecycle::CLASSIFIED,
            'interpretation_payload' => $payload,
        ]);

        $result = (new MediaGenerationDecisionService())->resolve($generation);

        $this->assertSame('pdf', $result->resolved_output_type);
        $this->assertSame('printable_intent_detected', data_get($result->decision_payload, 'reason_code'));
        $this->assertSame('candidate_ranking', data_get($result->decision_payload, 'decision_source'));
    }

    public function test_python_media_generator_client_signs_requests_and_persists_validated_metadata(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan handout pecahan untuk kelas 5 dengan contoh dan latihan singkat.',
            'preferred_output_type' => 'pdf',
            'resolved_output_type' => 'pdf',
            'status' => MediaGenerationLifecycle::GENERATING,
            'generation_spec_payload' => MediaGenerationSpecContract::fromInterpretation($this->validInterpretationPayload(), 'pdf'),
        ]);

        config([
            'services.media_generation.python.base_url' => 'https://python.example',
            'services.media_generation.python.shared_secret' => 'shared-secret',
            'services.media_generation.python.provider' => 'klass-python',
            'services.media_generation.python.model' => 'renderer-v1',
        ]);

        Http::fake([
            'https://python.example/*' => Http::response([
                'schema_version' => 'media_generator_response.v1',
                'request_id' => 'render-123',
                'status' => 'completed',
                'data' => [
                    'generation_id' => $generation->id,
                    'artifact_delivery' => [
                        'kind' => 'temporary_path',
                        'value' => '/tmp/handout-pecahan-kelas-5.pdf',
                    ],
                    'artifact_metadata' => $this->validArtifactMetadata(),
                    'contracts' => [
                        'artifact_metadata' => MediaArtifactMetadataContract::VERSION,
                    ],
                ],
            ], 200),
        ]);

        $result = (new PythonMediaGeneratorClient())->generate($generation);

        $this->assertSame('application/pdf', $result->mime_type);
        $this->assertSame('klass-media-generator', $result->generator_provider);
        $this->assertSame('0.1.0', $result->generator_model);
        $this->assertSame('render-123', data_get($result->generator_service_response, 'response.raw_payload.request_id'));
        $this->assertSame(
            MediaArtifactMetadataContract::VERSION,
            data_get($result->generator_service_response, 'response.artifact_metadata.schema_version')
        );
        $this->assertSame(
            'temporary_path',
            data_get($result->generator_service_response, 'response.raw_payload.data.artifact_delivery.kind')
        );

        Http::assertSent(function (Request $request) use ($generation): bool {
            $timestamp = $request->header('X-Klass-Request-Timestamp')[0] ?? null;
            $signature = $request->header('X-Klass-Signature')[0] ?? null;
            $payload = json_decode($request->body(), true, 512, JSON_THROW_ON_ERROR);

            return $request->url() === 'https://python.example/v1/generate'
                && ($request->header('X-Klass-Generation-Id')[0] ?? null) === $generation->id
                && $timestamp !== null
                && $signature === hash_hmac('sha256', $timestamp . '.' . $request->body(), 'shared-secret')
                && data_get($payload, 'generation_id') === $generation->id
                && data_get($payload, 'contracts.artifact_metadata') === MediaArtifactMetadataContract::VERSION;
        });
    }

    public function test_python_media_generator_client_classifies_upstream_503_as_service_unavailable(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan handout pecahan untuk kelas 5.',
            'preferred_output_type' => 'pdf',
            'resolved_output_type' => 'pdf',
            'status' => MediaGenerationLifecycle::GENERATING,
            'generation_spec_payload' => MediaGenerationSpecContract::fromInterpretation($this->validInterpretationPayload(), 'pdf'),
        ]);

        config([
            'services.media_generation.python.base_url' => 'https://python.example',
            'services.media_generation.python.shared_secret' => 'shared-secret',
        ]);

        Http::fake([
            'https://python.example/*' => Http::response(['message' => 'temporarily unavailable'], 503),
        ]);

        try {
            (new PythonMediaGeneratorClient())->generate($generation);
            $this->fail('Expected PythonMediaGeneratorClient to throw MediaGenerationServiceException.');
        } catch (MediaGenerationServiceException $exception) {
            $this->assertSame(MediaGenerationErrorCode::PYTHON_SERVICE_UNAVAILABLE, $exception->errorCode());
        }
    }

    public function test_python_media_generator_client_maps_structured_error_hint_to_artifact_invalid(): void
    {
        $teacher = User::factory()->teacher()->create();
        $generation = MediaGeneration::create([
            'teacher_id' => $teacher->id,
            'raw_prompt' => 'Buatkan slide pecahan untuk kelas 5.',
            'preferred_output_type' => 'pptx',
            'resolved_output_type' => 'pptx',
            'status' => MediaGenerationLifecycle::GENERATING,
            'generation_spec_payload' => MediaGenerationSpecContract::fromInterpretation($this->validInterpretationPayload(), 'pptx'),
        ]);

        config([
            'services.media_generation.python.base_url' => 'https://python.example',
            'services.media_generation.python.shared_secret' => 'shared-secret',
        ]);

        Http::fake([
            'https://python.example/*' => Http::response([
                'schema_version' => 'media_generator_response.v1',
                'request_id' => 'render-error-123',
                'status' => 'failed',
                'error' => [
                    'code' => 'request_contract_invalid',
                    'message' => 'Incoming request payload failed validation.',
                    'retryable' => true,
                    'laravel_error_code_hint' => MediaGenerationErrorCode::ARTIFACT_INVALID,
                    'details' => [
                        'errors' => ['generation_spec.export_format' => ['Unsupported format.']],
                    ],
                ],
            ], 422),
        ]);

        try {
            (new PythonMediaGeneratorClient())->generate($generation);
            $this->fail('Expected PythonMediaGeneratorClient to throw MediaGenerationServiceException.');
        } catch (MediaGenerationServiceException $exception) {
            $this->assertSame(MediaGenerationErrorCode::ARTIFACT_INVALID, $exception->errorCode());
            $this->assertSame('request_contract_invalid', data_get($exception->context(), 'python_error_code'));
        }
    }

    private function validInterpretationPayload(): array
    {
        return [
            'schema_version' => MediaPromptInterpretationSchema::VERSION,
            'teacher_prompt' => 'Buatkan handout pecahan untuk siswa kelas 5 dengan contoh dan latihan singkat.',
            'language' => 'id',
            'teacher_intent' => [
                'type' => 'generate_learning_media',
                'goal' => 'Create a printable classroom handout about fractions.',
                'preferred_delivery_mode' => 'digital_download',
                'requires_clarification' => false,
            ],
            'learning_objectives' => [
                'Students identify equivalent fractions.',
                'Students solve simple fraction exercises.',
            ],
            'constraints' => [
                'preferred_output_type' => 'auto',
                'max_duration_minutes' => 45,
                'must_include' => ['worked examples', 'short exercises'],
                'avoid' => ['overly technical jargon'],
                'tone' => 'encouraging',
            ],
            'output_type_candidates' => [
                [
                    'type' => 'docx',
                    'score' => 0.61,
                    'reason' => 'Editable worksheet is possible.',
                ],
                [
                    'type' => 'pdf',
                    'score' => 0.72,
                    'reason' => 'Printable handout format matches the prompt best.',
                ],
            ],
            'resolved_output_type_reasoning' => 'PDF best fits a printable classroom handout that should look stable on every device.',
            'document_blueprint' => [
                'title' => 'Handout Pecahan Kelas 5',
                'summary' => 'Handout singkat untuk memperkenalkan pecahan senilai dan latihan dasar.',
                'sections' => [
                    [
                        'title' => 'Tujuan Belajar',
                        'purpose' => 'Frame the lesson and expected outcomes.',
                        'bullets' => ['Memahami pecahan senilai', 'Menyelesaikan latihan dasar'],
                        'estimated_length' => 'short',
                    ],
                    [
                        'title' => 'Contoh dan Latihan',
                        'purpose' => 'Provide guided practice and independent work.',
                        'bullets' => ['Tampilkan satu contoh visual', 'Berikan tiga soal latihan'],
                        'estimated_length' => 'medium',
                    ],
                ],
            ],
            'subject_context' => [
                'subject_name' => 'Matematika',
                'subject_slug' => 'matematika',
            ],
            'sub_subject_context' => [
                'sub_subject_name' => 'Pecahan',
                'sub_subject_slug' => 'pecahan',
            ],
            'target_audience' => [
                'label' => 'Siswa kelas 5',
                'level' => 'elementary',
                'age_range' => '10-11',
            ],
            'requested_media_characteristics' => [
                'tone' => 'encouraging',
                'format_preferences' => ['printable', 'structured'],
                'visual_density' => 'medium',
            ],
            'assets' => [
                [
                    'type' => 'diagram',
                    'description' => 'Fraction circle illustration',
                    'required' => true,
                ],
            ],
            'assessment_or_activity_blocks' => [
                [
                    'title' => 'Latihan Mandiri',
                    'type' => 'activity',
                    'instructions' => 'Kerjakan tiga soal pecahan senilai secara mandiri.',
                ],
            ],
            'teacher_delivery_summary' => 'Gunakan sebagai handout singkat untuk pengenalan materi dan latihan mandiri.',
            'confidence' => [
                'score' => 0.93,
                'label' => 'high',
                'rationale' => 'The prompt explicitly asks for a printable handout with examples and exercises.',
            ],
            'fallback' => [
                'triggered' => false,
                'reason_code' => null,
                'action' => null,
            ],
        ];
    }

    private function validArtifactMetadata(): array
    {
        return [
            'schema_version' => MediaArtifactMetadataContract::VERSION,
            'export_format' => 'pdf',
            'title' => 'Handout Pecahan Kelas 5',
            'filename' => 'handout-pecahan-kelas-5.pdf',
            'extension' => 'pdf',
            'mime_type' => 'application/pdf',
            'size_bytes' => 24576,
            'checksum_sha256' => str_repeat('a', 64),
            'page_count' => 5,
            'artifact_locator' => [
                'kind' => 'temporary_path',
                'value' => '/tmp/handout-pecahan-kelas-5.pdf',
            ],
            'generator' => [
                'name' => 'klass-media-generator',
                'version' => '0.1.0',
            ],
            'warnings' => [],
        ];
    }
}