// lib/features/shorts/data/short_models.dart
//
// Models for Daily News and Yojana & Scholarship shorts. Hand-written parsing
// (no codegen) that tolerates missing/null fields — a malformed item must never
// crash the feed.

enum ShortKind { news, scheme }

/// How the admin chose to present an item. `null` on a [ShortItem] means an older API
/// record without the field (treated as "show a video if the server sent one").
enum ContentFormat { cardOnly, cardWithVideo }

ContentFormat? _format(dynamic v) => switch (v) {
      'CARD_ONLY' => ContentFormat.cardOnly,
      'CARD_WITH_VIDEO' => ContentFormat.cardWithVideo,
      _ => null,
    };

extension ShortKindX on ShortKind {
  String get apiValue => this == ShortKind.news ? 'NEWS' : 'SCHEME';
  String get label => this == ShortKind.news ? 'दैनिक समाचार' : 'योजना और छात्रवृत्ति';
}

List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().where((s) => s.trim().isNotEmpty).toList() : const [];

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Only https links are ever opened from content (defence against bad data).
String? safeHttpsUrl(dynamic v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v.trim());
  return (u != null && u.scheme == 'https' && u.host.isNotEmpty) ? u.toString() : null;
}

class NewsInfo {
  final String publisher;
  final String? originalHeadline;
  final String? url;
  final DateTime? publishedAt;
  final DateTime? lastVerifiedAt;
  final bool isDeveloping;
  final String correctionStatus; // NONE | CORRECTED | WITHDRAWN

  const NewsInfo({
    required this.publisher,
    this.originalHeadline,
    this.url,
    this.publishedAt,
    this.lastVerifiedAt,
    this.isDeveloping = false,
    this.correctionStatus = 'NONE',
  });

  factory NewsInfo.fromJson(Map<String, dynamic> j) => NewsInfo(
        publisher: (j['publisher'] as String?) ?? '',
        originalHeadline: j['originalHeadline'] as String?,
        url: safeHttpsUrl(j['url']),
        publishedAt: _date(j['publishedAt']),
        lastVerifiedAt: _date(j['lastVerifiedAt']),
        isDeveloping: j['isDeveloping'] == true,
        correctionStatus: (j['correctionStatus'] as String?) ?? 'NONE',
      );
}

class SchemeInfo {
  final String id;
  final String nameHi;
  final String officialName;
  final String? department;
  final String scope;
  final String? stateCode;
  final String? applicationUrl;
  final String? youtubeUrl;
  final String? youtubeId;
  final DateTime? lastVerifiedAt;
  // Detail-only
  final List<String> benefits;
  final List<String> eligibility;
  final List<String> documents;
  final List<String> applicationSteps;
  final String? applicationMode;
  final List<String> sourceUrls;
  final DateTime? sourceUpdatedAt;

  const SchemeInfo({
    required this.id,
    required this.nameHi,
    required this.officialName,
    this.department,
    this.scope = 'CENTRAL',
    this.stateCode,
    this.applicationUrl,
    this.youtubeUrl,
    this.youtubeId,
    this.lastVerifiedAt,
    this.benefits = const [],
    this.eligibility = const [],
    this.documents = const [],
    this.applicationSteps = const [],
    this.applicationMode,
    this.sourceUrls = const [],
    this.sourceUpdatedAt,
  });

  factory SchemeInfo.fromJson(Map<String, dynamic> j) => SchemeInfo(
        id: (j['id'] as String?) ?? '',
        nameHi: (j['nameHi'] as String?) ?? '',
        officialName: (j['officialName'] as String?) ?? '',
        department: j['department'] as String?,
        scope: (j['scope'] as String?) ?? 'CENTRAL',
        stateCode: j['stateCode'] as String?,
        applicationUrl: safeHttpsUrl(j['applicationUrl']),
        youtubeUrl: safeHttpsUrl(j['youtubeUrl']),
        youtubeId: j['youtubeId'] as String?,
        lastVerifiedAt: _date(j['lastVerifiedAt']),
        benefits: _strings(j['benefits']),
        eligibility: _strings(j['eligibility']),
        documents: _strings(j['documents']),
        applicationSteps: _strings(j['applicationSteps']),
        applicationMode: j['applicationMode'] as String?,
        sourceUrls: _strings(j['sourceUrls']).map(safeHttpsUrl).whereType<String>().toList(),
        sourceUpdatedAt: _date(j['sourceUpdatedAt']),
      );
}

class ShortItem {
  final String id;
  final ShortKind kind;
  final String subKind; // 'TOP' | 'REGIONAL'
  final String? region;
  final String title;
  final String? hook;
  final String? summary; // card text (~60 words)
  final String category;
  final ContentFormat? format;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? youtubeUrl;
  final String? youtubeId;
  final bool hasYoutube;
  final double? durationSec;
  final String? attribution;
  final DateTime? publishedAt;
  final String? correctionNote;
  final String disclaimer;
  final bool isSaved;
  final NewsInfo? news;
  final SchemeInfo? scheme;
  // Detail-only
  final String? description;
  final String? narration;
  final List<String> keyFacts;
  final List<String> warnings;

