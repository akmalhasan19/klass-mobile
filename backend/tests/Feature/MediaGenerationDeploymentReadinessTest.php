<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class MediaGenerationDeploymentReadinessTest extends TestCase
{
    public function test_smoke_python_service_command_reports_healthy_service(): void
    {
        config()->set('services.media_generation.python.base_url', 'https://python.example');
        config()->set('services.media_generation.python.health_path', '/v1/health');

        Http::preventStrayRequests();
        Http::fake([
            'https://python.example/v1/health' => Http::response([
                'schema_version' => 'media_generator_health.v1',
                'status' => 'ok',
                'service' => 'klass-media-generator',
                'version' => '0.1.0',
                'supported_formats' => ['docx', 'pdf', 'pptx'],
                'contracts' => [
                    'generation_spec' => 'media_generation_spec.v1',
                    'artifact_metadata' => 'media_generator_output_metadata.v1',
                    'response' => 'media_generator_response.v1',
                ],
                'auth' => [
                    'signature_algorithm' => 'hmac-sha256',
                    'configured' => true,
                    'rotation_enabled' => true,
                    'accepted_secret_count' => 2,
                    'max_request_age_seconds' => 300,
                ],
            ], 200),
        ]);

        $this->artisan('media-generation:smoke-python-service')
            ->expectsOutput('Python media generator service is reachable and healthy.')
            ->expectsOutput('Service: klass-media-generator')
            ->expectsOutput('Version: 0.1.0')
            ->expectsOutput('Health path: /v1/health')
            ->expectsOutput('Supported formats: docx, pdf, pptx')
            ->expectsOutput('Auth configured: yes')
            ->expectsOutput('Rotation enabled: yes')
            ->assertExitCode(0);

        Http::assertSentCount(1);
    }

    public function test_smoke_python_service_command_fails_when_auth_is_not_configured(): void
    {
        config()->set('services.media_generation.python.base_url', 'https://python.example');
        config()->set('services.media_generation.python.health_path', '/v1/health');

        Http::preventStrayRequests();
        Http::fake([
            'https://python.example/v1/health' => Http::response([
                'schema_version' => 'media_generator_health.v1',
                'status' => 'ok',
                'service' => 'klass-media-generator',
                'version' => '0.1.0',
                'supported_formats' => ['docx', 'pdf', 'pptx'],
                'contracts' => [
                    'generation_spec' => 'media_generation_spec.v1',
                    'artifact_metadata' => 'media_generator_output_metadata.v1',
                    'response' => 'media_generator_response.v1',
                ],
                'auth' => [
                    'signature_algorithm' => 'hmac-sha256',
                    'configured' => false,
                    'rotation_enabled' => false,
                    'accepted_secret_count' => 0,
                    'max_request_age_seconds' => 300,
                ],
            ], 200),
        ]);

        $this->artisan('media-generation:smoke-python-service')
            ->expectsOutput('Python media generator health payload reports auth.configured=false.')
            ->expectsOutput('health_path: /v1/health')
            ->assertExitCode(1);

        Http::assertSentCount(1);
    }
}