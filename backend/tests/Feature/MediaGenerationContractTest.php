<?php

namespace Tests\Feature;

use App\MediaGeneration\MediaArtifactMetadataContract;
use App\MediaGeneration\MediaGenerationContractException;
use App\MediaGeneration\MediaGenerationLifecycle;
use App\MediaGeneration\MediaGenerationSpecContract;
use App\MediaGeneration\MediaPromptInterpretationSchema;
use Tests\TestCase;

class MediaGenerationContractTest extends TestCase
{
    public function test_lifecycle_definition_locks_minimum_statuses_retry_behaviors_and_terminal_states(): void
    {
        $definition = MediaGenerationLifecycle::definition();

        $this->assertSame(MediaGenerationLifecycle::VERSION, $definition['version']);
        $this->assertSame(
            ['queued', 'interpreting', 'classified', 'generating', 'uploading', 'publishing', 'completed', 'failed'],
            $definition['minimum_statuses']
        );
        $this->assertTrue($definition['cancelled_prepared']);
        $this->assertSame(['completed', 'failed', 'cancelled'], $definition['terminal_states']);
        $this->assertSame('restart_from_interpreting', MediaGenerationLifecycle::retryBehavior(MediaGenerationLifecycle::FAILED));
        $this->assertSame('manual_requeue_only', MediaGenerationLifecycle::retryBehavior(MediaGenerationLifecycle::CANCELLED));
    }

    public function test_lifecycle_validates_known_transitions(): void
    {
        $this->assertTrue(MediaGenerationLifecycle::canTransition(MediaGenerationLifecycle::QUEUED, MediaGenerationLifecycle::INTERPRETING));
        $this->assertTrue(MediaGenerationLifecycle::canTransition(MediaGenerationLifecycle::PUBLISHING, MediaGenerationLifecycle::COMPLETED));
        $this->assertFalse(MediaGenerationLifecycle::canTransition(MediaGenerationLifecycle::COMPLETED, MediaGenerationLifecycle::GENERATING));
        $this->assertFalse(MediaGenerationLifecycle::canTransition(MediaGenerationLifecycle::PUBLISHING, MediaGenerationLifecycle::CANCELLED));
    }

    public function test_prompt_interpretation_schema_decodes_json_only_payload_and_sorts_candidates(): void
    {
        $payload = MediaPromptInterpretationSchema::decodeAndValidate(json_encode($this->validInterpretationPayload(), JSON_THROW_ON_ERROR));

        $this->assertSame(MediaPromptInterpretationSchema::VERSION, $payload['schema_version']);
        $this->assertSame('pdf', $payload['output_type_candidates'][0]['type']);
        $this->assertSame('docx', $payload['output_type_candidates'][1]['type']);
        $this->assertFalse($payload['fallback']['triggered']);
        $this->assertStringContainsString('Return exactly one JSON object.', MediaPromptInterpretationSchema::llmInstruction());
    }

    public function test_prompt_interpretation_schema_rejects_invalid_json_only_contract(): void
    {
        $this->expectException(MediaGenerationContractException::class);

        MediaPromptInterpretationSchema::decodeAndValidate("```json\n{}\n```");
    }

    public function test_prompt_interpretation_schema_builds_deterministic_fallback_payload(): void
    {
        $fallback = MediaPromptInterpretationSchema::fallback(
            'Buatkan media belajar pecahan untuk kelas 5.',
            preferredOutputType: 'pdf'
        );

        $this->assertTrue($fallback['fallback']['triggered']);
        $this->assertSame('pdf', $fallback['constraints']['preferred_output_type']);
        $this->assertSame('pdf', $fallback['output_type_candidates'][0]['type']);
        $this->assertSame('retry_interpretation', $fallback['fallback']['action']);
    }

