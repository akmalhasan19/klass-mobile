<?php

namespace App\MediaGeneration;

use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use JsonException;

final class MediaPromptInterpretationSchema
{
    public const VERSION = 'media_prompt_understanding.v1';

    public static function allowedOutputFormats(): array
    {
        return ['docx', 'pdf', 'pptx'];
    }

    public static function allowedPreferredOutputTypes(): array
    {
        return [
            'auto',
            ...self::allowedOutputFormats(),
        ];
    }

    public static function llmInstruction(): string
    {
        return implode("\n", [
            'Interpret the teacher request for media generation.',
            'Return exactly one JSON object.',
            'Do not wrap the JSON in markdown fences.',
            'Do not add prose before or after the JSON.',
            'Use schema_version "' . self::VERSION . '".',
            'Always include these top-level keys: schema_version, teacher_prompt, language, teacher_intent, learning_objectives, constraints, output_type_candidates, resolved_output_type_reasoning, document_blueprint, subject_context, sub_subject_context, target_audience, requested_media_characteristics, assets, assessment_or_activity_blocks, teacher_delivery_summary, confidence, fallback.',
            'Use null for unavailable objects and [] for unavailable lists.',
            'Allowed output format values are only: docx, pdf, pptx.',
        ]);
    }

    public static function decodeAndValidate(string $rawJson): array
    {
        $trimmed = trim($rawJson);

        if ($trimmed === '') {
            throw new MediaGenerationContractException(
                'Prompt interpretation response must not be empty.',
                'llm_contract_failed'
            );
        }

        try {
            $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new MediaGenerationContractException(
                'Prompt interpretation returned invalid JSON.',
                'llm_contract_failed',
                ['json_error' => $exception->getMessage()]
            );
        }

        if (! is_array($decoded) || array_is_list($decoded)) {
            throw new MediaGenerationContractException(
                'Prompt interpretation must be a JSON object.',
                'llm_contract_failed'
            );
        }

        return self::validate($decoded);
    }

    public static function validate(array $payload): array
    {
        self::assertAllowedKeys($payload, self::topLevelKeys(), 'payload');
        self::assertNestedAllowedKeys($payload);

        $payload = self::applyDefaults($payload);

        $validator = Validator::make($payload, self::rules());

        if ($validator->fails()) {
            throw new MediaGenerationContractException(
                'Prompt interpretation payload failed schema validation.',
                'llm_contract_failed',
                ['errors' => $validator->errors()->toArray()]
            );
        }

        return self::normalize($payload);
    }

    public static function fallback(
        string $teacherPrompt,
        string $reasonCode = 'llm_contract_failed',
        ?string $preferredOutputType = null,
        ?string $language = null
    ): array {
        $resolvedPreferredOutputType = self::normalizePreferredOutputType($preferredOutputType);
        $candidateTypes = $resolvedPreferredOutputType === 'auto'
            ? self::allowedOutputFormats()
            : [$resolvedPreferredOutputType];
        $candidateScore = $resolvedPreferredOutputType === 'auto' ? 0.34 : 0.51;

        return self::validate([
            'schema_version' => self::VERSION,
            'teacher_prompt' => $teacherPrompt,
            'language' => $language !== null && trim($language) !== '' ? trim($language) : 'und',
            'teacher_intent' => [
                'type' => 'generate_learning_media',
                'goal' => 'Retry prompt interpretation before sending any artifact request to the renderer.',
                'preferred_delivery_mode' => 'digital_download',
                'requires_clarification' => true,
            ],
            'learning_objectives' => [],
            'constraints' => [
                'preferred_output_type' => $resolvedPreferredOutputType,
                'must_include' => [],
                'avoid' => [],
                'tone' => null,
                'max_duration_minutes' => null,
            ],
            'output_type_candidates' => array_map(
                static fn (string $type): array => [
                    'type' => $type,
                    'score' => $candidateScore,
                    'reason' => 'Fallback candidate produced after the LLM response failed contract validation.',
                ],
                $candidateTypes
            ),
            'resolved_output_type_reasoning' => 'Fallback payload created because the prompt interpretation response was invalid or incomplete.',
            'document_blueprint' => [
                'title' => 'Interpretation Retry Required',
                'summary' => 'The teacher request must be interpreted again before any media file is rendered.',
                'sections' => [
                    [
                        'title' => 'Retry Interpretation',
                        'purpose' => 'Prevent renderer execution until the contract is valid again.',
                        'bullets' => ['Re-run interpretation with JSON-only output.'],
                        'estimated_length' => 'short',
                    ],
                ],
            ],
            'subject_context' => null,
            'sub_subject_context' => null,
            'target_audience' => null,
            'requested_media_characteristics' => [
                'tone' => null,
                'format_preferences' => $resolvedPreferredOutputType === 'auto' ? [] : [$resolvedPreferredOutputType],
                'visual_density' => null,
            ],
            'assets' => [],
            'assessment_or_activity_blocks' => [],
            'teacher_delivery_summary' => 'The prompt was received, but the interpretation contract failed validation and must be retried.',
            'confidence' => [
                'score' => 0.0,
                'label' => 'low',
                'rationale' => 'Fallback contract generated because the LLM response was invalid.',
            ],
            'fallback' => [
                'triggered' => true,
                'reason_code' => $reasonCode,
                'action' => 'retry_interpretation',
            ],
        ]);
    }

