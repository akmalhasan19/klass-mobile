import 'clarification_gap.dart';

class ClarificationDetected {
  final String? outputType;
  final String? subject;
  final int? subjectId;
  final String? audience;
  final String? topic;
  final String contentType;
  final double confidence;

  ClarificationDetected({
    this.outputType,
    this.subject,
    this.subjectId,
    this.audience,
    this.topic,
    required this.contentType,
    required this.confidence,
  });

  factory ClarificationDetected.fromJson(Map<String, dynamic> json) {
    return ClarificationDetected(
      outputType: json['output_type']?.toString(),
      subject: json['subject']?.toString(),
      subjectId: json['subject_id'] as int?,
      audience: json['audience']?.toString(),
      topic: json['topic']?.toString(),
      contentType: json['content_type']?.toString() ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'output_type': outputType,
      'subject': subject,
      'subject_id': subjectId,
      'audience': audience,
      'topic': topic,
      'content_type': contentType,
      'confidence': confidence,
    };
  }
}

class ClarificationResponse {
  final String generationId;
  final ClarificationDetected detected;
  final List<ClarificationGap> gaps;
  final String suggestedPrompt;
  final bool isReady;
  final int totalRequiredGaps;
  final int totalRecommendedGaps;

  ClarificationResponse({
    required this.generationId,
    required this.detected,
    required this.gaps,
    required this.suggestedPrompt,
    required this.isReady,
    required this.totalRequiredGaps,
    required this.totalRecommendedGaps,
  });

  factory ClarificationResponse.fromJson(Map<String, dynamic> json) {
    return ClarificationResponse(
      generationId: json['generation_id']?.toString() ?? '',
      detected: ClarificationDetected.fromJson(
        json['detected'] as Map<String, dynamic>? ?? {},
      ),
      gaps: (json['gaps'] as List?)
              ?.map((g) => ClarificationGap.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedPrompt: json['suggested_prompt']?.toString() ?? '',
      isReady: json['is_ready'] == true,
      totalRequiredGaps: json['total_required_gaps'] ?? 0,
      totalRecommendedGaps: json['total_recommended_gaps'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generation_id': generationId,
      'detected': detected.toJson(),
      'gaps': gaps.map((g) => g.toJson()).toList(),
      'suggested_prompt': suggestedPrompt,
      'is_ready': isReady,
      'total_required_gaps': totalRequiredGaps,
      'total_recommended_gaps': totalRecommendedGaps,
    };
  }

  int get totalGaps => gaps.length;
}
