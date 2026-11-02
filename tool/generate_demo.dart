// Generates plausible fake ascents so the app has something to show before
// real data is fetched:  dart run tool/generate_demo.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:thecrag_at_home/models/ascent.dart';

void main() {
  final rnd = Random(42);
  const crags = [
    ('Frankenjura', 'Germany', 49.70, 11.33),
    ('Arco', 'Italy', 45.92, 10.88),
    ('Kalymnos', 'Greece', 36.98, 26.97),
    ('Siurana', 'Spain', 41.26, 0.93),
    ('Fontainebleau', 'France', 48.40, 2.70),
    ('Magic Wood', 'Switzerland', 46.50, 9.35),
    ('Gimmelwald', 'Switzerland', 46.55, 7.89),
    ('Grampians', 'Australia', -37.15, 142.45),
    ('Red River Gorge', 'USA', 37.78, -83.68),
  ];
  const routeGrades = [
    '5c',
    '6a',
    '6a+',
    '6b',
    '6b+',
    '6c',
    '6c+',
    '7a',
    '7a+',
    '7b',
  ];
  const boulderGrades = ['5+', '6A', '6A+', '6B', '6B+', '6C', '7A'];
  const styles = [
    'onsight',
    'flash',
    'redpoint',
    'redpoint',
    'attempt',
    'second',
  ];
  const words = [
    'Black',
    'Golden',
    'Hidden',
    'Silent',
    'Wild',
    'Crimson',
    'Lazy',
    'Fat',
    'Lost',
    'Dancing',
  ];
  const nouns = [
    'Dihedral',
    'Arete',
    'Pillar',
    'Roof',
    'Crack',
    'Slab',
    'Dragon',
    'Wall',
    'Edge',
    'Groove',
  ];

  final ascents = <Ascent>[];
  final today = DateTime.now();
  var day = DateTime(today.year - 3, 1, 1);
  var id = 1;
  while (day.isBefore(today)) {
    final weekend = day.weekday >= 6;
    if (rnd.nextDouble() < (weekend ? 0.45 : 0.08)) {
      // Mostly the home crag, sometimes a trip.
      final c = rnd.nextDouble() < 0.7
          ? crags[0]
          : crags[rnd.nextInt(crags.length)];
      final boulder = c.$1 == 'Fontainebleau' || c.$1 == 'Magic Wood';
      final n = 1 + rnd.nextInt(boulder ? 9 : 6);
      // Slow progression over the years.
      final progress =
          day.difference(DateTime(today.year - 3)).inDays / (365 * 3);
      for (var i = 0; i < n; i++) {
        final grades = boulder ? boulderGrades : routeGrades;
        final gi = (rnd.nextDouble() * grades.length * (0.55 + 0.45 * progress))
            .floor()
            .clamp(0, grades.length - 1);
        final sector = rnd.nextInt(4);
        ascents.add(
          Ascent(
            id: '${id++}',
            date: day,
            route:
                '${words[rnd.nextInt(words.length)]} ${nouns[rnd.nextInt(nouns.length)]}',
            grade: grades[gi],
            style: styles[rnd.nextInt(styles.length)],
            crag: '${c.$1} sector ${String.fromCharCode(65 + sector)}',
            area: c.$1,
            country: c.$2,
            lat: c.$3 + (sector - 1.5) * 0.02,
            lon: c.$4 + (sector - 1.5) * 0.03,
          ),
        );
      }
    }
    day = day.add(const Duration(days: 1));
  }
  final ds = AscentDataset(
    ascents: ascents,
    climber: 'Demo climber',
    demo: true,
    generated: DateTime.now().toUtc(),
  );
  File('assets/data/ascents.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(ds));
  stdout.writeln('Wrote ${ascents.length} demo ascents.');
}
