// Fetches your ascents from the theCrag API and writes the snapshot the app
// reads (assets/data/ascents.json).
//
//   THECRAG_API_KEY=... dart run tool/fetch_ascents.dart
//
// Uses the Logbook Read API (GET /api/logbook/ascents, header
// `X-CData-Key: key=<key>`); the account is derived from the key. If
// THECRAG_API_KEY is unset the header is omitted, which works behind a proxy
// that injects it.
//
// Alternatively import a logbook CSV exported from theCrag website (the API
// key is then only used to look up crag coordinates):
//
//   dart run tool/fetch_ascents.dart --csv ~/Downloads/logbook.csv
//
// Options:
//   --out <file>   output file (default assets/data/ascents.json)
//   --csv <file>   read ascents from a theCrag logbook CSV export
//   --dump <dir>   save raw API responses, handy for debugging the parser
//   --no-geo       skip coordinate lookups
//
// Environment:
//   THECRAG_API_KEY      your personal API key (required for API mode)
//   THECRAG_ACCOUNT      optional display name (defaults to the account in the API response)
//   THECRAG_BASE_URL     default https://www.thecrag.com
//   THECRAG_ASCENTS_PATH default /api/logbook/ascents
//
// See docs/thecrag_api.md.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:thecrag_at_home/models/ascent.dart';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final env = Platform.environment;
  final key = env['THECRAG_API_KEY'];
  final account = env['THECRAG_ACCOUNT'];
  final api = TheCragApi(
    baseUrl: env['THECRAG_BASE_URL'] ?? 'https://www.thecrag.com',
    apiKey: key,
    ascentsPath: env['THECRAG_ASCENTS_PATH'] ?? '/api/logbook/ascents',
    nodePath: env['THECRAG_NODE_PATH'] ?? '/api/node/id/{id}',
    dumpDir: opts['dump'],
  );

  List<RawAscent> raw;
  if (opts['csv'] != null) {
    raw = parseLogbookCsv(File(opts['csv']!).readAsStringSync());
    stderr.writeln('Read ${raw.length} ascents from CSV.');
  } else {
    raw = await api.fetchAscents();
    stderr.writeln('Fetched ${raw.length} ascents from the API.');
  }

  if (!opts.containsKey('no-geo') && key != null && opts['csv'] != null) {
    await api.fillCoordinates(raw, cacheFile: File('tool/.cache/nodes.json'));
  }

  final dataset = AscentDataset(
    climber: env['THECRAG_DISPLAY_NAME'] ?? account ?? api.accountName,
    generated: DateTime.now().toUtc(),
    ascents: [for (final r in raw) r.toAscent()],
  );
  final located = dataset.ascents.where((a) => a.hasLocation).length;
  final out = File(opts['out'] ?? 'assets/data/ascents.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(dataset));
  stderr.writeln(
    'Wrote ${dataset.ascents.length} ascents '
    '($located with coordinates) to ${out.path}.',
  );
}

Map<String, String?> _parseArgs(List<String> args) {
  final m = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (name == 'no-geo') {
      m[name] = null;
    } else if (i + 1 < args.length) {
      m[name] = args[++i];
    }
  }
  return m;
}

/// Ascent while being assembled, before coordinates are known.
class RawAscent {
  RawAscent({
    required this.id,
    required this.date,
    required this.route,
    this.grade,
    this.style,
    this.crag,
    this.area,
    this.country,
    this.url,
    this.nodeIds = const [],
    this.lat,
    this.lon,
  });

  final String id;
  final DateTime date;
  final String route;
  final String? grade, style, crag, area, country, url;

  /// Candidate node ids to look up coordinates for, most specific first
  /// (route, then crag/area ancestors).
  final List<String> nodeIds;
  double? lat, lon;

  Ascent toAscent() => Ascent(
    id: id,
    date: date,
    route: route,
    grade: grade,
    style: style,
    crag: crag,
    area: area,
    country: country,
    url: url,
    lat: lat,
    lon: lon,
  );
}

