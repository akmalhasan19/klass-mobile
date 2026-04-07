import 'package:flutter_test/flutter_test.dart';
import 'package:klass_app/services/api_service.dart';

void main() {
  test('normalizeTopicCollection keeps legacy and taxonomy-aware topics compatible for workspace consumers', () {
    final normalized = ApiService.normalizeTopicCollection([
      {
        'id': 'legacy-topic',
        'title': 'Legacy Topic',
        'thumbnail_url': 'https://example.com/legacy-topic.jpg',
      },
      {
        'id': 'taxonomy-topic',
        'title': 'Taxonomy Topic',
        'thumbnail_url': 'https://example.com/taxonomy-topic.jpg',
        'sub_subject_id': 10,
        'subject_id': 5,
        'taxonomy': {
          'subject': {
            'id': 5,
            'slug': 'mathematics',
          },
          'sub_subject': {
            'id': 10,
            'slug': 'algebra',
          },
        },
        'owner_user_id': 42,
        'ownership_status': 'normalized',
      },
    ]);

    expect(normalized, hasLength(2));

    expect(normalized[0]['media_url'], 'https://example.com/legacy-topic.jpg');
    expect(normalized[0]['image'], 'https://example.com/legacy-topic.jpg');
    expect(normalized[0]['imagePath'], 'https://example.com/legacy-topic.jpg');

    expect(normalized[1]['media_url'], 'https://example.com/taxonomy-topic.jpg');
    expect(normalized[1]['taxonomy']['sub_subject']['slug'], 'algebra');
    expect(normalized[1]['owner_user_id'], 42);
    expect(normalized[1]['ownership_status'], 'normalized');
  });
}