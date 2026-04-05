<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'avatar_url', 'role', 'security_question', 'security_answer'])]
#[Hidden(['password', 'remember_token', 'security_answer'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public const ROLE_ADMIN = 'admin';
    public const ROLE_USER = 'user'; // Legacy — treated as teacher for backward compat
    public const ROLE_TEACHER = 'teacher';
    public const ROLE_FREELANCER = 'freelancer';

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    /**
     * A user is considered a teacher if their role is explicitly 'teacher'
     * or the legacy 'user' role (backward compatibility).
     */
    public function isTeacher(): bool
    {
        return in_array($this->role, [self::ROLE_TEACHER, self::ROLE_USER], true);
    }

    public function isFreelancer(): bool
    {
        return $this->role === self::ROLE_FREELANCER;
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }
}
