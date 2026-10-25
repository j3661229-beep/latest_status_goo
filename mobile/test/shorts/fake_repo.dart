import 'package:dio/dio.dart';
import 'package:status_go/features/shorts/data/short_models.dart';
import 'package:status_go/features/shorts/data/shorts_repository.dart';

/// Closure-driven repository fake that also records interactions.
class FakeRepo extends ShortsRepository {
  FakeRepo({this.onList, this.onSave, this.onDetail, this.onReport}) : super(Dio());
  Future<ShortPage> Function(ShortsFeed feed, String? category, int page)? onList;
  Future<void> Function(String id, bool saved)? onSave;
  Future<ShortDetail> Function(String id)? onDetail;
  Future<void> Function(String id, String reason, String? note)? onReport;
  final events = <String>[];
  final listCalls = <String>[];

  @override
  Future<ShortPage> list({required ShortsFeed feed, String? category, int page = 1}) {
    listCalls.add('${feed.name}|${category ?? '-'}|$page');
    return onList!(feed, category, page);
  }

  @override
  Future<ShortDetail> detail(String id) => onDetail!(id);
  @override
  Future<void> setSaved(String id, bool saved) => onSave!(id, saved);
  @override
  Future<void> report(String id, String reason, {String? note}) => onReport!(id, reason, note);
  @override
  Future<void> event(String id, String type) async => events.add('$id:$type');
}

Map<String, dynamic> newsJson(String id, {String? publishedAt, Map<String, dynamic>? news, String? video, String? summary, String? format, double? duration}) => {
      'id': id,
      'kind': 'NEWS',
      'title': 'ख़बर $id',
      'category': 'INDIA',
      if (summary != null) 'summary': summary,
      if (format != null) 'format': format,
      if (video != null && duration != null) 'durationSec': duration,
      if (video != null) 'videoUrl': video,
      'disclaimer': 'AI-सहायता प्राप्त सारांश। यह सरकारी घोषणा नहीं है।',
      'news': {
        'publisher': 'PIB',
        'originalHeadline': 'Headline $id',
        'url': 'https://pib.gov.in/$id',
        'publishedAt': publishedAt ?? DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
        ...?news,
      },
    };

Map<String, dynamic> schemeJson(String id, {Map<String, dynamic>? scheme, bool detail = true}) => {
      'id': id,
      'kind': 'SCHEME',
      'title': 'योजना $id',
      'category': 'FARMER',
      'attribution': 'स्रोत: pmkisan.gov.in',
      'narration': 'यह वीडियो का पूरा पाठ है।',
      'keyFacts': ['मुख्य तथ्य एक'],
      'scheme': {
        'id': 'sc$id',
        'nameHi': 'पीएम किसान',
        'officialName': 'PM Kisan',
        'department': 'कृषि विभाग',
        'applicationUrl': 'https://pmkisan.gov.in/apply',
        'lastVerifiedAt': '2026-10-01T00:00:00.000Z',
        if (detail) ...{
          'benefits': ['सालाना सहायता'],
          'eligibility': ['किसान परिवार'],
          'documents': ['आधार', 'बैंक खाता'],
          'applicationSteps': ['पोर्टल खोलें', 'फ़ॉर्म भरें'],
          'sourceUrls': ['https://pmkisan.gov.in/about'],
        },
        ...?scheme,
      },
    };

ShortItem mkNews(String id, {String? publishedAt, Map<String, dynamic>? news, String? video, String? summary, String? format, double? duration}) =>
    ShortItem.fromJson(newsJson(id, publishedAt: publishedAt, news: news, video: video, summary: summary, format: format, duration: duration));
ShortItem mkScheme(String id, {Map<String, dynamic>? scheme}) => ShortItem.fromJson(schemeJson(id, scheme: scheme));