    public function test_generation_spec_contract_normalizes_interpretation_payload_without_raw_prompt(): void
    {
        $spec = MediaGenerationSpecContract::fromInterpretation($this->validInterpretationPayload());

        $this->assertSame(MediaGenerationSpecContract::VERSION, $spec['schema_version']);
        $this->assertSame('pdf', $spec['export_format']);
        $this->assertArrayNotHasKey('teacher_prompt', $spec);
        $this->assertSame('document', $spec['layout_hints']['document_mode']);
        $this->assertSame(MediaArtifactMetadataContract::VERSION, $spec['contract_versions']['generator_output_metadata']);
        $this->assertSame('bullet', $spec['sections'][0]['body_blocks'][0]['type']);
    }

    public function test_generation_spec_contract_honors_override_and_validates_python_metadata(): void
    {
        $spec = MediaGenerationSpecContract::fromInterpretation($this->validInterpretationPayload(), 'pptx');

        $this->assertSame('pptx', $spec['export_format']);
        $this->assertSame('slide', $spec['page_or_slide_structure']['unit_type']);

        $metadata = MediaArtifactMetadataContract::validate([
            'schema_version' => MediaArtifactMetadataContract::VERSION,
            'export_format' => 'pptx',
            'title' => 'Deck Pecahan',
            'filename' => 'deck-pecahan.pptx',
            'extension' => 'pptx',
            'mime_type' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'size_bytes' => 24576,
            'checksum_sha256' => str_repeat('a', 64),
            'slide_count' => 12,
            'artifact_locator' => [
                'kind' => 'temporary_path',
                'value' => '/tmp/deck-pecahan.pptx',
            ],
            'generator' => [
                'name' => 'klass-media-generator',
                'version' => '0.1.0',
            ],
        ]);

        $this->assertSame('pptx', $metadata['extension']);
        $this->assertSame(12, $metadata['slide_count']);
    }

    public function test_python_metadata_contract_rejects_mismatched_extension(): void
    {
        $this->expectException(MediaGenerationContractException::class);

        MediaArtifactMetadataContract::validate([
            'schema_version' => MediaArtifactMetadataContract::VERSION,
            'export_format' => 'pdf',
            'title' => 'Handout Pecahan',
            'filename' => 'handout-pecahan.docx',
            'extension' => 'docx',
            'mime_type' => 'application/pdf',
            'size_bytes' => 12000,
            'checksum_sha256' => str_repeat('b', 64),
            'artifact_locator' => [
                'kind' => 'temporary_path',
                'value' => '/tmp/handout-pecahan.pdf',
            ],
            'generator' => [
                'name' => 'klass-media-generator',
                'version' => '0.1.0',
            ],
        ]);
    }

    public function test_python_metadata_contract_rejects_filename_extension_mismatch(): void
    {
        $this->expectException(MediaGenerationContractException::class);

        MediaArtifactMetadataContract::validate([
            'schema_version' => MediaArtifactMetadataContract::VERSION,
            'export_format' => 'pdf',
            'title' => 'Handout Pecahan',
            'filename' => 'handout-pecahan.docx',
            'extension' => 'pdf',
            'mime_type' => 'application/pdf',
            'size_bytes' => 12000,
            'checksum_sha256' => str_repeat('b', 64),
            'artifact_locator' => [
                'kind' => 'temporary_path',
                'value' => '/tmp/handout-pecahan.pdf',
            ],
            'generator' => [
                'name' => 'klass-media-generator',
                'version' => '0.1.0',
            ],
        ]);
    }

    public function test_python_metadata_contract_rejects_non_canonical_mime_type(): void
    {
        $this->expectException(MediaGenerationContractException::class);

        MediaArtifactMetadataContract::validate([
            'schema_version' => MediaArtifactMetadataContract::VERSION,
            'export_format' => 'docx',
            'title' => 'Handout Pecahan',
            'filename' => 'handout-pecahan.docx',
            'extension' => 'docx',
            'mime_type' => 'application/zip',
            'size_bytes' => 12000,
            'checksum_sha256' => str_repeat('c', 64),
            'artifact_locator' => [
                'kind' => 'temporary_path',
                'value' => '/tmp/handout-pecahan.docx',
            ],
            'generator' => [
                'name' => 'klass-media-generator',
                'version' => '0.1.0',
            ],
        ]);
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
}