class TheCragApi {
  TheCragApi({
    required this.baseUrl,
    required this.apiKey,
    required this.ascentsPath,
    required this.nodePath,
    this.dumpDir,
  });

  final String baseUrl;
  final String? apiKey;
  final String ascentsPath;
  final String nodePath;
  final String? dumpDir;
  final _client = http.Client();
  int _dumpN = 0;

  /// Display name from `data.account`, set after [fetchAscents].
  String? accountName;

  Future<Object?> _get(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        ...Uri.parse('$baseUrl$path').queryParameters,
        ...query,
      },
    );
    for (var attempt = 0; ; attempt++) {
      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (apiKey != null) 'X-CData-Key': 'key=$apiKey',
          'User-Agent': 'thecrag-at-home (personal dashboard)',
        },
      );
      if (res.statusCode == 429 || res.statusCode >= 500) {
        if (attempt < 4) {
          await Future<void>.delayed(Duration(seconds: 2 << attempt));
          continue;
        }
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
          'HTTP ${res.statusCode} for ${uri.path}: '
          '${res.body.length > 300 ? res.body.substring(0, 300) : res.body}',
        );
      }
      return jsonDecode(res.body);
    }
  }

  /// Pages through `GET /api/logbook/ascents` (250 ascents per page).
  Future<List<RawAscent>> fetchAscents() async {
    final result = <RawAscent>[];
    final seen = <String>{};
    for (var page = 1; page < 1000; page++) {
      final body = await _get(ascentsPath, {'page': '$page'});
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        final acc = data['account'];
        if (acc is Map) accountName ??= _str(acc['name'] ?? acc['login']);
      }
      final rows = findAscentRows(body);
      var added = 0;
      for (final row in rows) {
        final a = parseAscentMap(row, baseUrl);
        if (a != null && seen.add(a.id)) {
          result.add(a);
          added++;
        }
      }
      final total = data is Map ? data['numberAscents'] : null;
      stderr.writeln('  page $page: ${rows.length} rows (total $total)');
      if (rows.isEmpty || added == 0) break;
      if (total is num && seen.length >= total) break;
    }
    return result;
  }

  /// Looks up coordinates for each ascent's route / crag node, caching
  /// results on disk.
  Future<void> fillCoordinates(
    List<RawAscent> ascents, {
    required File cacheFile,
  }) async {
    final cache = <String, List<double>?>{};
    if (cacheFile.existsSync()) {
      final m = jsonDecode(cacheFile.readAsStringSync()) as Map;
      m.forEach(
        (k, v) => cache['$k'] = v == null
            ? null
            : [for (final x in v as List) (x as num).toDouble()],
      );
    }
    var lookups = 0;
    for (final a in ascents) {
      if (a.lat != null) continue;
      for (final id in a.nodeIds) {
        if (!cache.containsKey(id)) {
          try {
            final body = await _get(nodePath.replaceAll('{id}', id));
            final c = findCoordinates(body);
            cache[id] = c == null ? null : [c.$1, c.$2];
          } on Object catch (e) {
            stderr.writeln('  node $id: $e');
            cache[id] = null;
          }
          if (++lookups % 25 == 0) {
            stderr.writeln('  looked up $lookups nodes...');
            _saveCache(cacheFile, cache);
          }
        }
        final c = cache[id];
        if (c != null) {
          a.lat = c[0];
          a.lon = c[1];
          break;
        }
      }
    }
    _saveCache(cacheFile, cache);
  }

  void _saveCache(File f, Map<String, List<double>?> cache) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(cache));
  }
}

// ---------------------------------------------------------------------------
// Tolerant JSON parsing. theCrag responses wrap results in a `data` object;
// rows may be maps, or arrays described by a separate list of field names.

const _dateKeys = ['date', 'ascentDate', 'tickDate', 'when', 'dateClimbed'];

