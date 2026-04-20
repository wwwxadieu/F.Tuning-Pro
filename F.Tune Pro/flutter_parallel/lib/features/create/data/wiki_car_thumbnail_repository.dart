import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class WikiCarThumbnailRepository {
  WikiCarThumbnailRepository._();

  static final Map<String, String?> _memoryCache = <String, String?>{};
  static final Map<String, Future<String?>> _pending =
      <String, Future<String?>>{};
  static Future<Map<String, String>>? _catalogFuture;

  static String buildKey(String brand, String model) => '$brand $model';

  static Future<String?> resolveByName(String brand, String model) {
    final key = buildKey(brand, model);
    if (_memoryCache.containsKey(key)) {
      return Future<String?>.value(_memoryCache[key]);
    }
    final pending = _pending[key];
    if (pending != null) return pending;

    final future = _resolveInternal(key);
    _pending[key] = future;
    future.whenComplete(() => _pending.remove(key));
    return future;
  }

  static Future<String?> _resolveInternal(String key) async {
    final catalog = await _loadCatalog();
    final fromCatalog = catalog[key];
    if (fromCatalog != null && fromCatalog.isNotEmpty) {
      _memoryCache[key] = fromCatalog;
      return fromCatalog;
    }

    final live = await _fetchLive(key);
    _memoryCache[key] = live;
    return live;
  }

  static Future<Map<String, String>> _loadCatalog() {
    _catalogFuture ??= () async {
      try {
        final raw =
            await rootBundle.loadString('assets/data/wiki_car_thumbnails.json');
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      } catch (_) {
        return <String, String>{};
      }
    }();
    return _catalogFuture!;
  }

  static Future<String?> _fetchLive(String key) async {
    final exact = await _fetchThumbnailForTitle(key);
    if (exact != null) return exact;

    final candidates = await _searchTitles(key);
    for (final candidate in candidates) {
      final result = await _fetchThumbnailForTitle(candidate);
      if (result != null) return result;
    }
    return null;
  }

  static Future<String?> _fetchThumbnailForTitle(String title) async {
    final uri = Uri.https('forza.fandom.com', '/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'prop': 'pageimages',
      'pithumbsize': '800',
      'titles': title,
      'redirects': '1',
    });

    final json = await _getJson(uri);
    final query = json['query'];
    if (query is! Map<String, dynamic>) return null;
    final pages = query['pages'];
    if (pages is! List) return null;
    for (final rawPage in pages) {
      if (rawPage is! Map<String, dynamic>) continue;
      final thumbnail = rawPage['thumbnail'];
      if (thumbnail is Map<String, dynamic>) {
        final source = thumbnail['source']?.toString();
        if (source != null && source.isNotEmpty) {
          return source;
        }
      }
    }
    return null;
  }

  static Future<List<String>> _searchTitles(String query) async {
    final uri = Uri.https('forza.fandom.com', '/api.php', <String, String>{
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'list': 'search',
      'srsearch': query,
      'srlimit': '5',
    });

    final json = await _getJson(uri);
    final search = (json['query'] as Map<String, dynamic>?)?['search'];
    if (search is! List) return const <String>[];

    final normalizedQuery = _normalize(query);
    final sorted = search
        .whereType<Map<String, dynamic>>()
        .map((item) => item['title']?.toString())
        .whereType<String>()
        .toList()
      ..sort((left, right) => _searchScore(right, normalizedQuery)
          .compareTo(_searchScore(left, normalizedQuery)));
    return sorted;
  }

  static int _searchScore(String title, String normalizedQuery) {
    final normalizedTitle = _normalize(title);
    if (normalizedTitle == normalizedQuery) return 1000;
    var score = 0;
    if (normalizedTitle.contains(normalizedQuery)) score += 300;
    final tokens =
        normalizedQuery.split(' ').where((token) => token.isNotEmpty);
    for (final token in tokens) {
      if (normalizedTitle.contains(token)) score += 50;
    }
    if (title.contains('Forza Edition')) score -= 40;
    return score;
  }

  static String _normalize(String value) {
    final compact = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return compact.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient();
    client.userAgent = 'F.Tune Pro Flutter/0.1';
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return <String, dynamic>{};
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }
}
