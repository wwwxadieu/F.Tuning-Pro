import 'dart:convert';
import 'dart:io';

const _carsPaths = <String>[
  'assets/data/FH5_cars.json',
  'assets/data/FH6_cars.json',
];
const _outputPath = 'assets/data/wiki_car_thumbnails.json';
const _missingPath = 'assets/data/wiki_car_thumbnails_missing.json';
const _batchSize = 40;

Future<void> main() async {
  final cars = await _loadCarTitles();
  if (cars.isEmpty) {
    stderr.writeln('Missing all car catalogs: ${_carsPaths.join(', ')}');
    exitCode = 1;
    return;
  }

  final cachedResults = await _loadExistingResults();
  final results = <String, String>{
    for (final title in cars)
      if ((cachedResults[title] ?? '').trim().isNotEmpty)
        title: cachedResults[title]!.trim(),
  };
  final missing = <String>[];
  final unresolved = cars.where((title) => !results.containsKey(title)).toList();

  stdout.writeln(
    'Resolving ${cars.length} car thumbnails from wiki across ${_carsPaths.length} catalogs...',
  );
  if (results.isNotEmpty) {
    stdout.writeln('Reusing ${results.length} cached thumbnails from $_outputPath');
  }

  for (var index = 0; index < unresolved.length; index += _batchSize) {
    final batch = unresolved.skip(index).take(_batchSize).toList();
    final exact = await _fetchExactBatch(batch);
    for (final title in batch) {
      final match = exact[title];
      if (match != null && match.isNotEmpty) {
        results[title] = match;
      } else {
        final fallback = await _fetchWithSearch(title);
        if (fallback != null && fallback.isNotEmpty) {
          results[title] = fallback;
        } else {
          missing.add(title);
        }
      }
    }
    stdout.writeln(
      'Processed ${results.length + missing.length}/${cars.length} · found ${results.length} · missing ${missing.length}',
    );
  }

  await File(_outputPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(_sorted(results)),
  );
  await File(_missingPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(missing..sort()),
  );

  stdout.writeln('Saved $_outputPath');
  stdout.writeln('Missing count: ${missing.length}');
}

Future<List<String>> _loadCarTitles() async {
  final titles = <String>{};

  for (final path in _carsPaths) {
    final inputFile = File(path);
    if (!inputFile.existsSync()) {
      stderr.writeln('Missing $path');
      continue;
    }

    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! List) continue;

    titles.addAll(
      decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => '${item['brand']} ${item['model']}'),
    );
  }

  final sorted = titles.toList()..sort();
  return sorted;
}

Future<Map<String, String>> _loadExistingResults() async {
  final file = File(_outputPath);
  if (!file.existsSync()) return <String, String>{};

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) return <String, String>{};

  return decoded.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}

Future<Map<String, String?>> _fetchExactBatch(List<String> titles) async {
  final uri = Uri.https('forza.fandom.com', '/api.php', <String, String>{
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'prop': 'pageimages',
    'pithumbsize': '800',
    'redirects': '1',
    'titles': titles.join('|'),
  });

  final json = await _getJson(uri);
  final query = json['query'];
  if (query is! Map<String, dynamic>) {
    return <String, String?>{};
  }

  final pages = (query['pages'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .toList();
  final normalized = <String, String>{};
  for (final item
      in (query['normalized'] as List<dynamic>? ?? const <dynamic>[])) {
    if (item is! Map<String, dynamic>) continue;
    final from = item['from']?.toString();
    final to = item['to']?.toString();
    if (from != null && to != null) normalized[from] = to;
  }
  final redirects = <String, String>{};
  for (final item
      in (query['redirects'] as List<dynamic>? ?? const <dynamic>[])) {
    if (item is! Map<String, dynamic>) continue;
    final from = item['from']?.toString();
    final to = item['to']?.toString();
    if (from != null && to != null) redirects[from] = to;
  }

  final byTitle = <String, Map<String, dynamic>>{};
  for (final page in pages) {
    final title = page['title']?.toString();
    if (title != null) byTitle[title] = page;
  }

  final results = <String, String?>{};
  for (final original in titles) {
    final normalizedTitle = normalized[original] ?? original;
    final resolvedTitle = redirects[normalizedTitle] ?? normalizedTitle;
    final page = byTitle[resolvedTitle];
    final thumb = (page?['thumbnail'] as Map<String, dynamic>?)?['source'];
    results[original] = thumb?.toString();
  }
  return results;
}

Future<String?> _fetchWithSearch(String title) async {
  final uri = Uri.https('forza.fandom.com', '/api.php', <String, String>{
    'action': 'query',
    'format': 'json',
    'formatversion': '2',
    'list': 'search',
    'srsearch': title,
    'srlimit': '5',
  });

  final json = await _getJson(uri);
  final search =
      ((json['query'] as Map<String, dynamic>?)?['search'] as List<dynamic>? ??
              const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((item) => item['title']?.toString())
          .whereType<String>()
          .toList();

  if (search.isEmpty) return null;

  final normalizedTitle = _normalize(title);
  search.sort((left, right) => _scoreCandidate(right, normalizedTitle)
      .compareTo(_scoreCandidate(left, normalizedTitle)));

  final best = search.first;
  final result = await _fetchExactBatch(<String>[best]);
  return result[best];
}

int _scoreCandidate(String candidate, String normalizedTitle) {
  final normalizedCandidate = _normalize(candidate);
  if (normalizedCandidate == normalizedTitle) return 1000;
  var score = 0;
  if (normalizedCandidate.contains(normalizedTitle)) score += 300;
  final tokens =
      normalizedTitle.split(' ').where((token) => token.trim().isNotEmpty);
  for (final token in tokens) {
    if (normalizedCandidate.contains(token)) score += 50;
  }
  if (candidate.contains('Forza Edition')) score -= 25;
  return score;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

Map<String, String> _sorted(Map<String, String> input) {
  final entries = input.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return <String, String>{for (final entry in entries) entry.key: entry.value};
}

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final client = HttpClient();
  client.userAgent = 'F.Tune Pro Thumbnail Sync/0.1';
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
