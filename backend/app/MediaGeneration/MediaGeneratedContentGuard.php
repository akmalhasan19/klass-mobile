<?php

namespace App\MediaGeneration;

final class MediaGeneratedContentGuard
{
    /**
     * @var array<string, string>
     */
    private const DRAFT_SCAFFOLD_PATTERNS = [
        '/\bbagian ini disusun untuk\b/iu' => 'outline_scaffold',
        '/\bfokus utamanya meliputi\b/iu' => 'outline_scaffold',
        '/\bjelaskan ide pokoknya secara runtut\b/iu' => 'outline_scaffold',
        '/\bsampaikan inti materinya secara singkat, jelas, dan mudah dipresentasikan\b/iu' => 'outline_scaffold',
        '/\bdorong siswa merangkum kembali inti\b/iu' => 'outline_scaffold',
        '/\bthis section is written for\b/iu' => 'outline_scaffold',
        '/\bthe main focus includes\b/iu' => 'outline_scaffold',
        '/\bpresent the main idea in sequence\b/iu' => 'outline_scaffold',
        '/\bkeep the explanation concise, clear, and ready for presentation\b/iu' => 'outline_scaffold',
        '/\bencourage students to restate the key idea\b/iu' => 'outline_scaffold',
    ];

    /**
     * @var array<string, string>
     */
    private const FORBIDDEN_PATTERNS = [
        '/return exactly one json object/iu' => 'json_contract_instruction',
        '/do not wrap the json/iu' => 'json_contract_instruction',
        '/do not add prose before or after the json/iu' => 'json_contract_instruction',
        '/use schema_version/iu' => 'schema_instruction',
        '/always include these top-level keys/iu' => 'schema_instruction',
        '/top-level keys\s*:/iu' => 'schema_instruction',
        '/each sections entry must include/iu' => 'schema_instruction',
        '/each body_blocks entry/iu' => 'schema_instruction',
        '/body_blocks\.content/iu' => 'schema_instruction',
        '/fallback\.triggered/iu' => 'schema_instruction',
        '/adapter contract guardrails/iu' => 'adapter_instruction',
        '/json[- ]only output/iu' => 'json_contract_instruction',
        '/media_content_draft\.v1/iu' => 'schema_version_leak',
        '/media_prompt_understanding\.v1/iu' => 'schema_version_leak',
        '/re-run interpretation with json-only output/iu' => 'pipeline_instruction',
        '/retry prompt interpretation/iu' => 'pipeline_instruction',
        '/before any media file is rendered/iu' => 'pipeline_instruction',
        '/before sending any artifact request to the renderer/iu' => 'pipeline_instruction',
        '/internal taxonomy guidance for alignment only/iu' => 'taxonomy_instruction',
        '/curriculum-alignment hint/iu' => 'taxonomy_instruction',
    ];

