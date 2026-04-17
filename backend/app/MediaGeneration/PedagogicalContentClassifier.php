<?php

namespace App\MediaGeneration;

class PedagogicalContentClassifier
{
    private array $kurikulumStructure;

    public function __construct()
    {
        $path = config('content_integrity.kurikulum_merdeka_reference');
        if ($path && file_exists($path)) {
            $this->kurikulumStructure = json_decode(file_get_contents($path), true) ?? [];
        } else {
            $this->kurikulumStructure = [];
        }
    }

    public function classify(MediaGenerationSpecContract $spec): array
    {
        return [
            'content_types' => $this->detectContentTypes($spec),
            'pedagogical_alignment_score' => $this->calculateStructuralAlignment($spec),
            'tone_classification' => $this->classifyTone($spec),
            'expected_structure_match' => $this->calculateStructuralAlignment($spec),
        ];
    }

    private function detectContentTypes(MediaGenerationSpecContract $spec): array
    {
        $types = [];
        
        $content = strtolower(json_encode($spec->body_blocks ?? []));
        
        if (preg_match('/\b(definisi|pengertian|adalah|merupakan|merujuk pada)\b/i', $content)) {
            $types['definition'] = true;
        }
        
        if (preg_match('/\b(contoh|misalnya|sebagai contoh|contoh soal|penyelesaian)\b/i', $content)) {
            $types['worked_example'] = true;
        }
        
        if (preg_match('/\b(latihan|kerjakan|jawablah|tugas|praktik|hitunglah)\b/i', $content)) {
            $types['exercise'] = true;
        }
        
        if (preg_match('/\b(evaluasi|penilaian|uji kompetensi|ulangan)\b/i', $content)) {
            $types['assessment'] = true;
        }

        return $types;
    }

    private function classifyTone(MediaGenerationSpecContract $spec): string
    {
        $content = strtolower(json_encode($spec->body_blocks ?? []));
        
        // Procedural indicators (teacher-facing)
        $proceduralCount = preg_match_all('/\b(pastikan|guru harus|instruksikan|beri waktu|bagikan|langkah-langkah mengajarkan)\b/i', $content);
        
        // Conversational indicators
        $conversationalCount = preg_match_all('/\b(mari kita|ayo|bagaimana kalau|coba bayangkan|hai|halo|kamu tahu tidak)\b/i', $content);
        
        // Academic indicators (formal, objective)
        $academicCount = preg_match_all('/\b(berdasarkan|diketahui|hipotesis|variabel|metode|analisis|kesimpulan)\b/i', $content);
        
        if ($proceduralCount > max($conversationalCount, $academicCount)) {
            return 'procedural';
        }
        
        if ($conversationalCount > $academicCount) {
            return 'conversational';
        }
        
        return 'academic';
    }

    private function calculateStructuralAlignment(MediaGenerationSpecContract $spec): float
    {
        if (empty($this->kurikulumStructure)) {
            return 1.0;
        }
        
        $score = 1.0;
        $types = $this->detectContentTypes($spec);
        $requiredCount = 0;
        $presentCount = 0;
        
        $expected = ['definition', 'worked_example', 'exercise'];
        foreach ($expected as $e) {
            $requiredCount++;
            if (isset($types[$e]) && $types[$e]) {
                $presentCount++;
            }
        }
        
        if ($requiredCount > 0) {
            $score = $presentCount / $requiredCount;
        }
        
        return (float) round($score, 2);
    }
}
