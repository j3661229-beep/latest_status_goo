import 'package:flutter_test/flutter_test.dart';
import 'package:status_go/features/shorts/data/short_models.dart';
import 'package:status_go/features/shorts/presentation/short_format.dart';

Map<String, dynamic> newsJson({Map<String, dynamic>? over}) => {
      'id': 'n1',
      'kind': 'NEWS',
      'title': 'नई घोषणा',
      'category': 'INDIA',
      'videoUrl': 'https://cdn.test/v.mp4',
      'thumbnailUrl': 'https://cdn.test/t.jpg',
      'news': {
        'publisher': 'PIB',
        'originalHeadline': 'Original',
        'url': 'https://pib.gov.in/x',
        'publishedAt': '2026-10-15T08:00:00.000Z',
        'isDeveloping': true,
        'correctionStatus': 'CORRECTED',
      },
      ...?over,
    };

void main() {
  group('ShortItem.fromJson', () {
    test('parses news with attribution, dates and flags', () {
      final s = ShortItem.fromJson(newsJson());
      expect(s.kind, ShortKind.news);
      expect(s.news!.publisher, 'PIB');
      expect(s.news!.publishedAt, isNotNull);
      expect(s.news!.isDeveloping, isTrue);
      expect(s.news!.correctionStatus, 'CORRECTED');
      expect(s.primaryLink, 'https://pib.gov.in/x');
      expect(s.disclaimer, contains('AI'));
    });

    test('parses scheme detail lists and tolerates nulls / wrong types', () {
      final s = ShortItem.fromJson({
        'id': 's1',
        'kind': 'SCHEME',
        'title': 'पीएम किसान',
        'category': 'FARMER',
        'scheme': {
          'id': 'x',
          'nameHi': 'पीएम किसान',
          'officialName': 'PM Kisan',
          'applicationUrl': 'https://pmkisan.gov.in/apply',
          'benefits': ['लाभ 1', 5, null, ''],
          'eligibility': null,
          'documents': 'oops',
          'sourceUrls': ['https://pmkisan.gov.in', 'http://insecure.example', 'javascript:alert(1)'],
        },
        'keyFacts': ['तथ्य'],
      });
      expect(s.scheme!.benefits, ['लाभ 1']);
      expect(s.scheme!.eligibility, isEmpty);
      expect(s.scheme!.documents, isEmpty);
      expect(s.scheme!.sourceUrls, ['https://pmkisan.gov.in']); // non-https dropped
      expect(s.primaryLink, 'https://pmkisan.gov.in/apply');
      expect(s.keyFacts, ['तथ्य']);
    });

    test('only https URLs survive (media and links)', () {
      expect(safeHttpsUrl('https://a.in/x'), 'https://a.in/x');
      expect(safeHttpsUrl('http://a.in'), isNull);
      expect(safeHttpsUrl('javascript:alert(1)'), isNull);
      expect(safeHttpsUrl('file:///etc/passwd'), isNull);
      expect(safeHttpsUrl(null), isNull);
      final s = ShortItem.fromJson(newsJson(over: {'videoUrl': 'http://x/v.mp4'}));
      expect(s.videoUrl, isNull);
    });

    test('copyWith toggles saved only', () {
      final s = ShortItem.fromJson(newsJson());
      final t = s.copyWith(isSaved: true);
      expect(t.isSaved, isTrue);
      expect(t.title, s.title);
      expect(t.news!.publisher, 'PIB');
    });
  });

  group('formatting', () {
    test('Hindi date and time', () {
      final d = DateTime(2026, 10, 15, 17, 5);
      expect(formatDateHi(d), '15 अक्टूबर 2026');
      expect(formatDateTimeHi(d), '15 अक्टूबर 2026, 17:05');
    });
    test('relative labels', () {
      final now = DateTime(2026, 10, 15, 12);
      expect(relativeHi(now.subtract(const Duration(minutes: 5)), now: now), '5 मिनट पहले');
      expect(relativeHi(now.subtract(const Duration(hours: 3)), now: now), '3 घंटे पहले');
      expect(relativeHi(now.subtract(const Duration(days: 2)), now: now), '2 दिन पहले');
      expect(relativeHi(now.subtract(const Duration(days: 30)), now: now), contains('2026'));
    });
    test('stale news is flagged, fresh and unknown are not', () {
      final now = DateTime(2026, 10, 15, 12);
      expect(isStaleNews(now.subtract(const Duration(hours: 60)), now: now), isTrue);
      expect(isStaleNews(now.subtract(const Duration(hours: 5)), now: now), isFalse);
      expect(isStaleNews(null, now: now), isFalse);
    });
  });
}