    private static function rules(): array
    {
        return [
            'schema_version' => ['required', 'string', Rule::in([self::VERSION])],
            'teacher_prompt' => ['required', 'string', 'max:5000'],
            'language' => ['required', 'string', 'max:32'],
            'teacher_intent' => ['required', 'array'],
            'teacher_intent.type' => ['required', 'string', 'max:100'],
            'teacher_intent.goal' => ['required', 'string', 'max:500'],
            'teacher_intent.preferred_delivery_mode' => ['required', 'string', 'max:100'],
            'teacher_intent.requires_clarification' => ['required', 'boolean'],
            'learning_objectives' => ['present', 'array'],
            'learning_objectives.*' => ['string', 'max:300'],
            'constraints' => ['required', 'array'],
            'constraints.preferred_output_type' => ['required', 'string', Rule::in(self::allowedPreferredOutputTypes())],
            'constraints.max_duration_minutes' => ['nullable', 'integer', 'min:1', 'max:1440'],
            'constraints.must_include' => ['present', 'array'],
            'constraints.must_include.*' => ['string', 'max:300'],
            'constraints.avoid' => ['present', 'array'],
            'constraints.avoid.*' => ['string', 'max:300'],
            'constraints.tone' => ['nullable', 'string', 'max:100'],
            'output_type_candidates' => ['required', 'array', 'min:1'],
            'output_type_candidates.*.type' => ['required', 'string', Rule::in(self::allowedOutputFormats())],
            'output_type_candidates.*.score' => ['required', 'numeric', 'min:0', 'max:1'],
            'output_type_candidates.*.reason' => ['required', 'string', 'max:500'],
            'resolved_output_type_reasoning' => ['required', 'string', 'max:1000'],
            'document_blueprint' => ['required', 'array'],
            'document_blueprint.title' => ['required', 'string', 'max:200'],
            'document_blueprint.summary' => ['required', 'string', 'max:1000'],
            'document_blueprint.sections' => ['required', 'array', 'min:1'],
            'document_blueprint.sections.*.title' => ['required', 'string', 'max:200'],
            'document_blueprint.sections.*.purpose' => ['required', 'string', 'max:500'],
            'document_blueprint.sections.*.bullets' => ['present', 'array'],
            'document_blueprint.sections.*.bullets.*' => ['string', 'max:300'],
            'document_blueprint.sections.*.estimated_length' => ['required', 'string', Rule::in(['short', 'medium', 'long'])],
            'subject_context' => ['nullable', 'array'],
            'subject_context.subject_name' => ['required_with:subject_context', 'string', 'max:100'],
            'subject_context.subject_slug' => ['nullable', 'string', 'max:100'],
            'sub_subject_context' => ['nullable', 'array'],
            'sub_subject_context.sub_subject_name' => ['required_with:sub_subject_context', 'string', 'max:100'],
            'sub_subject_context.sub_subject_slug' => ['nullable', 'string', 'max:100'],
            'target_audience' => ['nullable', 'array'],
            'target_audience.label' => ['required_with:target_audience', 'string', 'max:100'],
            'target_audience.level' => ['nullable', 'string', 'max:100'],
            'target_audience.age_range' => ['nullable', 'string', 'max:100'],
            'requested_media_characteristics' => ['required', 'array'],
            'requested_media_characteristics.tone' => ['nullable', 'string', 'max:100'],
            'requested_media_characteristics.format_preferences' => ['present', 'array'],
            'requested_media_characteristics.format_preferences.*' => ['string', 'max:100'],
            'requested_media_characteristics.visual_density' => ['nullable', 'string', Rule::in(['low', 'medium', 'high'])],
            'assets' => ['present', 'array'],
            'assets.*.type' => ['required', 'string', Rule::in(['text', 'image', 'table', 'chart', 'diagram', 'reference'])],
            'assets.*.description' => ['required', 'string', 'max:500'],
            'assets.*.required' => ['required', 'boolean'],
            'assessment_or_activity_blocks' => ['present', 'array'],
            'assessment_or_activity_blocks.*.title' => ['required', 'string', 'max:200'],
            'assessment_or_activity_blocks.*.type' => ['required', 'string', Rule::in(['assessment', 'activity', 'reflection', 'quiz', 'assignment'])],
            'assessment_or_activity_blocks.*.instructions' => ['required', 'string', 'max:1000'],
            'teacher_delivery_summary' => ['required', 'string', 'max:1000'],
            'confidence' => ['required', 'array'],
            'confidence.score' => ['required', 'numeric', 'min:0', 'max:1'],
            'confidence.label' => ['required', 'string', Rule::in(['low', 'medium', 'high'])],
            'confidence.rationale' => ['nullable', 'string', 'max:500'],
            'fallback' => ['required', 'array'],
            'fallback.triggered' => ['required', 'boolean'],
            'fallback.reason_code' => ['nullable', 'string', 'max:100'],
            'fallback.action' => ['nullable', 'string', 'max:100'],
        ];
    }