/// Finds the list of ascent records anywhere in [body].
List<Map<String, dynamic>> findAscentRows(Object? body) {
  List<Map<String, dynamic>>? found;
  void visit(Object? node, Map<String, dynamic>? parent) {
    if (found != null) return;
    if (node is List && node.isNotEmpty) {
      if (node.first is Map &&
          (node.first as Map).keys.any(
            (k) => _dateKeys.contains(k) || '$k'.toLowerCase().contains('date'),
          )) {
        found = [for (final e in node) (e as Map).cast<String, dynamic>()];
        return;
      }
      if (node.first is List && parent != null) {
        // Array rows + a list of field names somewhere in the parent.
        final fields = parent.values.whereType<List>().firstWhere(
          (l) =>
              l.isNotEmpty &&
              l.every((x) => x is String) &&
              l.length == (node.first as List).length,
          orElse: () => const [],
        );
        if (fields.isNotEmpty) {
          found = [
            for (final row in node)
              {
                for (var i = 0; i < fields.length; i++)
                  fields[i] as String: (row as List)[i],
              },
          ];
          return;
        }
      }
      for (final e in node) {
        visit(e, parent);
      }
    } else if (node is Map) {
      final m = node.cast<String, dynamic>();
      // Prefer obvious keys first.
      for (final k in ['ascents', 'data', 'results', 'items']) {
        if (m.containsKey(k)) visit(m[k], m);
      }
      for (final v in m.values) {
        visit(v, m);
      }
    }
  }

  visit(body, null);
  return found ?? const [];
}

