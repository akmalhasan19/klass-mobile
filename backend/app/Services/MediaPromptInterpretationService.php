<?php

namespace App\Services;

use App\MediaGeneration\MediaGenerationContractException;
use App\MediaGeneration\MediaGenerationServiceException;
use App\MediaGeneration\MediaPromptInterpretationSchema;
use App\Models\MediaGeneration;
use Exception;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Factory as HttpFactory;
use Illuminate\Http\Client\Response;
use JsonException;

class MediaPromptInterpretationService
{
    public const AUDIT_SCHEMA_VERSION = 'media_prompt_interpretation_audit.v1';

    public function __construct(protected ?HttpFactory $http = null)
    {
    }

    public function interpret(MediaGeneration $generation): MediaGeneration
    {
        $response = $this->sendInterpretationRequest($generation);

        if ($response->failed()) {
            $this->throwFailedInterpretationRequest($response);
        }

        $rawContent = $this->extractRawInterpretationContent($response);
        $normalization = $this->normalizeInterpretationPayload($generation, $rawContent);

        $generation->forceFill([
            'llm_provider' => $this->provider(),
            'llm_model' => $this->model(),
            'interpretation_payload' => $normalization['payload'],
            'interpretation_audit_payload' => $this->buildAuditPayload(
                generation: $generation,
                response: $response,
                rawContent: $rawContent,
                normalizedPayload: $normalization['payload'],
                usedFallback: $normalization['used_fallback'],
                fallbackError: $normalization['fallback_error'],
            ),
            'error_code' => null,
            'error_message' => null,
        ])->save();

        return $generation->fresh(['subject', 'subSubject.subject']);
    }

    protected function sendInterpretationRequest(MediaGeneration $generation): Response
    {
        $baseUrl = trim((string) config('services.media_generation.interpreter.base_url'));

        if ($baseUrl === '') {
            throw MediaGenerationServiceException::llmContractFailed(
                'Media interpretation service is not configured.',
                ['config' => 'services.media_generation.interpreter.base_url']
            );
        }

        $request = $this->http()
            ->baseUrl(rtrim($baseUrl, '/'))
            ->acceptJson()
            ->asJson()
            ->timeout($this->timeoutSeconds())
            ->connectTimeout($this->connectTimeoutSeconds())
            ->retry(
                $this->retryAttempts(),
                $this->retrySleepMilliseconds(),
                function (Exception $exception): bool {
                    return $exception instanceof ConnectionException;
                },
                false,
            );

        $apiKey = trim((string) config('services.media_generation.interpreter.api_key'));

        if ($apiKey !== '') {
            $request = $request->withToken($apiKey);
        }

        try {
            return $request->post($this->path(), $this->buildRequestPayload($generation));
        } catch (ConnectionException $exception) {
            throw MediaGenerationServiceException::llmContractFailed(
                'Could not reach the media interpretation service.',
                ['exception' => $exception->getMessage()]
            );
        }
    }

    protected function buildRequestPayload(MediaGeneration $generation): array
    {
        $generation->loadMissing(['subject', 'subSubject.subject']);

        $subject = $generation->subSubject?->subject ?? $generation->subject;
        $subSubject = $generation->subSubject;

        return [
            'request_type' => 'media_prompt_interpretation',
            'generation_id' => $generation->id,
            'model' => $this->model(),
            'instruction' => MediaPromptInterpretationSchema::llmInstruction(),
            'input' => [
                'teacher_prompt' => $generation->raw_prompt,
                'preferred_output_type' => $generation->preferred_output_type,
                'subject_context' => $subject ? [
                    'id' => $subject->id,
                    'name' => $subject->name,
                    'slug' => $subject->slug,
                ] : null,
                'sub_subject_context' => $subSubject ? [
                    'id' => $subSubject->id,
                    'name' => $subSubject->name,
                    'slug' => $subSubject->slug,
                ] : null,
            ],
        ];
    }

    /**
     * @return array{payload: array<string, mixed>, used_fallback: bool, fallback_error: array<string, mixed>|null}
     */
    protected function normalizeInterpretationPayload(MediaGeneration $generation, string $rawContent): array
    {
        try {
            return [
                'payload' => MediaPromptInterpretationSchema::decodeAndValidate($rawContent),
                'used_fallback' => false,
                'fallback_error' => null,
            ];
        } catch (MediaGenerationContractException $exception) {
            return [
                'payload' => MediaPromptInterpretationSchema::fallback(
                    teacherPrompt: (string) $generation->raw_prompt,
                    reasonCode: $exception->errorCode(),
                    preferredOutputType: $generation->preferred_output_type,
                ),
                'used_fallback' => true,
                'fallback_error' => [
                    'message' => $exception->getMessage(),
                    'error_code' => $exception->errorCode(),
                    'context' => $exception->context(),
                ],
            ];
        }
    }

