<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Topic extends Model
{
    use HasFactory, HasUuids;

    public const OWNERSHIP_STATUS_NORMALIZED = 'normalized';
    public const OWNERSHIP_STATUS_LEGACY_UNRESOLVED = 'legacy_unresolved';

    protected $fillable = [
        'title',
        'teacher_id',
        'sub_subject_id',
        'owner_user_id',
        'ownership_status',
        'thumbnail_url',
        'is_published',
        'order',
    ];

    protected function casts(): array
    {
        return [
            'sub_subject_id' => 'integer',
            'owner_user_id' => 'integer',
            'is_published' => 'boolean',
            'order' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (Topic $topic): void {
            $topic->syncOwnershipFromLegacyIdentifier();
        });
    }

    /**
     * Satu Topic memiliki banyak Content.
     */
    public function contents(): HasMany
    {
        return $this->hasMany(Content::class);
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function subSubject(): BelongsTo
    {
        return $this->belongsTo(SubSubject::class);
    }

    public function scopeNormalizedOwnership(Builder $query): Builder
    {
        return $query
            ->whereNotNull('owner_user_id')
            ->where('ownership_status', self::OWNERSHIP_STATUS_NORMALIZED);
    }

    public function scopeEligibleForPersonalization(Builder $query): Builder
    {
        return $query->normalizedOwnership();
    }

    public function syncOwnershipFromLegacyIdentifier(): void
    {
        if (! $this->isDirty('owner_user_id')) {
            $this->owner_user_id = $this->resolveOwnerUserIdFromTeacherIdentifier();
        }

        $this->ownership_status = $this->owner_user_id !== null
            ? self::OWNERSHIP_STATUS_NORMALIZED
            : self::OWNERSHIP_STATUS_LEGACY_UNRESOLVED;
    }

    public function hasNormalizedOwnership(): bool
    {
        return $this->owner_user_id !== null
            && $this->ownership_status === self::OWNERSHIP_STATUS_NORMALIZED;
    }

    public function resolveSubject(): ?Subject
    {
        return $this->subSubject?->subject;
    }

    protected function resolveOwnerUserIdFromTeacherIdentifier(): ?int
    {
        $teacherIdentifier = trim((string) $this->teacher_id);

        if ($teacherIdentifier === '') {
            return null;
        }

        if (preg_match('/^\d+$/', $teacherIdentifier) === 1) {
            return User::query()->whereKey((int) $teacherIdentifier)->value('id');
        }

        if (filter_var($teacherIdentifier, FILTER_VALIDATE_EMAIL)) {
            return User::query()
                ->whereRaw('LOWER(email) = ?', [strtolower($teacherIdentifier)])
                ->value('id');
        }

        return null;
    }
}
