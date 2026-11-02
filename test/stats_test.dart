import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/stats.dart';
import 'package:thecrag_at_home/widgets/year_chart.dart';

Ascent a(
  String date,
  String route, {
  String? grade,
  ClimbKind? kind,
  String? crag,
  String? country,
}) => Ascent(
  id: '$date$route',
  date: DateTime.parse(date),
  route: route,
  grade: grade,
  kind: kind,
  crag: crag,
  country: country,
);

void main() {
  group('daysPerYearByKind', () {
    test('counts each day once per kind and fills empty years', () {
      final years = daysPerYearByKind([
        a('2022-05-01', 'r1', kind: ClimbKind.sport),
        a('2022-05-01', 'r2', kind: ClimbKind.sport), // same day
        a('2022-05-01', 'b1', kind: ClimbKind.boulder), // both kinds
        a('2022-06-01', 'r3', kind: ClimbKind.sport),
        a('2024-01-10', 't1', kind: ClimbKind.trad),
      ]);
      expect(years.map((y) => y.year), [2022, 2023, 2024]);
      expect(years[0].daysOf(ClimbKind.sport), 2);
      expect(years[0].daysOf(ClimbKind.boulder), 1);
      expect(years[1].days, isEmpty);
      expect(years[2].daysOf(ClimbKind.trad), 1);
    });

    test('guesses the kind from the grade when it is missing', () {
      final years = daysPerYearByKind([
        a('2023-03-01', 'x', grade: '7A'), // Font => boulder
        a('2023-03-02', 'y', grade: '7a'), // French => sport
        a('2023-03-03', 'z'), // no grade => sport
      ]);
      expect(years.single.daysOf(ClimbKind.boulder), 1);
      expect(years.single.daysOf(ClimbKind.sport), 2);
    });

    test('is empty without ascents', () {
      expect(daysPerYearByKind(const []), isEmpty);
    });
  });

  group('mostVisitedCrags', () {
    test('ranks by days, then ascents, and separates countries', () {
      final crags = mostVisitedCrags([
        for (final d in ['2024-01-01', '2024-01-02', '2024-01-03'])
          a(d, 'x$d', crag: 'Chironico', country: 'Switzerland'),
        a('2024-02-01', 'p', crag: 'Arco', country: 'Italy'),
        a('2024-02-01', 'q', crag: 'Arco', country: 'Italy'),
        a('2024-02-01', 'r', crag: 'Arco', country: 'Italy'),
        a('2024-03-01', 's', crag: 'Arco', country: 'Italy'),
        a('2024-04-01', 'u', crag: 'Arco', country: 'Austria'), // other Arco
        Ascent(id: 'n', date: DateTime(2024, 5, 1), route: 'no crag'),
      ]);
      expect(crags.map((c) => (c.name, c.country, c.days, c.ascents)), [
        ('Chironico', 'Switzerland', 3, 3),
        ('Arco', 'Italy', 2, 4),
        ('Arco', 'Austria', 1, 1),
      ]);
    });

    test('respects the limit', () {
      final crags = mostVisitedCrags([
        for (var i = 0; i < 20; i++) a('2024-01-01', 'r$i', crag: 'Crag $i'),
      ], limit: 5);
      expect(crags, hasLength(5));
    });
  });

  test('niceStep gives about four gridlines', () {
    expect(DaysPerYearChart.niceStep(1), 1);
    expect(DaysPerYearChart.niceStep(18), 5);
    expect(DaysPerYearChart.niceStep(35), 10);
    expect(DaysPerYearChart.niceStep(120), 50);
  });
}