String? _str(Object? v) {
  if (v == null) return null;
  if (v is Map) return _str(v['name'] ?? v['label'] ?? v['value']);
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

Object? _pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m[k] != null) return m[k];
  }
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is num) {
    final ms = v > 1e11 ? v.toInt() : v.toInt() * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateTime(d.year, d.month, d.day);
  }
  final s = '$v'.trim();
  final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) {
    return DateTime(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }
  final dmy = RegExp(r'(\d{1,2})[/.](\d{1,2})[/.](\d{4})').firstMatch(s);
  if (dmy != null) {
    return DateTime(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  }
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Converts one ascent object of unknown exact shape to a [RawAscent].
RawAscent? parseAscentMap(Map<String, dynamic> m, String baseUrl) {
  final date = _parseDate(
    _pick(m, _dateKeys) ??
        m.entries
            .where((e) => e.key.toLowerCase().contains('date'))
            .firstOrNull
            ?.value,
  );
  if (date == null) return null;

  final route = m['route'] is Map
      ? (m['route'] as Map).cast<String, dynamic>()
      : null;
  final routeName = _str(
    route?['name'] ?? _pick(m, ['routeName', 'route', 'name']),
  );
  final grade = _str(
    _pick(m, ['grade', 'ascentGrade', 'gradeLabel']) ??
        route?['grade'] ??
        m['routeGrade'],
  );

  // Ancestors / location path: list of {id, name} from planet down to crag.
  final ancestors = <Map<String, dynamic>>[];
  // Logbook API: route.ancestors is {parent, TLC, country}.
  final ancMap = route?['ancestors'];
  Map<String, dynamic>? ancNode(String k) => ancMap is Map && ancMap[k] is Map
      ? (ancMap[k] as Map).cast<String, dynamic>()
      : null;
  final aParent = ancNode('parent'), aTlc = ancNode('TLC');
  final aCountry = ancNode('country');
  for (final k in ['ancestors', 'parents', 'location', 'path', 'crumbs']) {
    final v = m[k] ?? route?[k];
    if (v is List) {
      ancestors.addAll(
        v.whereType<Map>().map((e) => e.cast<String, dynamic>()),
      );
      break;
    }
  }
  final crag =
      _str(m['crag'] ?? m['cragName'] ?? route?['crag']) ??
      _str(aParent?['name']) ??
      (ancestors.length >= 2 ? _str(ancestors[ancestors.length - 1]) : null);
  final area =
      _str(m['area'] ?? m['areaName']) ??
      _str(aTlc?['name']) ??
      (ancestors.length >= 3 ? _str(ancestors[ancestors.length - 2]) : null);
  final country =
      _str(m['country'] ?? m['countryName']) ??
      _str(aCountry?['name']) ??
      (ancestors.length >= 2 ? _str(ancestors[1]) : null);

  final routeId = _str(
    route?['id'] ?? _pick(m, ['routeID', 'routeId', 'route_id', 'nodeID']),
  );
  final nodeIds = [
    ?routeId,
    for (final a in ancestors.reversed) ?_str(a['id']),
    ?_str(_pick(m, ['cragID', 'cragId', 'areaID', 'areaId'])),
  ];

  final id =
      _str(_pick(m, ['id', 'ascentID', 'ascentId'])) ??
      '${routeId ?? routeName}-${dayKey(date)}';
  final tick = m['tick'];
  final directCoords =
      findCoordinates(m) ??
      findCoordinates(aParent) ??
      findCoordinates(aTlc) ??
      findCoordinates(aCountry);
  return RawAscent(
    id: id,
    date: date,
    route: routeName ?? 'Unknown route',
    grade: grade,
    style: tick is Map
        ? _str(tick['label'] ?? tick['name'])
        : _str(_pick(m, ['tick', 'tickType', 'ascentType', 'style', 'type'])),
    crag: crag,
    area: area,
    country: country,
    url: routeId == null ? null : '$baseUrl/climbing/route/$routeId',
    nodeIds: nodeIds,
    lat: directCoords?.$1,
    lon: directCoords?.$2,
  );
}

/// Searches a JSON tree for a latitude/longitude pair.
(double, double)? findCoordinates(Object? body, [int depth = 0]) {
  if (depth > 6 || body == null) return null;
  double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
  bool ok(double? lat, double? lon) =>
      lat != null &&
      lon != null &&
      lat.abs() <= 90 &&
      lon.abs() <= 180 &&
      !(lat == 0 && lon == 0);
  if (body is Map) {
    final m = body.cast<String, dynamic>();
    final lat = n(_pick(m, ['lat', 'latitude', 'Lat']));
    final lon = n(_pick(m, ['lon', 'long', 'lng', 'longitude', 'Long']));
    if (ok(lat, lon)) return (lat!, lon!);
    // GeoJSON-ish {type: Point, coordinates: [lon, lat]}
    final coords = m['coordinates'];
    if (coords is List && coords.length >= 2 && coords.first is num) {
      final lo = n(coords[0]), la = n(coords[1]);
      if (ok(la, lo)) return (la!, lo!);
    }
    for (final k in [
      'geometry',
      'location',
      'point',
      'centroid',
      'geo',
      'data',
    ]) {
      final r = findCoordinates(m[k], depth + 1);
      if (r != null) return r;
    }
  } else if (body is List) {
    for (final e in body.take(5)) {
      final r = findCoordinates(e, depth + 1);
      if (r != null) return r;
    }
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
List<RawAscent> parseLogbookCsv(String text) {
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
  final cCragLink = col(['crag link']);
  final cAreaLink = col(['area link']);
  if (cDate < 0) throw const FormatException('CSV has no date column');

  String? at(List<String> r, int i) =>
      i < 0 || i >= r.length || r[i].trim().isEmpty ? null : r[i].trim();
  String? idFromLink(String? link) =>
      link == null ? null : RegExp(r'(\d{3,})/?$').firstMatch(link)?.group(1);

  final out = <RawAscent>[];
  for (final r in rows.skip(1)) {
    final date = _parseDate(at(r, cDate));
    if (date == null) continue;
    // Prefer the ascent grade, fall back to the route grade.
    final grade = at(r, cGrade) ?? at(r, col(['route grade']));
    out.add(
      RawAscent(
        id: at(r, cId) ?? '${out.length}',
        date: date,
        route: at(r, cRoute) ?? 'Unknown route',
        grade: grade,
        style: at(r, cStyle),
        crag: at(r, cCrag),
        area: at(r, cArea),
        country: at(r, cCountry),
        url: at(r, cRouteLink),
        nodeIds: [
          ?idFromLink(at(r, cRouteLink)),
          ?idFromLink(at(r, cCragLink)),
          ?idFromLink(at(r, cAreaLink)),
        ],
      ),
    );
  }
  return out;
}
