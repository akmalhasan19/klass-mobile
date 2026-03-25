<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MarketplaceTask extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'content_id',
        'status',
        'creator_id',
    ];

    /**
     * MarketplaceTask milik satu Content.
     */
    public function content(): BelongsTo
    {
        return $this->belongsTo(Content::class);
    }
}
