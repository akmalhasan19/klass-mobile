<?php

namespace App\Http\Requests;

class StoreTopicRequest extends ApiFormRequest
{
    public function rules(): array
    {
        return [
            'title' => 'required|string|max:255',
            'teacher_id' => 'required|string|max:255',
            'thumbnail_url' => 'nullable|string|url|max:2048',
        ];
    }

    public function messages(): array
    {
        return [
            'title.required' => 'Judul topik wajib diisi.',
            'title.max' => 'Judul topik maksimal 255 karakter.',
            'teacher_id.required' => 'ID pengajar wajib diisi.',
            'thumbnail_url.url' => 'URL thumbnail harus berupa URL yang valid.',
        ];
    }
}
