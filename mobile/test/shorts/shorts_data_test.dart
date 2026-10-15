import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_go/features/shorts/data/short_models.dart';
import 'package:status_go/features/shorts/data/shorts_repository.dart';
import 'package:status_go/features/shorts/presentation/providers/shorts_feed_provider.dart';

import 'fake_repo.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final (int, Object?) Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> item(String id, {String kind = 'NEWS'}) => {'id': id, 'kind': kind, 'title': 't$id', 'category': 'INDIA'};

ShortsRepository _repoWith(_Adapter a) => ShortsRepository(Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = a);

ShortItem mk(String id) => ShortItem.fromJson(item(id));

void main() {
  group('ShortsRepository', () {
    test('list hits /news or /schemes with paging + category, and parses meta', () async {
      final a = _Adapter((o) => (200, {'data': [item('1'), item('2')], 'meta': {'hasMore': true}}));
      final r = _repoWith(a);
      final p = await r.list(feed: ShortsFeed.news, category: 'FARMER', page: 2);
      expect(a.requests.single.path, '/news');
      expect(a.requests.single.queryParameters, {'page': 2, 'limit': 10, 'category': 'FARMER'});
      expect(p.items.map((e) => e.id), ['1', '2']);
      expect(p.hasMore, isTrue);
      await r.list(feed: ShortsFeed.scheme);
      expect(a.requests.last.path, '/schemes');
      await r.list(feed: ShortsFeed.saved);
      expect(a.requests.last.path, '/shorts/bookmarks/list');
    });

    test('skips malformed items instead of failing the page', () async {
      final a = _Adapter((o) => (200, {'data': [item('1'), 'garbage', {'no': 'id'}, item('3')], 'meta': {'hasMore': false}}));
      final p = await _repoWith(a).list(feed: ShortsFeed.news);
      expect(p.items.map((e) => e.id), ['1', '3']);
      expect(p.hasMore, isFalse);
    });

    test('throws on a non-conforming response and on HTTP errors', () async {
      expect(() => _repoWith(_Adapter((o) => (200, {'oops': 1}))).list(feed: ShortsFeed.news), throwsFormatException);
      expect(() => _repoWith(_Adapter((o) => (500, {'message': 'x'}))).list(feed: ShortsFeed.news), throwsA(isA<DioException>()));
    });

    test('detail parses item + related; bookmark/report/event call the right endpoints', () async {
      final a = _Adapter((o) {
        if (o.path == '/shorts/s1' && o.method == 'GET') {
          return (200, {'data': {...item('s1', kind: 'SCHEME'), 'narration': 'पाठ'}, 'related': [item('r1')]});
        }
        if (o.path.endsWith('/events')) return (500, {'message': 'down'});
        return (200, {'ok': true});
      });
      final r = _repoWith(a);
      final d = await r.detail('s1');
      expect(d.item.narration, 'पाठ');
      expect(d.related.single.id, 'r1');

      await r.setSaved('s1', true);
      expect(a.requests.last.method, 'POST');
      expect(a.requests.last.path, '/shorts/s1/bookmark');
      await r.setSaved('s1', false);
      expect(a.requests.last.method, 'DELETE');

      await r.report('s1', 'OUTDATED', note: '  पुराना  ');
      expect(a.requests.last.data, {'reason': 'OUTDATED', 'note': 'पुराना'});
      await r.report('s1', 'OTHER', note: '  ');
      expect(a.requests.last.data, {'reason': 'OTHER'});

      await r.event('s1', 'VIEW'); // server error must be swallowed
    });
  });

  group('ShortsFeedNotifier', () {
    ProviderContainer container(FakeRepo repo) {
      final c = ProviderContainer(overrides: [shortsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('loads first page then paginates without duplicates, stopping at the end', () async {
      final repo = FakeRepo(onList: (f, c, page) async => switch (page) {
            1 => ShortPage([mk('1'), mk('2')], true),
            2 => ShortPage([mk('2'), mk('3')], false), // overlap must be deduped
            _ => throw StateError('should not fetch page $page'),
          });
      final c = container(repo);
      const q = ShortsQuery(ShortsFeed.news);
      c.listen(shortsFeedProvider(q), (_, __) {});
      await settle();
      expect(c.read(shortsFeedProvider(q)).items.map((e) => e.id), ['1', '2']);
      final n = c.read(shortsFeedProvider(q).notifier);
      await n.loadMore();
      expect(c.read(shortsFeedProvider(q)).items.map((e) => e.id), ['1', '2', '3']);
      expect(c.read(shortsFeedProvider(q)).hasMore, isFalse);
      await n.loadMore(); // no-op, would throw if it fetched
      expect(c.read(shortsFeedProvider(q)).items.length, 3);
    });

    test('first-page failure exposes error; retry recovers; load-more failure keeps items', () async {
      var fail = true;
      final repo = FakeRepo(onList: (f, c, page) async {
        if (fail) throw Exception('offline');
        return ShortPage([mk('1')], page == 1);
      });
      final c = container(repo);
      const q = ShortsQuery(ShortsFeed.scheme, 'FARMER');
      c.listen(shortsFeedProvider(q), (_, __) {});
      await settle();
      expect(c.read(shortsFeedProvider(q)).error, isNotNull);
      expect(c.read(shortsFeedProvider(q)).loading, isFalse);

      fail = false;
      await c.read(shortsFeedProvider(q).notifier).refresh();
      expect(c.read(shortsFeedProvider(q)).error, isNull);
      expect(c.read(shortsFeedProvider(q)).items, hasLength(1));

      fail = true;
      await c.read(shortsFeedProvider(q).notifier).loadMore();
      final s = c.read(shortsFeedProvider(q));
      expect(s.loadMoreError, isNotNull);
      expect(s.items, hasLength(1)); // existing content survives
    });

    test('refresh failure keeps the existing items visible', () async {
      var calls = 0;
      final repo = FakeRepo(onList: (f, c, page) async {
        if (++calls == 1) return ShortPage([mk('1')], false);
        throw Exception('offline');
      });
      final c = container(repo);
      const q = ShortsQuery(ShortsFeed.news);
      c.listen(shortsFeedProvider(q), (_, __) {});
      await settle();
      await c.read(shortsFeedProvider(q).notifier).refresh();
      expect(c.read(shortsFeedProvider(q)).items, hasLength(1));
      expect(c.read(shortsFeedProvider(q)).error, isNotNull);
    });

    test('optimistic bookmark rolls back and rethrows on failure', () async {
      final repo = FakeRepo(
        onList: (f, c, p) async => ShortPage([mk('1')], false),
        onSave: (id, saved) async => throw Exception('403'),
      );
      final c = container(repo);
      const q = ShortsQuery(ShortsFeed.news);
      c.listen(shortsFeedProvider(q), (_, __) {});
      await settle();
      final n = c.read(shortsFeedProvider(q).notifier);
      await expectLater(n.toggleSaved('1'), throwsException);
      expect(c.read(shortsFeedProvider(q)).items.single.isSaved, isFalse);

      repo.onSave = (id, saved) async {};
      await n.toggleSaved('1');
      expect(c.read(shortsFeedProvider(q)).items.single.isSaved, isTrue);
    });

    test('a slow response arriving after dispose is ignored', () async {
      final gate = Future<void>.delayed(const Duration(milliseconds: 20));
      final repo = FakeRepo(onList: (f, c, p) async {
        await gate;
        return ShortPage([mk('1')], false);
      });
      final c = ProviderContainer(overrides: [shortsRepositoryProvider.overrideWithValue(repo)]);
      const q = ShortsQuery(ShortsFeed.news);
      final sub = c.listen(shortsFeedProvider(q), (_, __) {});
      sub.close();
      await settle();
      c.dispose(); // must not throw "state set after dispose" when gate completes
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
  });
}
