class ClarificationGapSuggestion {
  final String value;
  final String label;

  ClarificationGapSuggestion({
    required this.value,
    required this.label,
  });

  factory ClarificationGapSuggestion.fromJson(Map<String, dynamic> json) {
    return ClarificationGapSuggestion(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
    };
  }
}

class ClarificationGap {
  final String fieldId;
  final String question;
  final String priority;
  final String inputType;
  final List<ClarificationGapSuggestion> suggestions;
  final String? detectedValue;

  ClarificationGap({
    required this.fieldId,
    required this.question,
    required this.priority,
    required this.inputType,
    this.suggestions = const [],
    this.detectedValue,
  });

  factory ClarificationGap.fromJson(Map<String, dynamic> json) {
    return ClarificationGap(
      fieldId: json['field_id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'recommended',
      inputType: json['input_type']?.toString() ?? 'text_input',
      suggestions: (json['suggestions'] as List?)
              ?.map((s) => ClarificationGapSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      detectedValue: json['detected_value']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field_id': fieldId,
      'question': question,
      'priority': priority,
      'input_type': inputType,
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
      'detected_value': detectedValue,
    };
  }

  bool get isRequired => priority == 'required';
  bool get isRecommended => priority == 'recommended';
}
