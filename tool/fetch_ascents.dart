// Fetches your ascents from theCrag's Logbook Read API and writes the
// snapshot the app reads (assets/data/ascents.json).
//
//   THECRAG_API_KEY=... dart run tool/fetch_ascents.dart
//
// The API is documented at
// https://www.thecrag.com/de/artikel/logbookreadapi (see docs/thecrag_api.md).
// Calls cost tokens from a weekly per-account budget, so after a first full
// download only new or changed ascents are fetched (`since=<epoch>`), merged
// into a local cache (tool/.cache/ascents.json). A full download is repeated
// once a week, or with --full, to pick up deleted ascents.
//
// Without API access, import a logbook CSV exported from the theCrag website
// instead (no map coordinates in that case):
//
//   dart run tool/fetch_ascents.dart --csv ~/Downloads/logbook.csv
//
// Options:
//   --out <file>    output file (default assets/data/ascents.json)
//   --cache <file>  sync cache (default tool/.cache/ascents.json)
//   --full          ignore the cache and download the whole logbook
//   --csv <file>    read ascents from a theCrag logbook CSV export
//   --dump <dir>    save raw API responses, handy for debugging the parser
//
// Environment:
//   THECRAG_API_KEY       your personal API key (required for API mode)
//   THECRAG_DISPLAY_NAME  name shown in the app (default: your theCrag name)
//   THECRAG_BASE_URL      default https://www.thecrag.com
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/grades.dart';

/// How long an incrementally updated cache is trusted before the whole
/// logbook is downloaded again (incremental syncs cannot see deletions).
const fullRefreshAfter = Duration(days: 7);

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final env = Platform.environment;
  final baseUrl = env['THECRAG_BASE_URL'] ?? 'https://www.thecrag.com';
  final out = File(opts['out'] ?? 'assets/data/ascents.json');

  String? climber;
  List<Ascent> ascents;
  if (opts['csv'] != null) {
    ascents = parseLogbookCsv(File(opts['csv']!).readAsStringSync());
    stderr.writeln('Read ${ascents.length} ascents from CSV.');
  } else {
    final key = env['THECRAG_API_KEY'];
    if (key == null || key.isEmpty) {
      stderr.writeln('Set THECRAG_API_KEY (or use --csv).');
      exit(64);
    }
    final api = LogbookApi(
      baseUrl: baseUrl,
      apiKey: key,
      dumpDir: opts['dump'],
    );
    final sync = await syncLogbook(
      api,
      File(opts['cache'] ?? 'tool/.cache/ascents.json'),
      forceFull: opts.containsKey('full'),
    );
    climber = sync.climber;
    ascents = sync.ascents;
  }

  final dataset = AscentDataset(
    climber: resolveDisplayName(env['THECRAG_DISPLAY_NAME'], climber),
    generated: DateTime.now().toUtc(),
    ascents: ascents..sort((a, b) => a.date.compareTo(b.date)),
  );
  final located = dataset.ascents.where((a) => a.hasLocation).length;
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(dataset));
  stderr.writeln(
    'Wrote ${dataset.ascents.length} ascents '
    '($located with coordinates) to ${out.path}.',
  );
}

/// The name shown in the app: [configured] (THECRAG_DISPLAY_NAME) if it has
/// text, else the account name from theCrag. GitHub Actions passes an unset
/// variable as an empty string, which must not count as a name.
String? resolveDisplayName(String? configured, String? fromApi) {
  final name = configured?.trim();
  return name == null || name.isEmpty ? fromApi : name;
}

Map<String, String?> _parseArgs(List<String> args) {
  const flags = {'full'};
  final m = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (flags.contains(name)) {
      m[name] = null;
    } else if (i + 1 < args.length) {
      m[name] = args[++i];
    }
  }
  return m;
}

// ---------------------------------------------------------------------------
// Logbook Read API: GET /api/logbook/ascents?page=N&since=EPOCH

/// One page of `GET /api/logbook/ascents`.
class LogbookPage {
  LogbookPage({
    required this.ascents,
    required this.total,
    required this.page,
    required this.perPage,
    this.climber,
    this.maxEpoch,
  });

