<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Topic extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'title',
        'teacher_id',
        'thumbnail_url',
        'is_published',
        'order',
    ];

    /**
     * Satu Topic memiliki banyak Content.
     */
    public function contents(): HasMany
    {
        return $this->hasMany(Content::class);
    }
}
