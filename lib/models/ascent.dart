/// Normalised ascent record used by the app.
///
/// This file is pure Dart (no Flutter imports) so it can be shared with the
/// command line data fetcher in `tool/`.
library;

import 'grades.dart';

class Ascent {
  Ascent({
    required this.id,
    required this.date,
    required this.route,
    this.grade,
    this.style,
    this.crag,
    this.area,
    this.country,
    this.lat,
    this.lon,
    this.url,
    this.discipline,
  });

  final String id;

  /// Calendar day of the ascent (time component is always midnight, local).
  final DateTime date;
  final String route;
  final String? grade;

  /// theCrag "ascent type", e.g. onsight, flash, redpoint, attempt...
  final String? style;
  final String? crag;
  final String? area;
  final String? country;
  final double? lat;
  final double? lon;
  final String? url;

  /// Whether the climb is a boulder or a route, when known. Disambiguates
  /// grades like `5+` (Font on a boulder, UIAA on a route).
  final Discipline? discipline;

  bool get hasLocation => lat != null && lon != null;

  /// Whether this ascent counts as a completed climb (used for "hardest").
  bool get isSend => !nonSendStyles.contains(style?.toLowerCase().trim());

  ParsedGrade? get parsedGrade => Grades.parse(grade, discipline: discipline);

  static const nonSendStyles = {
    'attempt',
    'working',
    'retreat',
    'target',
    'mark',
    'hang dog',
    'hangdog',
    'dog',
    'dnf',
    'ghost',
  };

  factory Ascent.fromJson(Map<String, dynamic> j) => Ascent(
    id: '${j['id']}',
    date: DateTime.parse(j['date'] as String),
    route: (j['route'] as String?) ?? 'Unknown route',
    grade: j['grade'] as String?,
    style: j['style'] as String?,
    crag: j['crag'] as String?,
    area: j['area'] as String?,
    country: j['country'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    url: j['url'] as String?,
    discipline: switch (j['discipline']) {
      'boulder' => Discipline.boulder,
      'route' => Discipline.route,
      _ => null,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dayKey(date),
    'route': route,
    if (grade != null) 'grade': grade,
    if (style != null) 'style': style,
    if (crag != null) 'crag': crag,
    if (area != null) 'area': area,
    if (country != null) 'country': country,
    if (lat != null) 'lat': lat,
    if (lon != null) 'lon': lon,
    if (url != null) 'url': url,
    if (discipline != null) 'discipline': discipline!.name,
  };
}

/// `YYYY-MM-DD` key for a date.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The file format written by `tool/fetch_ascents.dart` and read by the app.
class AscentDataset {
  AscentDataset({
    required this.ascents,
    this.climber,
    this.generated,
    this.demo = false,
  });

  final List<Ascent> ascents;
  final String? climber;
  final DateTime? generated;
  final bool demo;

  factory AscentDataset.fromJson(Map<String, dynamic> j) => AscentDataset(
    climber: j['climber'] as String?,
    generated: j['generated'] == null
        ? null
        : DateTime.tryParse(j['generated'] as String),
    demo: j['demo'] == true,
    ascents: [
      for (final a in (j['ascents'] as List? ?? const []))
        Ascent.fromJson((a as Map).cast<String, dynamic>()),
    ]..sort((a, b) => a.date.compareTo(b.date)),
  );

  Map<String, dynamic> toJson() => {
    if (climber != null) 'climber': climber,
    'generated': (generated ?? DateTime.now().toUtc()).toIso8601String(),
    if (demo) 'demo': true,
    'ascents': [for (final a in ascents) a.toJson()],
  };
}

/// All ascents of one calendar day.
class ClimbingDay {
  ClimbingDay(this.date, this.ascents);

  final DateTime date;
  final List<Ascent> ascents;

  int get count => ascents.length;

  /// Hardest sent route (non-boulder) of the day.
  Ascent? get hardestRoute => _hardest(Discipline.route);

  /// Hardest sent boulder of the day.
  Ascent? get hardestBoulder => _hardest(Discipline.boulder);

  /// Hardest send of the day, routes preferred over boulders.
  Ascent? get hardest => hardestRoute ?? hardestBoulder;

  Ascent? _hardest(Discipline d) {
    Ascent? best;
    double bestScore = double.negativeInfinity;
    for (final a in ascents) {
      final g = a.parsedGrade;
      if (!a.isSend || g == null || g.discipline != d) continue;
      if (g.score > bestScore) {
        best = a;
        bestScore = g.score;
      }
    }
    return best;
  }

  /// Mean position of the day's ascents that have coordinates.
  (double lat, double lon)? get position {
    final located = ascents.where((a) => a.hasLocation).toList();
    if (located.isEmpty) return null;
    final lat = located.map((a) => a.lat!).reduce((a, b) => a + b);
    final lon = located.map((a) => a.lon!).reduce((a, b) => a + b);
    return (lat / located.length, lon / located.length);
  }

  /// Distinct crag names visited, most ascents first.
  List<String> get crags {
    final counts = <String, int>{};
    for (final a in ascents) {
      final c = a.crag ?? a.area;
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  /// Group ascents into days (sorted ascending).
  static List<ClimbingDay> group(Iterable<Ascent> ascents) {
    final map = <String, List<Ascent>>{};
    for (final a in ascents) {
      map.putIfAbsent(dayKey(a.date), () => []).add(a);
    }
    final days = [
      for (final e in map.entries) ClimbingDay(e.value.first.date, e.value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }
}