  /// Raw ascent objects as returned by the API.
  final List<Map<String, dynamic>> ascents;

  /// `numberAscents`: ascents matching the query (all pages).
  final int total;
  final int page;
  final int perPage;
  final String? climber;
  final int? maxEpoch;

  factory LogbookPage.fromJson(Map<String, dynamic> body) {
    final d = (body['data'] as Map).cast<String, dynamic>();
    final rows = [
      for (final a in (d['ascents'] as List? ?? const []))
        (a as Map).cast<String, dynamic>(),
    ];
    final account = d['account'] as Map?;
    int? maxEpoch;
    for (final a in rows) {
      final e = (a['epoch'] as num?)?.toInt();
      if (e != null && (maxEpoch == null || e > maxEpoch)) maxEpoch = e;
    }
    return LogbookPage(
      ascents: rows,
      total: _int(d['numberAscents']) ?? rows.length,
      page: _int(d['page']) ?? 1,
      perPage: _int(d['perPage']) ?? 250,
      climber: _str(account?['name'] ?? account?['login']),
      maxEpoch: maxEpoch,
    );
  }
}

class LogbookApi {
  LogbookApi({required this.baseUrl, required this.apiKey, this.dumpDir});

  final String baseUrl;
  final String apiKey;
  final String? dumpDir;
  final _client = http.Client();
  int _dumpN = 0;

  Future<LogbookPage> fetchPage(int page, {int? since}) async {
    final uri = Uri.parse(
      '$baseUrl/api/logbook/ascents',
    ).replace(queryParameters: {'page': '$page', 'since': ?since?.toString()});
    for (var attempt = 0; ; attempt++) {
      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-CData-Key': 'key=$apiKey',
          'User-Agent': 'thecrag-at-home (personal dashboard)',
        },
      );
      if ((res.statusCode == 429 || res.statusCode >= 500) && attempt < 4) {
        await Future<void>.delayed(Duration(seconds: 2 << attempt));
        continue;
      }
      if (dumpDir != null) {
        final f = File(
          '$dumpDir/${(_dumpN++).toString().padLeft(4, '0')}.json',
        );
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(
          '// GET $uri\n// HTTP ${res.statusCode}\n${res.body}',
        );
      }
      if (res.statusCode != 200) {
        throw HttpException(
          'HTTP ${res.statusCode} for $uri: '
          '${res.body.length > 300 ? res.body.substring(0, 300) : res.body}',
        );
      }
      return LogbookPage.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>(),
      );
    }
  }

  /// All ascents created or updated after [since] (everything if null).
  Future<({List<Map<String, dynamic>> ascents, String? climber, int? maxEpoch})>
  fetchAll({int? since}) async {
    final rows = <Map<String, dynamic>>[];
    String? climber;
    int? maxEpoch;
    for (var page = 1; page < 1000; page++) {
      final p = await fetchPage(page, since: since);
      climber ??= p.climber;
      if (p.maxEpoch != null && (maxEpoch == null || p.maxEpoch! > maxEpoch)) {
        maxEpoch = p.maxEpoch;
      }
      rows.addAll(p.ascents);
      stderr.writeln('  page $page: ${p.ascents.length} ascents');
      if (p.ascents.isEmpty ||
          p.ascents.length < p.perPage ||
          rows.length >= p.total) {
        break;
      }
    }
    return (ascents: rows, climber: climber, maxEpoch: maxEpoch);
  }
}

