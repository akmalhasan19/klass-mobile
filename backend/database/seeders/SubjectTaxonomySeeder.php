<?php

namespace Database\Seeders;

use App\Models\SubSubject;
use App\Models\Subject;
use Illuminate\Database\Seeder;

class SubjectTaxonomySeeder extends Seeder
{
    public function run(): void
    {
        $taxonomy = [
            [
                'name' => 'History',
                'slug' => 'history',
                'description' => 'Historical learning topics and civic context.',
                'sub_subjects' => [
                    ['name' => 'Indonesian History', 'slug' => 'indonesian-history', 'description' => 'National history, independence, and modern eras.'],
                    ['name' => 'World History', 'slug' => 'world-history', 'description' => 'Global civilizations, wars, and political change.'],
                    ['name' => 'Civics', 'slug' => 'civics', 'description' => 'Government, citizenship, and public institutions.'],
                ],
            ],
            [
                'name' => 'Health',
                'slug' => 'health',
                'description' => 'Nutrition, wellness, and personal health topics.',
                'sub_subjects' => [
                    ['name' => 'Nutrition', 'slug' => 'nutrition', 'description' => 'Balanced diet, macro, and micronutrients.'],
                    ['name' => 'Healthy Lifestyle', 'slug' => 'healthy-lifestyle', 'description' => 'Daily habits, sleep, and preventive care.'],
                    ['name' => 'Public Health', 'slug' => 'public-health', 'description' => 'Population-level health and safety topics.'],
                ],
            ],
            [
                'name' => 'Mathematics',
                'slug' => 'mathematics',
                'description' => 'Core numeracy, problem-solving, and mathematical reasoning.',
                'sub_subjects' => [
                    ['name' => 'Algebra', 'slug' => 'algebra', 'description' => 'Equations, variables, and algebraic reasoning.'],
                    ['name' => 'Geometry', 'slug' => 'geometry', 'description' => 'Shapes, angles, and spatial thinking.'],
                    ['name' => 'Arithmetic', 'slug' => 'arithmetic', 'description' => 'Foundational operations and number fluency.'],
                ],
            ],
            [
                'name' => 'Science',
                'slug' => 'science',
                'description' => 'Scientific foundations across physics and related disciplines.',
                'sub_subjects' => [
                    ['name' => 'Physics', 'slug' => 'physics', 'description' => 'Motion, forces, and physical systems.'],
                    ['name' => 'Thermodynamics', 'slug' => 'thermodynamics', 'description' => 'Energy, heat, and entropy.'],
                    ['name' => 'Quantum Physics', 'slug' => 'quantum-physics', 'description' => 'Wave behavior and modern quantum concepts.'],
                ],
            ],
            [
                'name' => 'Arts and Humanities',
                'slug' => 'arts-and-humanities',
                'description' => 'Art, culture, and creative interpretation topics.',
                'sub_subjects' => [
                    ['name' => 'Art History', 'slug' => 'art-history', 'description' => 'Movements, artists, and visual culture.'],
                    ['name' => 'Visual Design', 'slug' => 'visual-design', 'description' => 'Composition, imagery, and visual communication.'],
                    ['name' => 'Creative Studies', 'slug' => 'creative-studies', 'description' => 'Creative process and artistic exploration.'],
                ],
            ],
        ];

        foreach ($taxonomy as $subjectIndex => $subjectData) {
            $subject = Subject::updateOrCreate(
                ['slug' => $subjectData['slug']],
                [
                    'name' => $subjectData['name'],
                    'description' => $subjectData['description'],
                    'display_order' => $subjectIndex + 1,
                    'is_active' => true,
                ],
            );

            foreach ($subjectData['sub_subjects'] as $subSubjectIndex => $subSubjectData) {
                SubSubject::updateOrCreate(
                    [
                        'subject_id' => $subject->id,
                        'slug' => $subSubjectData['slug'],
                    ],
                    [
                        'name' => $subSubjectData['name'],
                        'description' => $subSubjectData['description'],
                        'display_order' => $subSubjectIndex + 1,
                        'is_active' => true,
                    ],
                );
            }
        }
    }
}