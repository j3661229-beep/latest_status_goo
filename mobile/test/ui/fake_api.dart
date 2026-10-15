// Fake HTTP adapter for UI tests: serves canned API responses so the REAL repositories and providers run.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

enum FakeApiMode {
  /// Backend reachable, rich realistic data (long Hindi text, many items) — worst case for layout.
  data,

  /// Backend returning errors / unreachable — every screen must still render a usable state.
  failing,

  /// Backend reachable but empty — empty states.
  empty,
}

Map<String, dynamic> template(int i, {bool video = false, bool premium = false, bool locked = false}) => {
      'id': 't$i',
      'type': video ? 'VIDEO' : 'IMAGE',
      'status': 'APPROVED',
      'categoryId': 'c${i % 3}',
      'category': {'id': 'c${i % 3}', 'slug': 'cat${i % 3}', 'nameHi': 'शुभ प्रभात संदेश ${i % 3}', 'nameEn': 'Good Morning', 'emoji': '🌅'},
      'creator': {'id': 'cr1', 'name': 'क्रिएटर नाम जो काफ़ी लंबा हो सकता है'},
      'nameHi': 'आपका दिन मंगलमय हो — बहुत लंबा हिंदी शीर्षक नंबर $i जो छोटे स्क्रीन पर कई पंक्तियों में टूटेगा',
      'nameEn': 'A very long English title for template number $i that will wrap on small screens',
      'quoteHi': 'सुबह की पहली किरण आपके जीवन में खुशियाँ और सफलता लेकर आए, यही हमारी शुभकामना है।',
      'imageUrl': null,
      'imageThumbUrl': null,
      'videoUrl': video ? 'https://cdn.test/v$i.mp4' : null,
      'videoThumbUrl': null,
      'videoDuration': video ? 12 : null,
      'gradient': 'linear-gradient(135deg,#2563EB,#0EA5E9)',
      'photoZoneEnabled': true,
      'photoZoneX': 0.5,
      'photoZoneY': 0.3,
      'photoZoneSize': 0.3,
      'photoZoneShape': 'circle',
      'nameZoneEnabled': true,
      'nameZoneX': 0.5,
      'nameZoneY': 0.8,
      'tags': ['गुड मॉर्निंग', 'सुप्रभात', 'फ़ेस्टिवल'],
      'isFeatured': i % 2 == 0,
      'isTrending': i % 3 == 0,
      'isPremium': premium,
      'isLocked': locked,
      'isNew': i % 4 == 0,
      'useCount': 1200 * i,
      'shareCount': 800 * i,
      'saveCount': 90 * i,
      'viewCount': 15000 * i,
    };

List<Map<String, dynamic>> templates(int n) =>
    [for (var i = 1; i <= n; i++) template(i, video: i % 3 == 0, premium: i % 5 == 0, locked: i % 5 == 0)];

class FakeApi implements HttpClientAdapter {
  FakeApi(this.mode);
  final FakeApiMode mode;
  final List<String> calls = [];

  Object? _body(RequestOptions o) {
    final p = o.path;
    final empty = mode == FakeApiMode.empty;
    List<Map<String, dynamic>> list(int n) => empty ? [] : templates(n);

    if (p == '/templates/home') {
      return {
        'data': {
          'featured': list(8),
          'trending': list(8),
          'coordinatorPicks': list(3),
          'festivalToday': empty ? null : {'id': 'f1', 'nameHi': 'महाशिवरात्रि की हार्दिक शुभकामनाएँ', 'date': '2026-10-15'},
          'categories': empty
              ? []
              : [
                  for (var i = 0; i < 8; i++)
                    {'id': 'c$i', 'slug': 'cat$i', 'nameHi': 'श्रेणी नंबर $i', 'nameEn': 'Category $i', 'emoji': '🙏', 'templateCount': 20 + i},
                ],
        },
      };
    }
    if (p == '/templates') {
      final page = (o.queryParameters['page'] as int?) ?? 1;
      return {'data': page > 1 ? [] : list(12), 'meta': {'page': page, 'hasMore': false}};
    }
    if (p.startsWith('/templates/') && !p.endsWith('/view') && !p.endsWith('/use') && !p.endsWith('/share')) {
      return empty ? null : {'data': template(1), ...template(1)};
    }
    if (p == '/user/saved') return {'data': list(6), 'meta': {'page': 1, 'hasMore': false}};
    if (p == '/festivals/upcoming') {
      return {
        'data': empty
            ? []
            : [
                for (var i = 1; i <= 5; i++)
                  {'id': 'f$i', 'nameHi': 'त्योहार नंबर $i', 'nameEn': 'Festival $i', 'emoji': '🪔', 'date': DateTime.now().add(Duration(days: i * 4)).toIso8601String(), 'category': null},
              ],
      };
    }
    if (p == '/search') return {'data': list(6), 'meta': {'page': 1, 'hasMore': false}};
    if (p == '/search/trending') return {'terms': empty ? [] : ['गुड मॉर्निंग', 'जन्मदिन', 'दीवाली', 'भक्ति', 'राजनीति', 'शायरी']};
    if (p == '/search/suggestions') return {'suggestions': empty ? [] : ['गुड मॉर्निंग इमेज', 'गुड नाइट']};
    if (p == '/subscribe/status') {
      return {
        'plan': 'FREE', 'isRecurring': false, 'recurringAmount': 9900, 'introEligible': true,
      };
    }
    if (p == '/subscribe/plans') {
      return {
        'plans': [
          {'id': 'PREMIUM', 'name': 'मासिक', 'price': 99, 'amount': 9900},
          {'id': 'ANNUAL', 'name': 'वार्षिक', 'price': 799, 'amount': 79900},
        ],
      };
    }
    if (p == '/user/notifications') {
      return {
        'data': empty
            ? []
            : [
                for (var i = 0; i < 12; i++)
                  {
                    'id': 'n$i', 'title': 'आज का स्टेटस तैयार है — बहुत लंबा नोटिफिकेशन शीर्षक $i',
                    'body': 'आपके लिए नया शुभ प्रभात टेम्पलेट आया है। अभी अपने नाम और फोटो के साथ शेयर करें और अपने दोस्तों को भेजें।',
                    'type': 'DAILY_STATUS', 'sentAt': DateTime.now().subtract(Duration(hours: i * 5)).toIso8601String(),
                  },
              ],
      };
    }
    if (p.startsWith('/shorts/bookmarks') || p == '/news' || p == '/schemes') {
      return {'data': [], 'meta': {'page': 1, 'hasMore': false}};
    }
    if (p == '/auth/me') return null;
    return null; // unknown → 404
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    if (mode == FakeApiMode.failing) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'offline (fake)');
    }
    final body = _body(options);
    final status = body == null ? 404 : 200;
    return ResponseBody.fromString(
      jsonEncode(body ?? {'error': 'Not found'}),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