/// Brings the local cache up to date and returns all ascents.
Future<({List<Ascent> ascents, String? climber})> syncLogbook(
  LogbookApi api,
  File cacheFile, {
  bool forceFull = false,
  DateTime? now,
}) async {
  now ??= DateTime.now().toUtc();
  final cache = SyncCache.load(cacheFile);
  final full =
      forceFull ||
      cache == null ||
      cache.lastFull == null ||
      now.difference(cache.lastFull!) > fullRefreshAfter;

  final since = full ? null : cache.since;
  stderr.writeln(
    full
        ? 'Downloading the whole logbook...'
        : 'Fetching ascents changed since epoch $since...',
  );
  final res = await api.fetchAll(since: since);

  final byId = <String, Ascent>{
    if (!full)
      for (final a in cache.ascents) a.id: a,
  };
  var skipped = 0;
  for (final row in res.ascents) {
    final a = parseLogbookAscent(row, api.baseUrl);
    if (a == null) {
      skipped++;
    } else {
      byId[a.id] = a;
    }
  }
  if (skipped > 0) stderr.writeln('  skipped $skipped ascents without a date');
  stderr.writeln(
    '${res.ascents.length} ascents fetched, ${byId.length} in total.',
  );

  final updated = SyncCache(
    since: [
      ?cache?.since,
      ?res.maxEpoch,
    ].fold<int?>(null, (m, e) => m == null || e > m ? e : m),
    lastFull: full ? now : cache.lastFull,
    climber: res.climber ?? cache?.climber,
    ascents: byId.values.toList(),
  );
  updated.save(cacheFile);
  return (ascents: updated.ascents, climber: updated.climber);
}

/// Layout version of the cache file. Raise it whenever the normalised ascents
/// gain fields, so an older cache is rebuilt with a full download instead of
/// being kept (and merged into) until the weekly refresh.
const cacheVersion = 4;

/// Normalised ascents plus the state needed for incremental syncs.
class SyncCache {
  SyncCache({required this.ascents, this.since, this.lastFull, this.climber});

  final List<Ascent> ascents;

  /// Highest `epoch` seen; the next sync asks for changes after it.
  final int? since;
  final DateTime? lastFull;
  final String? climber;

  static SyncCache? load(File f) {
    if (!f.existsSync()) return null;
    try {
      final j = (jsonDecode(f.readAsStringSync()) as Map)
          .cast<String, dynamic>();
      if (j['version'] != cacheVersion) return null;
      return SyncCache(
        since: _int(j['since']),
        lastFull: j['lastFull'] == null
            ? null
            : DateTime.tryParse(j['lastFull'] as String),
        climber: j['climber'] as String?,
        ascents: [
          for (final a in j['ascents'] as List)
            Ascent.fromJson((a as Map).cast<String, dynamic>()),
        ],
      );
    } on Object catch (e) {
      stderr.writeln('Ignoring unreadable cache ${f.path}: $e');
      return null;
    }
  }

  void save(File f) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      jsonEncode({
        'version': cacheVersion,
        'since': ?since,
        'lastFull': ?lastFull?.toIso8601String(),
        'climber': ?climber,
        'ascents': [for (final a in ascents) a.toJson()],
      }),
    );
  }
}

