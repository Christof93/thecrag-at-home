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

  test('multipitchSummary counts ascents with two or more logged pitches', () {
    Ascent p(String id, int? pitches) =>
        Ascent(id: id, date: DateTime(2024, 1, 1), route: id, pitches: pitches);
    final s = multipitchSummary([
      p('a', 6),
      p('b', 2),
      p('c', 1),
      p('d', null),
    ]);
    expect(s.ascents, 2); // a single logged pitch is a single-pitch route
    expect(s.pitches, 8);
    expect(p('x', 3).isMultipitch, isTrue);
    expect(p('x', 1).isMultipitch, isFalse);
    expect(multipitchSummary(const []).ascents, 0);
  });

  group('openProjects', () {
    Ascent t(
      String date,
      String route,
      String style, {
      String? id,
      String? crag,
      String? grade,
    }) => Ascent(
      id: '$route$date',
      date: DateTime.parse(date),
      route: route,
      style: style,
      routeId: id,
      crag: crag,
      grade: grade,
    );

    test('lists routes that were never sent, most recently tried first', () {
      final p = openProjects([
        t('2024-05-01', 'Old project', 'dog', id: '1', grade: '7a'),
        t('2025-06-01', 'Sent later', 'working', id: '2'),
        t('2025-07-01', 'Sent later', 'redpoint', id: '2'),
        t('2025-08-01', 'New project', 'attempt', id: '3', grade: '7b'),
        t('2025-08-01', 'Plain tick', 'tick', id: '4'),
        t('2025-09-01', 'Old project', 'working', id: '1'),
        t('2025-09-01', 'Latest try', 'try', id: '5'),
      ]);
      expect(p.map((x) => x.route), [
        'Latest try',
        'Old project',
        'New project',
      ]);
      final old = p[1];
      expect(old.sessions, 2);
      expect(old.firstTried, DateTime(2024, 5, 1));
      expect(old.lastTried, DateTime(2025, 9, 1));
      expect(old.lastStyle, 'working');
      expect(old.grade, '7a');
    });

    test('a send of the route anywhere counts, whatever its date', () {
      expect(
        openProjects([
          t('2020-01-01', 'A', 'redpoint', id: '1'),
          t('2024-01-01', 'A', 'dog', id: '1'), // later dog after a send
        ]),
        isEmpty,
      );
    });

    test('similar routes with other ids stay separate', () {
      final p = openProjects([
        t('2024-01-01', 'Same name', 'dog', id: '1'),
        t('2024-01-02', 'Same name', 'redpoint', id: '2'),
      ]);
      expect(p.map((x) => x.route), ['Same name']);
    });

    test('without route ids, name and crag identify a route', () {
      final p = openProjects([
        t('2024-01-01', 'X', 'dog', crag: 'A'),
        t('2024-01-02', 'X', 'redpoint', crag: 'B'), // another X, sent
        t('2024-01-03', 'X', 'try', crag: 'A'),
      ]);
      expect(p, hasLength(1));
      expect(p.single.crag, 'A');
      expect(p.single.sessions, 2);
    });

    test('stage is the furthest reached on any ascent', () {
      ProjectStage stage(List<String> styles) => openProjects([
        for (var i = 0; i < styles.length; i++)
          t('2024-01-0${i + 1}', 'R', styles[i], id: '1'),
      ]).single.stage;
      expect(stage(['dog']), ProjectStage.hangDog);
      expect(stage(['hang dog']), ProjectStage.hangDog);
      expect(stage(['working']), ProjectStage.projected);
      expect(stage(['projected']), ProjectStage.projected);
      expect(stage(['attempt']), ProjectStage.tried);
      expect(stage(['retreat']), ProjectStage.tried);
      expect(stage(['try']), ProjectStage.tried);
      // Several tries, then it was worked, then hang dogged.
      expect(stage(['attempt', 'working']), ProjectStage.projected);
      expect(stage(['attempt', 'working', 'dog']), ProjectStage.hangDog);
      expect(stage(['dog', 'attempt']), ProjectStage.hangDog);
    });

    test('also knows try and projected', () {
      expect(
        openProjects([
          t('2024-01-01', 'A', 'try', id: '1'),
          t('2024-01-01', 'B', 'projected', id: '2'),
        ]),
        hasLength(2),
      );
    });
  });

  test('niceStep gives about four gridlines', () {
    expect(DaysPerYearChart.niceStep(1), 1);
    expect(DaysPerYearChart.niceStep(18), 5);
    expect(DaysPerYearChart.niceStep(35), 10);
    expect(DaysPerYearChart.niceStep(120), 50);
  });
}
