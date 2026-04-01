<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\FileUploadService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * UserSeeder
 *
 * Membuat user awal yang merepresentasikan:
 * - 1 akun demo teacher (Dr. Sarah Jenkins — profil utama app)
 * - 4 freelancer/tutor (Agus, Ani, Budi, Susi — dari home screen)
 * - 2 teacher (Elena Rodriguez, Marcus Chen — dari search screen)
 */
class UserSeeder extends Seeder
{
    public function run(): void
    {
        $uploadService = app(FileUploadService::class);

        $users = [
            [
                'name' => 'Klass Admin',
                'email' => 'admin@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => null,
                'role' => User::ROLE_ADMIN,
            ],

            // Demo teacher — profil utama yang ditampilkan di profile_screen.dart
            [
                'name' => 'Dr. Sarah Jenkins',
                'email' => 'sarah.jenkins@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => $uploadService->generatePublicUrl('avatars/ani.png'),
                'role' => User::ROLE_USER,
            ],

            // Freelancers dari home_screen.dart
            [
                'name' => 'Agus S',
                'email' => 'agus@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => $uploadService->generatePublicUrl('avatars/agus.png'),
                'role' => User::ROLE_USER,
            ],
            [
                'name' => 'Ani A',
                'email' => 'ani@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => $uploadService->generatePublicUrl('avatars/ani.png'),
                'role' => User::ROLE_USER,
            ],
            [
                'name' => 'Budi O',
                'email' => 'budi@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => $uploadService->generatePublicUrl('avatars/budi.png'),
                'role' => User::ROLE_USER,
            ],
            [
                'name' => 'Susi',
                'email' => 'susi@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => $uploadService->generatePublicUrl('avatars/susi.png'),
                'role' => User::ROLE_USER,
            ],

            // Teachers dari search_screen.dart
            [
                'name' => 'Elena Rodriguez',
                'email' => 'elena@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => null,
                'role' => User::ROLE_USER,
            ],
            [
                'name' => 'Marcus Chen',
                'email' => 'marcus@klass.id',
                'password' => Hash::make('password'),
                'avatar_url' => null,
                'role' => User::ROLE_USER,
            ],
        ];

        foreach ($users as $userData) {
            User::updateOrCreate(
                ['email' => $userData['email']],
                $userData,
            );
        }
    }
}