/// Converts one ascent object of the Logbook Read API to an [Ascent].
///
/// Private notes (`markdown`) are deliberately not carried over: the
/// snapshot ends up on a public web page.
Ascent? parseLogbookAscent(Map<String, dynamic> m, String baseUrl) {
  // `date` is when the climb happened; a few historical entries only have
  // `logDate` (when it was logged).
  final date = _parseDate(m['date']) ?? _parseDate(m['logDate']);
  if (date == null) return null;

  final route = (m['route'] as Map?)?.cast<String, dynamic>() ?? const {};
  final ancestors =
      (route['ancestors'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic>? anc(String k) =>
      (ancestors[k] as Map?)?.cast<String, dynamic>();
  final tlc = anc('TLC'), parent = anc('parent'), country = anc('country');

  // Coordinates: the route's sector, else its crag.
  final pos = _lonLat(parent?['geometry']) ?? _lonLat(tlc?['geometry']);

  final routeStyle = _str(route['style'])?.toLowerCase();
  final gearStyle = _str(m['climbedGearStyle'])?.toLowerCase();
  final discipline = routeStyle == null && gearStyle == null
      ? null
      : (routeStyle == 'boulder' || gearStyle == 'boulder')
      ? Discipline.boulder
      : Discipline.route;

  final kind = routeStyle == 'boulder' || gearStyle == 'boulder'
      ? ClimbKind.boulder
      : routeStyle == 'trad'
      ? ClimbKind.trad
      : ClimbKind.sport;

  final routeId = _str(route['id']);
  final stub = _str(route['urlAncestorStub'] ?? parent?['urlAncestorStub']);
  final url = routeId == null
      ? null
      : stub == null
      ? '$baseUrl/climbing/route/$routeId'
      : '$baseUrl/climbing/$stub/route/$routeId';

  final tick = m['tick'];
  final cragName = _str(tlc?['name']);
  final sectorName = _str(parent?['name']);
  return Ascent(
    id: _str(m['id']) ?? '$routeId-${dayKey(date)}',
    date: date,
    route: _str(route['name'] ?? m['label']) ?? 'Unknown route',
    // The grade logged with the ascent, else the route's consensus grade.
    grade: _str(m['grade']) ?? _str(route['grade']),
    style: tick is Map ? _str(tick['label'] ?? tick['name']) : _str(tick),
    crag: cragName ?? sectorName,
    area: sectorName != null && sectorName != cragName ? sectorName : null,
    country: _str(country?['name']),
    lat: pos?.$1,
    lon: pos?.$2,
    url: url,
    discipline: discipline,
    kind: kind,
    routeId: routeId,
    pitches: m['pitch'] is List && (m['pitch'] as List).isNotEmpty
        ? (m['pitch'] as List).length
        : null,
  );
}

/// `[lon, lat]` geometry → `(lat, lon)`.
(double, double)? _lonLat(Object? g) {
  if (g is! List || g.length < 2 || g[0] is! num || g[1] is! num) return null;
  final lon = (g[0] as num).toDouble(), lat = (g[1] as num).toDouble();
  if (lat.abs() > 90 || lon.abs() > 180 || (lat == 0 && lon == 0)) return null;
  return (lat, lon);
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// Calendar day of a date string (time and time zone are ignored, so
/// `2024-06-01T00:00:00Z` is the 1st everywhere).
DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) {
    return DateTime(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }
  final dmy = RegExp(r'(\d{1,2})[/.](\d{1,2})[/.](\d{4})').firstMatch(s);
  if (dmy != null) {
    return DateTime(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  }
  return null;
}

// ---------------------------------------------------------------------------
// Logbook CSV export.

List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString());
  if (row.any((f) => f.isNotEmpty)) rows.add(row);
  return rows;
}

/// Parses a theCrag logbook CSV export, matching columns by header name.
List<Ascent> parseLogbookCsv(String text) {
  final rows = _parseCsv(text.replaceFirst('﻿', ''));
  if (rows.isEmpty) return const [];
  final header = [for (final h in rows.first) h.toLowerCase().trim()];
  int col(List<String> names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) return i;
    }
    for (final n in names) {
      final i = header.indexWhere((h) => h.contains(n));
      if (i >= 0) return i;
    }
    return -1;
  }

  final cDate = col(['ascent date', 'date']);
  final cRoute = col(['route name', 'route']);
  final cGrade = col(['ascent grade', 'route grade', 'grade']);
  final cStyle = col(['ascent type', 'tick type', 'type']);
  final cCrag = col(['crag name', 'crag']);
  final cArea = col(['area name', 'area']);
  final cCountry = col(['country']);
  final cId = col(['ascent id']);
  final cRouteLink = col(['route link']);
  if (cDate < 0) throw const FormatException('CSV has no date column');

  String? at(List<String> r, int i) =>
      i < 0 || i >= r.length || r[i].trim().isEmpty ? null : r[i].trim();

  final out = <Ascent>[];
  for (final r in rows.skip(1)) {
    final date = _parseDate(at(r, cDate));
    if (date == null) continue;
    // Prefer the ascent grade, fall back to the route grade.
    final grade = at(r, cGrade) ?? at(r, col(['route grade']));
    out.add(
      Ascent(
        id: at(r, cId) ?? '${out.length}',
        date: date,
        route: at(r, cRoute) ?? 'Unknown route',
        grade: grade,
        style: at(r, cStyle),
        crag: at(r, cCrag),
        area: at(r, cArea),
        country: at(r, cCountry),
        url: at(r, cRouteLink),
      ),
    );
  }
  return out;
}
