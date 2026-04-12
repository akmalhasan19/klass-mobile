<?php

namespace App\MediaGeneration;

use App\Models\MediaGeneration;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use JsonException;

final class MediaContentDraftSchema
{
    public const VERSION = 'media_content_draft.v1';

    public static function llmInstruction(): string
    {
        return implode("\n", [
            'Draft the full classroom-ready learning material from the interpreted teacher request.',
            'Return exactly one JSON object.',
            'Do not wrap the JSON in markdown fences.',
            'Do not add prose before or after the JSON.',
            'Use schema_version "' . self::VERSION . '".',
            'Always include these top-level keys: schema_version, title, summary, learning_objectives, sections, teacher_delivery_summary, fallback.',
            'Each sections entry must include: title, purpose, body_blocks, emphasis.',
            'Each body_blocks entry must be an object with type and content.',
            'Write actual teaching content inside body_blocks.content. Do not output planning notes, schema explanations, placeholders, or instructions about what should be written later.',
            'Prefer paragraph blocks for explanations. Use bullet or checklist blocks only for lists, steps, or short exercises.',
            'Use the same language as input.interpretation.language.',
            'Keep the content aligned with input.resolved_output_type: fuller prose for pdf/docx, tighter points for pptx.',
            'Set fallback.triggered to false unless you explicitly need to signal degraded drafting.',
        ]);
    }

    public static function decodeAndValidate(string $rawJson): array
    {
        $trimmed = trim($rawJson);

        if ($trimmed === '') {
            throw new MediaGenerationContractException(
                'Content draft response must not be empty.',
                MediaGenerationErrorCode::LLM_CONTRACT_FAILED
            );
        }

        try {
            $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            throw new MediaGenerationContractException(
                'Content draft returned invalid JSON.',
                MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
                ['json_error' => $exception->getMessage()]
            );
        }

        if (! is_array($decoded) || array_is_list($decoded)) {
            throw new MediaGenerationContractException(
                'Content draft must be a JSON object.',
                MediaGenerationErrorCode::LLM_CONTRACT_FAILED
            );
        }

        return self::validate($decoded);
    }

    public static function validate(array $payload): array
    {
        self::assertAllowedKeys($payload, self::topLevelKeys(), 'payload');
        self::assertNestedAllowedKeys($payload);

        $payload = self::applyDefaults($payload);

        $validator = Validator::make($payload, [
            'schema_version' => ['required', 'string', Rule::in([self::VERSION])],
            'title' => ['required', 'string', 'max:200'],
            'summary' => ['required', 'string', 'max:1000'],
            'learning_objectives' => ['present', 'array'],
            'learning_objectives.*' => ['string', 'max:300'],
            'sections' => ['required', 'array', 'min:1'],
            'sections.*.title' => ['required', 'string', 'max:200'],
            'sections.*.purpose' => ['required', 'string', 'max:500'],
            'sections.*.body_blocks' => ['required', 'array', 'min:1'],
            'sections.*.body_blocks.*.type' => ['required', 'string', Rule::in(['paragraph', 'bullet', 'checklist', 'note'])],
            'sections.*.body_blocks.*.content' => ['required', 'string', 'max:1000'],
            'sections.*.emphasis' => ['required', 'string', Rule::in(['short', 'medium', 'long'])],
            'teacher_delivery_summary' => ['required', 'string', 'max:1000'],
            'fallback' => ['required', 'array'],
            'fallback.triggered' => ['required', 'boolean'],
            'fallback.reason_code' => ['nullable', 'string', 'max:100'],
            'fallback.action' => ['nullable', 'string', 'max:100'],
        ]);

        if ($validator->fails()) {
            throw new MediaGenerationContractException(
                'Content draft payload failed schema validation.',
                MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
                ['errors' => $validator->errors()->toArray()]
            );
        }

        return self::normalize($payload);
    }

    public static function fallbackFromInterpretation(
        array $interpretationPayload,
        string $resolvedOutputType,
        string $reasonCode = 'content_draft_fallback'
    ): array {
        $interpretation = MediaPromptInterpretationSchema::validate($interpretationPayload);
        $normalizedOutputType = MediaGeneration::normalizePreferredOutputType($resolvedOutputType);

        return self::validate([
            'schema_version' => self::VERSION,
            'title' => $interpretation['document_blueprint']['title'],
            'summary' => $interpretation['document_blueprint']['summary'],
            'learning_objectives' => $interpretation['learning_objectives'],
            'sections' => array_map(
                static fn (array $section): array => [
                    'title' => $section['title'],
                    'purpose' => $section['purpose'],
                    'body_blocks' => self::fallbackBodyBlocks($section, $normalizedOutputType),
                    'emphasis' => $section['estimated_length'],
                ],
                $interpretation['document_blueprint']['sections']
            ),
            'teacher_delivery_summary' => $interpretation['teacher_delivery_summary'],
            'fallback' => [
                'triggered' => true,
                'reason_code' => $reasonCode,
                'action' => 'use_interpretation_outline',
            ],
        ]);
    }