    protected function buildAuditPayload(
        MediaGeneration $generation,
        Response $response,
        string $rawContent,
        array $normalizedPayload,
        bool $usedFallback,
        ?array $fallbackError,
    ): array {
        return [
            'schema_version' => self::AUDIT_SCHEMA_VERSION,
            'provider' => [
                'name' => $this->provider(),
                'model' => $this->model(),
            ],
            'request' => $this->buildRequestPayload($generation),
            'response' => [
                'http_status' => $response->status(),
                'raw_payload' => $this->decodedResponsePayload($response),
                'raw_content' => $rawContent,
                'normalized_payload' => $normalizedPayload,
                'used_fallback' => $usedFallback,
                'fallback_error' => $fallbackError,
            ],
            'recorded_at' => now()->toISOString(),
        ];
    }

    protected function extractRawInterpretationContent(Response $response): string
    {
        $decodedPayload = $this->decodedResponsePayload($response);

        if (is_array($decodedPayload)) {
            foreach ([
                'output_text',
                'data.output_text',
                'data.response_text',
                'data.content',
                'response',
                'message.content',
                'choices.0.message.content',
                'choices.0.text',
                'content',
            ] as $path) {
                $content = $this->stringifyContent(data_get($decodedPayload, $path));

                if ($content !== null) {
                    return $content;
                }
            }

            if ($this->looksLikeInterpretationPayload($decodedPayload)) {
                return $this->encodeJson($decodedPayload);
            }
        }

        return trim($response->body());
    }

    protected function stringifyContent(mixed $value): ?string
    {
        if (is_string($value)) {
            $trimmed = trim($value);

            return $trimmed !== '' ? $trimmed : null;
        }

        if (! is_array($value)) {
            return null;
        }

        if ($this->looksLikeInterpretationPayload($value)) {
            return $this->encodeJson($value);
        }

        $segments = [];

        foreach ($value as $item) {
            if (is_array($item)) {
                $segment = $this->stringifyContent($item['text'] ?? $item['content'] ?? null);
            } else {
                $segment = $this->stringifyContent($item);
            }

            if ($segment !== null) {
                $segments[] = $segment;
            }
        }

        if ($segments === []) {
            return null;
        }

        return trim(implode("\n", $segments));
    }

    protected function looksLikeInterpretationPayload(array $payload): bool
    {
        return array_key_exists('schema_version', $payload)
            || (array_key_exists('teacher_prompt', $payload) && array_key_exists('document_blueprint', $payload));
    }

    protected function throwFailedInterpretationRequest(Response $response): never
    {
        throw MediaGenerationServiceException::llmContractFailed(
            'Media interpretation service rejected the request.',
            [
                'http_status' => $response->status(),
                'response_body' => trim($response->body()),
            ]
        );
    }

    protected function decodedResponsePayload(Response $response): mixed
    {
        $json = $response->json();

        return $json ?? trim($response->body());
    }

    protected function encodeJson(array $payload): string
    {
        try {
            return json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } catch (JsonException) {
            return '{}';
        }
    }

    protected function http(): HttpFactory
    {
        return $this->http ?? app(HttpFactory::class);
    }

    protected function provider(): string
    {
        return trim((string) config('services.media_generation.interpreter.provider', 'llm-gateway'));
    }

    protected function model(): string
    {
        return trim((string) config('services.media_generation.interpreter.model', 'gpt-5.4'));
    }

    protected function path(): string
    {
        return ltrim((string) config('services.media_generation.interpreter.path', '/v1/interpret'), '/');
    }

    protected function timeoutSeconds(): float
    {
        return (float) config('services.media_generation.interpreter.timeout_seconds', 30);
    }

    protected function connectTimeoutSeconds(): float
    {
        return (float) config('services.media_generation.interpreter.connect_timeout_seconds', 10);
    }

    protected function retryAttempts(): int
    {
        return (int) config('services.media_generation.interpreter.retry_attempts', 2);
    }

    protected function retrySleepMilliseconds(): int
    {
        return (int) config('services.media_generation.interpreter.retry_sleep_milliseconds', 250);
    }
}