    private static function normalize(array $payload): array
    {
        return [
            'schema_version' => self::VERSION,
            'teacher_prompt' => trim($payload['teacher_prompt']),
            'language' => trim($payload['language']),
            'teacher_intent' => [
                'type' => trim($payload['teacher_intent']['type']),
                'goal' => trim($payload['teacher_intent']['goal']),
                'preferred_delivery_mode' => trim($payload['teacher_intent']['preferred_delivery_mode']),
                'requires_clarification' => (bool) $payload['teacher_intent']['requires_clarification'],
            ],
            'learning_objectives' => array_values($payload['learning_objectives']),
            'constraints' => [
                'preferred_output_type' => trim($payload['constraints']['preferred_output_type']),
                'max_duration_minutes' => $payload['constraints']['max_duration_minutes'],
                'must_include' => array_values($payload['constraints']['must_include']),
                'avoid' => array_values($payload['constraints']['avoid']),
                'tone' => $payload['constraints']['tone'] !== null ? trim($payload['constraints']['tone']) : null,
            ],
            'output_type_candidates' => self::normalizeCandidates($payload['output_type_candidates']),
            'resolved_output_type_reasoning' => trim($payload['resolved_output_type_reasoning']),
            'document_blueprint' => [
                'title' => trim($payload['document_blueprint']['title']),
                'summary' => trim($payload['document_blueprint']['summary']),
                'sections' => array_map(
                    static fn (array $section): array => [
                        'title' => trim($section['title']),
                        'purpose' => trim($section['purpose']),
                        'bullets' => array_values($section['bullets']),
                        'estimated_length' => trim($section['estimated_length']),
                    ],
                    $payload['document_blueprint']['sections']
                ),
            ],
            'subject_context' => self::normalizeNullableObject($payload['subject_context']),
            'sub_subject_context' => self::normalizeNullableObject($payload['sub_subject_context']),
            'target_audience' => self::normalizeNullableObject($payload['target_audience']),
            'requested_media_characteristics' => [
                'tone' => $payload['requested_media_characteristics']['tone'] !== null
                    ? trim($payload['requested_media_characteristics']['tone'])
                    : null,
                'format_preferences' => array_values($payload['requested_media_characteristics']['format_preferences']),
                'visual_density' => $payload['requested_media_characteristics']['visual_density'],
            ],
            'assets' => array_map(
                static fn (array $asset): array => [
                    'type' => trim($asset['type']),
                    'description' => trim($asset['description']),
                    'required' => (bool) $asset['required'],
                ],
                $payload['assets']
            ),
            'assessment_or_activity_blocks' => array_map(
                static fn (array $block): array => [
                    'title' => trim($block['title']),
                    'type' => trim($block['type']),
                    'instructions' => trim($block['instructions']),
                ],
                $payload['assessment_or_activity_blocks']
            ),
            'teacher_delivery_summary' => trim($payload['teacher_delivery_summary']),
            'confidence' => [
                'score' => (float) $payload['confidence']['score'],
                'label' => trim($payload['confidence']['label']),
                'rationale' => $payload['confidence']['rationale'] !== null ? trim($payload['confidence']['rationale']) : null,
            ],
            'fallback' => [
                'triggered' => (bool) $payload['fallback']['triggered'],
                'reason_code' => $payload['fallback']['reason_code'] !== null ? trim($payload['fallback']['reason_code']) : null,
                'action' => $payload['fallback']['action'] !== null ? trim($payload['fallback']['action']) : null,
            ],
        ];
    }