    /**
     * @param  array<string, mixed>  $payload
     */
    public static function assertInterpretationPayload(array $payload): void
    {
        self::assertTextSafe('teacher_intent.goal', data_get($payload, 'teacher_intent.goal'));

        foreach (array_values((array) data_get($payload, 'learning_objectives', [])) as $index => $objective) {
            self::assertTextSafe('learning_objectives.' . $index, $objective);
        }

        foreach (array_values((array) data_get($payload, 'constraints.must_include', [])) as $index => $constraint) {
            self::assertTextSafe('constraints.must_include.' . $index, $constraint);
        }

        foreach (array_values((array) data_get($payload, 'constraints.avoid', [])) as $index => $constraint) {
            self::assertTextSafe('constraints.avoid.' . $index, $constraint);
        }

        foreach (array_values((array) data_get($payload, 'output_type_candidates', [])) as $index => $candidate) {
            self::assertTextSafe('output_type_candidates.' . $index . '.reason', data_get($candidate, 'reason'));
        }

        self::assertTextSafe('resolved_output_type_reasoning', data_get($payload, 'resolved_output_type_reasoning'));
        self::assertTextSafe('document_blueprint.title', data_get($payload, 'document_blueprint.title'));
        self::assertTextSafe('document_blueprint.summary', data_get($payload, 'document_blueprint.summary'));

        foreach (array_values((array) data_get($payload, 'document_blueprint.sections', [])) as $sectionIndex => $section) {
            self::assertTextSafe('document_blueprint.sections.' . $sectionIndex . '.title', data_get($section, 'title'));
            self::assertTextSafe('document_blueprint.sections.' . $sectionIndex . '.purpose', data_get($section, 'purpose'));

            foreach (array_values((array) data_get($section, 'bullets', [])) as $bulletIndex => $bullet) {
                self::assertTextSafe('document_blueprint.sections.' . $sectionIndex . '.bullets.' . $bulletIndex, $bullet);
            }
        }

        foreach (array_values((array) data_get($payload, 'assessment_or_activity_blocks', [])) as $index => $block) {
            self::assertTextSafe('assessment_or_activity_blocks.' . $index . '.title', data_get($block, 'title'));
            self::assertTextSafe('assessment_or_activity_blocks.' . $index . '.instructions', data_get($block, 'instructions'));
        }

        self::assertTextSafe('teacher_delivery_summary', data_get($payload, 'teacher_delivery_summary'));
        self::assertTextSafe('confidence.rationale', data_get($payload, 'confidence.rationale'));
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    public static function assertContentDraftPayload(array $payload, ?string $resolvedOutputType = null): void
    {
        self::assertTextSafe('title', data_get($payload, 'title'));
        self::assertTextSafe('summary', data_get($payload, 'summary'));
        self::assertTextSafe('teacher_delivery_summary', data_get($payload, 'teacher_delivery_summary'));
        self::assertDraftMaterialText('summary', data_get($payload, 'summary'));

        foreach (array_values((array) data_get($payload, 'learning_objectives', [])) as $index => $objective) {
            self::assertTextSafe('learning_objectives.' . $index, $objective);
        }

        foreach (array_values((array) data_get($payload, 'sections', [])) as $sectionIndex => $section) {
            self::assertTextSafe('sections.' . $sectionIndex . '.title', data_get($section, 'title'));
            self::assertTextSafe('sections.' . $sectionIndex . '.purpose', data_get($section, 'purpose'));

            foreach (array_values((array) data_get($section, 'body_blocks', [])) as $blockIndex => $block) {
                self::assertTextSafe('sections.' . $sectionIndex . '.body_blocks.' . $blockIndex . '.content', data_get($block, 'content'));
                self::assertDraftMaterialText(
                    'sections.' . $sectionIndex . '.body_blocks.' . $blockIndex . '.content',
                    data_get($block, 'content')
                );
            }
        }

        self::assertSectionNarrative((array) data_get($payload, 'sections', []), $resolvedOutputType);
    }

    /**
     * @param  array<int, array<string, mixed>>  $sections
     */
    private static function assertSectionNarrative(array $sections, ?string $resolvedOutputType): void
    {
        $normalizedOutputType = strtolower(trim((string) $resolvedOutputType));

        if ($normalizedOutputType === 'pptx') {
            return;
        }

        foreach ($sections as $sectionIndex => $section) {
            $paragraphBlocks = array_values(array_filter(
                (array) ($section['body_blocks'] ?? []),
                static function (mixed $block): bool {
                    if (! is_array($block)) {
                        return false;
                    }

                    return ($block['type'] ?? null) === 'paragraph'
                        && self::textLength((string) ($block['content'] ?? '')) >= 60;
                }
            ));

            if ($paragraphBlocks !== []) {
                continue;
            }

            throw new MediaGenerationContractException(
                'Document content must include at least one explanatory paragraph in every section.',
                MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
                [
                    'path' => 'sections.' . $sectionIndex . '.body_blocks',
                    'reason' => 'missing_explanatory_paragraph',
                ]
            );
        }
    }

    private static function assertTextSafe(string $path, mixed $value): void
    {
        if (! is_string($value)) {
            return;
        }

        $text = trim($value);

        if ($text === '') {
            return;
        }

        foreach (self::FORBIDDEN_PATTERNS as $pattern => $reason) {
            if (preg_match($pattern, $text) === 1) {
                throw new MediaGenerationContractException(
                    'Generated content contains internal authoring instructions instead of classroom-ready material.',
                    MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
                    [
                        'path' => $path,
                        'reason' => $reason,
                        'matched_pattern' => $pattern,
                    ]
                );
            }
        }
    }

    private static function assertDraftMaterialText(string $path, mixed $value): void
    {
        if (! is_string($value)) {
            return;
        }

        $text = trim($value);

        if ($text === '') {
            return;
        }

        foreach (self::DRAFT_SCAFFOLD_PATTERNS as $pattern => $reason) {
            if (preg_match($pattern, $text) === 1) {
                throw new MediaGenerationContractException(
                    'Generated content is still outline scaffolding instead of final classroom-ready material.',
                    MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
                    [
                        'path' => $path,
                        'reason' => $reason,
                        'matched_pattern' => $pattern,
                    ]
                );
            }
        }
    }

    private static function textLength(string $text): int
    {
        $normalized = preg_replace('/\s+/u', ' ', trim($text));

        return mb_strlen($normalized ?? trim($text));
    }
}