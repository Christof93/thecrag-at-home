import 'package:intl/intl.dart';

import '../models/ascent.dart';

final _dateFmt = DateFormat('EEE d MMM yyyy');

/// Plain-text tooltip describing one climbing day.
String describeDay(ClimbingDay day, {bool includeCrag = true}) {
  final b = StringBuffer(_dateFmt.format(day.date))
    ..write(' · ${day.count} ascent${day.count == 1 ? '' : 's'}');
  final route = day.hardestRoute;
  final boulder = day.hardestBoulder;
  if (route != null) b.write('\nHardest: ${route.grade}  ${route.route}');
  if (boulder != null) {
    b.write('\nHardest boulder: ${boulder.grade}  ${boulder.route}');
  }
  if (includeCrag && day.crags.isNotEmpty) {
    b.write('\n${day.crags.take(3).join(', ')}');
  }
  return b.toString();
}

/// Tooltip for a map dot that may stand for several days at the same spot.
String describeDays(List<ClimbingDay> days) {
  final sorted = [...days]..sort((a, b) => b.date.compareTo(a.date));
  final total = sorted.fold<int>(0, (s, d) => s + d.count);
  final lines = <String>[];
  final crags = sorted.expand((d) => d.crags).toSet().take(3).join(', ');
  if (crags.isNotEmpty) lines.add(crags);
  if (sorted.length > 1) lines.add('${sorted.length} days · $total ascents');
  const maxDays = 12;
  for (final d in sorted.take(maxDays)) {
    final h = d.hardest;
    lines.add(
      '${_dateFmt.format(d.date)} · ${d.count} asc.'
      '${h == null ? '' : ' · hardest ${h.grade}'}',
    );
  }
  if (sorted.length > maxDays) {
    lines.add('…and ${sorted.length - maxDays} more days');
  }
  return lines.join('\n');
}