    private static function normalizeCandidates(array $candidates): array
    {
        $indexedCandidates = array_map(
            static fn (array $candidate, int $index): array => [
                'index' => $index,
                'type' => trim($candidate['type']),
                'score' => round((float) $candidate['score'], 4),
                'reason' => trim($candidate['reason']),
            ],
            $candidates,
            array_keys($candidates)
        );

        usort($indexedCandidates, static function (array $left, array $right): int {
            if ($left['score'] !== $right['score']) {
                return $right['score'] <=> $left['score'];
            }

            return $left['index'] <=> $right['index'];
        });

        return array_map(static function (array $candidate): array {
            unset($candidate['index']);

            return $candidate;
        }, $indexedCandidates);
    }

    private static function applyDefaults(array $payload): array
    {
        if (! array_key_exists('requested_media_characteristics', $payload)) {
            $payload['requested_media_characteristics'] = [
                'tone' => null,
                'format_preferences' => [],
                'visual_density' => null,
            ];
        } elseif (is_array($payload['requested_media_characteristics'])) {
            $payload['requested_media_characteristics'] = array_merge([
                'tone' => null,
                'format_preferences' => [],
                'visual_density' => null,
            ], $payload['requested_media_characteristics']);
        }

        if (! array_key_exists('constraints', $payload)) {
            return array_merge([
                'subject_context' => null,
                'sub_subject_context' => null,
                'target_audience' => null,
                'assets' => [],
                'assessment_or_activity_blocks' => [],
                'fallback' => [
                    'triggered' => false,
                    'reason_code' => null,
                    'action' => null,
                ],
            ], $payload);
        }

        if (is_array($payload['constraints'])) {
            $payload['constraints'] = array_merge([
                'preferred_output_type' => 'auto',
                'max_duration_minutes' => null,
                'must_include' => [],
                'avoid' => [],
                'tone' => null,
            ], $payload['constraints']);
        }

        if (! array_key_exists('subject_context', $payload)) {
            $payload['subject_context'] = null;
        }

        if (! array_key_exists('sub_subject_context', $payload)) {
            $payload['sub_subject_context'] = null;
        }

        if (! array_key_exists('target_audience', $payload)) {
            $payload['target_audience'] = null;
        }

        if (! array_key_exists('assets', $payload)) {
            $payload['assets'] = [];
        }

        if (! array_key_exists('assessment_or_activity_blocks', $payload)) {
            $payload['assessment_or_activity_blocks'] = [];
        }

        if (! array_key_exists('fallback', $payload)) {
            $payload['fallback'] = [
                'triggered' => false,
                'reason_code' => null,
                'action' => null,
            ];
        } elseif (is_array($payload['fallback'])) {
            $payload['fallback'] = array_merge([
                'triggered' => false,
                'reason_code' => null,
                'action' => null,
            ], $payload['fallback']);
        }

        return $payload;
    }

