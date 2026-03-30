<?php

namespace App\Http\Requests;

class UpdateTopicRequest extends ApiFormRequest
{
    public function rules(): array
    {
        return [
            'title' => 'sometimes|string|max:255',
            'teacher_id' => 'sometimes|string|max:255',
            'thumbnail_url' => 'nullable|string|url|max:2048',
        ];
    }

    public function messages(): array
    {
        return [
            'title.max' => 'Judul topik maksimal 255 karakter.',
            'thumbnail_url.url' => 'URL thumbnail harus berupa URL yang valid.',
        ];
    }
}