    private static function normalize(array $payload): array
    {
        return [
            'schema_version' => self::VERSION,
            'title' => trim($payload['title']),
            'summary' => trim($payload['summary']),
            'learning_objectives' => array_values(array_map(
                static fn (string $objective): string => trim($objective),
                $payload['learning_objectives']
            )),
            'sections' => array_map(
                static fn (array $section): array => [
                    'title' => trim($section['title']),
                    'purpose' => trim($section['purpose']),
                    'body_blocks' => array_map(
                        static fn (array $block): array => [
                            'type' => trim($block['type']),
                            'content' => trim($block['content']),
                        ],
                        $section['body_blocks']
                    ),
                    'emphasis' => trim($section['emphasis']),
                ],
                $payload['sections']
            ),
            'teacher_delivery_summary' => trim($payload['teacher_delivery_summary']),
            'fallback' => [
                'triggered' => (bool) $payload['fallback']['triggered'],
                'reason_code' => $payload['fallback']['reason_code'] !== null
                    ? trim((string) $payload['fallback']['reason_code'])
                    : null,
                'action' => $payload['fallback']['action'] !== null
                    ? trim((string) $payload['fallback']['action'])
                    : null,
            ],
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private static function applyDefaults(array $payload): array
    {
        $payload = array_merge([
            'schema_version' => self::VERSION,
            'learning_objectives' => [],
            'fallback' => [
                'triggered' => false,
                'reason_code' => null,
                'action' => null,
            ],
        ], $payload);

        if (isset($payload['fallback']) && is_array($payload['fallback'])) {
            $payload['fallback'] = array_merge([
                'triggered' => false,
                'reason_code' => null,
                'action' => null,
            ], $payload['fallback']);
        }

        return $payload;
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private static function assertNestedAllowedKeys(array $payload): void
    {
        if (! isset($payload['sections']) || ! is_array($payload['sections'])) {
            return;
        }

        foreach ($payload['sections'] as $index => $section) {
            if (! is_array($section)) {
                continue;
            }

            self::assertAllowedKeys($section, ['title', 'purpose', 'body_blocks', 'emphasis'], 'sections.' . $index);

            if (! isset($section['body_blocks']) || ! is_array($section['body_blocks'])) {
                continue;
            }

            foreach ($section['body_blocks'] as $blockIndex => $block) {
                if (is_array($block)) {
                    self::assertAllowedKeys($block, ['type', 'content'], 'sections.' . $index . '.body_blocks.' . $blockIndex);
                }
            }
        }

        if (isset($payload['fallback']) && is_array($payload['fallback'])) {
            self::assertAllowedKeys($payload['fallback'], ['triggered', 'reason_code', 'action'], 'fallback');
        }
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  string[]  $allowedKeys
     */
    private static function assertAllowedKeys(array $payload, array $allowedKeys, string $path): void
    {
        $unknownKeys = array_diff(array_keys($payload), $allowedKeys);

        if ($unknownKeys === []) {
            return;
        }

        throw new MediaGenerationContractException(
            'Content draft payload contains unsupported fields.',
            MediaGenerationErrorCode::LLM_CONTRACT_FAILED,
            [
                'path' => $path,
                'unknown_fields' => array_values($unknownKeys),
            ]
        );
    }

    private static function topLevelKeys(): array
    {
        return [
            'schema_version',
            'title',
            'summary',
            'learning_objectives',
            'sections',
            'teacher_delivery_summary',
            'fallback',
        ];
    }

    /**
     * @param  array<string, mixed>  $section
     * @return array<int, array<string, string>>
     */
    private static function fallbackBodyBlocks(array $section, string $resolvedOutputType): array
    {
        $purpose = trim((string) ($section['purpose'] ?? ''));
        $bullets = array_values(array_filter(
            is_array($section['bullets'] ?? null) ? $section['bullets'] : [],
            static fn (mixed $bullet): bool => is_string($bullet) && trim($bullet) !== ''
        ));
        $title = trim((string) ($section['title'] ?? ''));
        $content = $purpose;

        if ($bullets !== []) {
            $content .= ($content !== '' ? ' ' : '') . 'Pokok bahasan utama: ' . implode('; ', array_map(
                static fn (string $bullet): string => trim($bullet),
                $bullets
            )) . '.';
        }

        if ($content === '') {
            $content = $resolvedOutputType === 'pptx'
                ? 'Soroti inti materi secara ringkas dan siap dipresentasikan.'
                : 'Jelaskan inti materi ini secara runtut, jelas, dan siap dipakai di kelas.';
        }

        $blocks = [
            [
                'type' => 'paragraph',
                'content' => trim($title !== '' ? $title . ': ' . $content : $content),
            ],
        ];

        foreach ($bullets as $bullet) {
            $blocks[] = [
                'type' => 'bullet',
                'content' => trim($bullet),
            ];
        }

        return $blocks;
    }
}