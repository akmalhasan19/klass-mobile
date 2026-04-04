<?php

namespace App\Services;

use Exception;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use NcJoes\OfficeConverter\OfficeConverter;
use Spatie\PdfToImage\Pdf;
use Illuminate\Support\Str;

class DocumentPreviewService
{
    /**
     * Attempts to generate an image preview of the first page of a document.
     * Supports: PDF, PPT, PPTX, DOC, DOCX.
     *
     * Note: Requires LibreOffice installed on the server for Office docs,
     * and ImageMagick/Ghostscript for PDFs.
     *
     * @param UploadedFile $file
     * @return UploadedFile|null The generated image as an UploadedFile, or null on failure.
     */
    public function generatePreview(UploadedFile $file): ?UploadedFile
    {
        $extension = strtolower($file->getClientOriginalExtension());
        $inputPath = $file->getRealPath();
        
        try {
            if (in_array($extension, ['pdf'])) {
                return $this->convertPdfToImage($inputPath);
            }
            
            if (in_array($extension, ['ppt', 'pptx', 'doc', 'docx'])) {
                $pdfPath = $this->convertOfficeToPdf($inputPath);
                if ($pdfPath) {
                    $preview = $this->convertPdfToImage($pdfPath);
                    @unlink($pdfPath); // Cleanup temporary PDF
                    return $preview;
                }
            }
        } catch (Exception $e) {
            Log::warning("Failed to generate document preview for {$file->getClientOriginalName()}: " . $e->getMessage());
        }

        return null;
    }

    /**
     * Converts the first page of a PDF to an image.
     */
    protected function convertPdfToImage(string $pdfPath): ?UploadedFile
    {
        try {
            $pdf = new Pdf($pdfPath);
            $outputPath = sys_get_temp_dir() . '/' . Str::random(10) . '_preview.jpg';
            
            // Output first page to JPG
            $pdf->setPage(1)->saveImage($outputPath);
            
            if (file_exists($outputPath)) {
                return new UploadedFile(
                    $outputPath,
                    'preview.jpg',
                    'image/jpeg',
                    null,
                    true
                );
            }
        } catch (Exception $e) {
            throw new Exception("PDF conversion error: " . $e->getMessage());
        }
        
        return null;
    }

    /**
     * Converts an Office document to PDF using LibreOffice.
     */
    protected function convertOfficeToPdf(string $inputPath): ?string
    {
        try {
            $tempDir = sys_get_temp_dir() . '/' . Str::random(10);
            if (!is_dir($tempDir)) {
                mkdir($tempDir, 0777, true);
            }

            $converter = new OfficeConverter($inputPath, $tempDir);
            $outputPdf = $converter->convertTo('preview.pdf');
            
            return $tempDir . '/' . $outputPdf;
        } catch (Exception $e) {
            throw new Exception("Office to PDF conversion error: " . $e->getMessage());
        }
    }
}
