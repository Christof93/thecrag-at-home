/// Aggregations behind the dashboard charts (pure Dart).
library;

import 'ascent.dart';

/// Number of days out in one calendar year, per kind of climbing.
///
/// A day with both sport routes and boulders counts once for each kind, so
/// the kinds of one year can add up to more than the days out that year.
class YearKindDays {
  YearKindDays(this.year, this.days);

  final int year;
  final Map<ClimbKind, int> days;

  int daysOf(ClimbKind kind) => days[kind] ?? 0;
}

/// Days out per year and kind, oldest year first, including years without
/// any climbing between the first and the last.
List<YearKindDays> daysPerYearByKind(Iterable<Ascent> ascents) {
  final seen = <int, Map<ClimbKind, Set<String>>>{};
  for (final a in ascents) {
    seen
        .putIfAbsent(a.date.year, () => {})
        .putIfAbsent(a.climbKind, () => {})
        .add(dayKey(a.date));
  }
  if (seen.isEmpty) return const [];
  final years = seen.keys.toList()..sort();
  return [
    for (var y = years.first; y <= years.last; y++)
      YearKindDays(y, {
        for (final e in (seen[y] ?? const {}).entries) e.key: e.value.length,
      }),
  ];
}

/// A route you have tried but never sent: every logged ascent of it is a
/// hang dog, working, attempt, retreat or similar.
class OpenProject {
  OpenProject(this.ascents);

  /// All logged ascents of the route, oldest first.
  final List<Ascent> ascents;

  Ascent get first => ascents.first;
  Ascent get last => ascents.last;

  String get route => first.route;
  String? get grade => last.grade ?? first.grade;
  String? get crag => first.crag ?? first.area;
  String? get country => first.country;
  ClimbKind get kind => first.climbKind;
  String? get url => last.url ?? first.url;
  DateTime get firstTried => first.date;
  DateTime get lastTried => last.date;

  /// How the route was last tried, e.g. `dog` or `working`.
  String? get lastStyle => last.style;

  /// Distinct days spent on it.
  int get sessions => {for (final a in ascents) dayKey(a.date)}.length;

  double? get gradeScore => last.parsedGrade?.score ?? first.parsedGrade?.score;
}

/// Routes tried but not sent, most recently tried first. Whether a route was
/// sent is judged over all ascents of it, whatever the period on screen.
List<OpenProject> openProjects(Iterable<Ascent> ascents) {
  final byRoute = <String, List<Ascent>>{};
  for (final a in ascents) {
    // Ascents of one route share an id; without ids fall back to name+crag.
    final key = a.routeId ?? '${a.route}\u0000${a.crag ?? a.area ?? ''}';
    byRoute.putIfAbsent(key, () => []).add(a);
  }
  final result = [
    for (final list in byRoute.values)
      if (list.every((a) => !a.isSend))
        OpenProject(list..sort((a, b) => a.date.compareTo(b.date))),
  ];
  result.sort((a, b) {
    final byDate = b.lastTried.compareTo(a.lastTried);
    return byDate != 0 ? byDate : a.route.compareTo(b.route);
  });
  return result;
}

/// Ascents with two or more logged pitches, and those pitches.
class MultipitchSummary {
  const MultipitchSummary(this.ascents, this.pitches);

  final int ascents;
  final int pitches;
}

MultipitchSummary multipitchSummary(Iterable<Ascent> ascents) {
  var count = 0, pitches = 0;
  for (final a in ascents.where((a) => a.isMultipitch)) {
    count++;
    pitches += a.pitches!;
  }
  return MultipitchSummary(count, pitches);
}

/// A crag (or area) and how often it was visited.
class CragVisits {
  CragVisits(this.name, this.country, this.days, this.ascents);

  final String name;
  final String? country;

  /// Distinct days with at least one ascent here.
  final int days;
  final int ascents;
}

/// The [limit] most visited crags, by days out, then by ascents.
List<CragVisits> mostVisitedCrags(Iterable<Ascent> ascents, {int limit = 8}) {
  final dayKeys = <String, Set<String>>{};
  final counts = <String, int>{};
  final names = <String, (String, String?)>{};
  for (final a in ascents) {
    final name = a.crag ?? a.area;
    if (name == null) continue;
    // The same crag name can exist in several countries.
    final key = '$name\u0000${a.country ?? ''}';
    names[key] = (name, a.country);
    dayKeys.putIfAbsent(key, () => {}).add(dayKey(a.date));
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final result = [
    for (final e in names.entries)
      CragVisits(
        e.value.$1,
        e.value.$2,
        dayKeys[e.key]!.length,
        counts[e.key]!,
      ),
  ];
  result.sort((a, b) {
    final byDays = b.days.compareTo(a.days);
    if (byDays != 0) return byDays;
    final byAscents = b.ascents.compareTo(a.ascents);
    return byAscents != 0 ? byAscents : a.name.compareTo(b.name);
  });
  return result.take(limit).toList();
}