  const ShortItem({
    required this.id,
    required this.kind,
    this.subKind = 'TOP',
    this.region,
    required this.title,
    required this.category,
    this.format,
    this.hook,
    this.summary,
    this.videoUrl,
    this.thumbnailUrl,
    this.youtubeUrl,
    this.youtubeId,
    this.hasYoutube = false,
    this.durationSec,
    this.attribution,
    this.publishedAt,
    this.correctionNote,
    this.disclaimer = 'AI-सहायता प्राप्त सारांश। यह सरकारी घोषणा नहीं है।',
    this.isSaved = false,
    this.news,
    this.scheme,
    this.description,
    this.narration,
    this.keyFacts = const [],
    this.warnings = const [],
  });

  /// True for a video item: either an admin-provided YouTube video for schemes, or an approved video.
  bool get hasVideo => hasYoutube || (videoUrl != null && format != ContentFormat.cardOnly);
  bool get isYoutube => hasYoutube && youtubeId != null && youtubeId!.isNotEmpty;
  bool get isRegional => subKind == 'REGIONAL' || region != null;

  /// The one link a user should follow: official application page for schemes,
  /// the publisher's article for news.
  String? get primaryLink => kind == ShortKind.scheme ? scheme?.applicationUrl : news?.url;

  ShortItem copyWith({bool? isSaved}) => ShortItem(
        id: id, kind: kind, subKind: subKind, region: region, title: title, category: category, format: format, hook: hook, summary: summary, videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl, youtubeUrl: youtubeUrl, youtubeId: youtubeId, hasYoutube: hasYoutube, durationSec: durationSec, attribution: attribution,
        publishedAt: publishedAt, correctionNote: correctionNote, disclaimer: disclaimer,
        isSaved: isSaved ?? this.isSaved, news: news, scheme: scheme, description: description,
        narration: narration, keyFacts: keyFacts, warnings: warnings,
      );

  factory ShortItem.fromJson(Map<String, dynamic> j) {
    final newsJson = j['news'];
    final schemeJson = j['scheme'];
    final yUrl = safeHttpsUrl(j['youtubeUrl'] ?? (schemeJson is Map ? schemeJson['youtubeUrl'] : null));
    final yId = (j['youtubeId'] ?? (schemeJson is Map ? schemeJson['youtubeId'] : null)) as String?;
    final hasYt = j['hasYoutube'] == true || (yId != null && yId.isNotEmpty);

    return ShortItem(
      id: j['id'] as String,
      kind: j['kind'] == 'NEWS' ? ShortKind.news : ShortKind.scheme,
      subKind: (j['subKind'] as String?) ?? (j['region'] != null ? 'REGIONAL' : 'TOP'),
      region: j['region'] as String?,
      title: (j['title'] as String?) ?? '',
      hook: j['hook'] as String?,
      summary: (j['summary'] as String?)?.trim().isEmpty == true ? null : j['summary'] as String?,
      category: (j['category'] as String?) ?? '',
      format: _format(j['format']),
      videoUrl: safeHttpsUrl(j['videoUrl']),
      thumbnailUrl: safeHttpsUrl(j['thumbnailUrl']),
      youtubeUrl: yUrl,
      youtubeId: yId,
      hasYoutube: hasYt,
      durationSec: (j['durationSec'] as num?)?.toDouble(),
      attribution: j['attribution'] as String?,
      publishedAt: _date(j['publishedAt']),
      correctionNote: j['correctionNote'] as String?,
      disclaimer: (j['disclaimer'] as String?) ?? 'AI-सहायता प्राप्त सारांश। यह सरकारी घोषणा नहीं है।',
      isSaved: j['isSaved'] == true,
      news: newsJson is Map ? NewsInfo.fromJson(Map<String, dynamic>.from(newsJson)) : null,
      scheme: schemeJson is Map ? SchemeInfo.fromJson(Map<String, dynamic>.from(schemeJson)) : null,
      description: j['description'] as String?,
      narration: j['narration'] as String?,
      keyFacts: _strings(j['keyFacts']),
      warnings: _strings(j['warnings']),
    );
  }
}

class ShortPage {
  final List<ShortItem> items;
  final bool hasMore;
  const ShortPage(this.items, this.hasMore);
}

class ShortDetail {
  final ShortItem item;
  final List<ShortItem> related;
  const ShortDetail(this.item, this.related);
}

/// Report reasons (values match the backend enum).
const kReportReasons = <String, String>{
  'INCORRECT': 'जानकारी गलत है',
  'OUTDATED': 'जानकारी पुरानी है',
  'MISLEADING': 'भ्रामक है',
  'OFFENSIVE': 'आपत्तिजनक है',
  'OTHER': 'अन्य',
};

/// Category chips. `null` value = all. Values match backend `category`.
const kNewsCategories = <(String?, String)>[
  (null, 'सभी'),
  ('INDIA', 'भारत'),
  ('MAHARASHTRA', 'महाराष्ट्र'),
  ('EDUCATION', 'शिक्षा'),
  ('FARMER', 'किसान'),
  ('ECONOMY', 'अर्थव्यवस्था'),
  ('TECH', 'तकनीक'),
  ('EMPLOYMENT', 'रोज़गार'),
];
const kSchemeCategories = <(String?, String)>[
  (null, 'सभी'),
  ('CENTRAL', 'केंद्र सरकार'),
  ('MAHARASHTRA', 'महाराष्ट्र'),
  ('SCHOLARSHIP', 'छात्रवृत्ति'),
  ('FARMER', 'किसान'),
  ('WOMEN_CHILD', 'महिला व बाल'),
  ('EMPLOYMENT', 'रोज़गार व कौशल'),
];