    private static function assertNestedAllowedKeys(array $payload): void
    {
        if (isset($payload['teacher_intent']) && is_array($payload['teacher_intent'])) {
            self::assertAllowedKeys($payload['teacher_intent'], ['type', 'goal', 'preferred_delivery_mode', 'requires_clarification'], 'teacher_intent');
        }

        if (isset($payload['constraints']) && is_array($payload['constraints'])) {
            self::assertAllowedKeys($payload['constraints'], ['preferred_output_type', 'max_duration_minutes', 'must_include', 'avoid', 'tone'], 'constraints');
        }

        if (isset($payload['document_blueprint']) && is_array($payload['document_blueprint'])) {
            self::assertAllowedKeys($payload['document_blueprint'], ['title', 'summary', 'sections'], 'document_blueprint');

            if (isset($payload['document_blueprint']['sections']) && is_array($payload['document_blueprint']['sections'])) {
                foreach ($payload['document_blueprint']['sections'] as $index => $section) {
                    if (is_array($section)) {
                        self::assertAllowedKeys($section, ['title', 'purpose', 'bullets', 'estimated_length'], 'document_blueprint.sections.' . $index);
                    }
                }
            }
        }

        if (isset($payload['subject_context']) && is_array($payload['subject_context'])) {
            self::assertAllowedKeys($payload['subject_context'], ['subject_name', 'subject_slug'], 'subject_context');
        }

        if (isset($payload['sub_subject_context']) && is_array($payload['sub_subject_context'])) {
            self::assertAllowedKeys($payload['sub_subject_context'], ['sub_subject_name', 'sub_subject_slug'], 'sub_subject_context');
        }

        if (isset($payload['target_audience']) && is_array($payload['target_audience'])) {
            self::assertAllowedKeys($payload['target_audience'], ['label', 'level', 'age_range'], 'target_audience');
        }

        if (isset($payload['requested_media_characteristics']) && is_array($payload['requested_media_characteristics'])) {
            self::assertAllowedKeys($payload['requested_media_characteristics'], ['tone', 'format_preferences', 'visual_density'], 'requested_media_characteristics');
        }

        if (isset($payload['output_type_candidates']) && is_array($payload['output_type_candidates'])) {
            foreach ($payload['output_type_candidates'] as $index => $candidate) {
                if (is_array($candidate)) {
                    self::assertAllowedKeys($candidate, ['type', 'score', 'reason'], 'output_type_candidates.' . $index);
                }
            }
        }

        if (isset($payload['assets']) && is_array($payload['assets'])) {
            foreach ($payload['assets'] as $index => $asset) {
                if (is_array($asset)) {
                    self::assertAllowedKeys($asset, ['type', 'description', 'required'], 'assets.' . $index);
                }
            }
        }

        if (isset($payload['assessment_or_activity_blocks']) && is_array($payload['assessment_or_activity_blocks'])) {
            foreach ($payload['assessment_or_activity_blocks'] as $index => $block) {
                if (is_array($block)) {
                    self::assertAllowedKeys($block, ['title', 'type', 'instructions'], 'assessment_or_activity_blocks.' . $index);
                }
            }
        }

        if (isset($payload['confidence']) && is_array($payload['confidence'])) {
            self::assertAllowedKeys($payload['confidence'], ['score', 'label', 'rationale'], 'confidence');
        }

        if (isset($payload['fallback']) && is_array($payload['fallback'])) {
            self::assertAllowedKeys($payload['fallback'], ['triggered', 'reason_code', 'action'], 'fallback');
        }
    }

    private static function assertAllowedKeys(array $payload, array $allowedKeys, string $path): void
    {
        $unknownKeys = array_diff(array_keys($payload), $allowedKeys);

        if ($unknownKeys === []) {
            return;
        }

        throw new MediaGenerationContractException(
            'Prompt interpretation payload contains unsupported fields.',
            'llm_contract_failed',
            [
                'path' => $path,
                'unknown_fields' => array_values($unknownKeys),
            ]
        );
    }

    private static function normalizePreferredOutputType(?string $preferredOutputType): string
    {
        if ($preferredOutputType === null || trim($preferredOutputType) === '') {
            return 'auto';
        }

        $normalized = strtolower(trim($preferredOutputType));

        if (! in_array($normalized, self::allowedPreferredOutputTypes(), true)) {
            throw new MediaGenerationContractException(
                'Unsupported preferred output type.',
                'llm_contract_failed',
                ['preferred_output_type' => $preferredOutputType]
            );
        }

        return $normalized;
    }

    private static function normalizeNullableObject(mixed $value): ?array
    {
        return is_array($value) ? $value : null;
    }

    private static function topLevelKeys(): array
    {
        return [
            'schema_version',
            'teacher_prompt',
            'language',
            'teacher_intent',
            'learning_objectives',
            'constraints',
            'output_type_candidates',
            'resolved_output_type_reasoning',
            'document_blueprint',
            'subject_context',
            'sub_subject_context',
            'target_audience',
            'requested_media_characteristics',
            'assets',
            'assessment_or_activity_blocks',
            'teacher_delivery_summary',
            'confidence',
            'fallback',
        ];
    }
}