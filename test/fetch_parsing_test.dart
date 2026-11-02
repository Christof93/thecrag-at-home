import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/models/grades.dart';

import '../tool/fetch_ascents.dart';

/// Trimmed `GET /api/logbook/ascents` response (shape as returned by the API).
Map<String, dynamic> response({
  List<Map<String, dynamic>>? ascents,
  int? total,
  int page = 1,
}) {
  final rows = ascents ?? [sportAscent, boulderAscent];
  return {
    'data': {
      'account': {'name': 'chrible', 'login': 'chrible93', 'ascentCount': 2},
      'ascents': rows,
      'numberAscents': total ?? rows.length,
      'page': '$page',
      'perPage': 250,
    },
  };
}

final sportAscent = <String, dynamic>{
  'id': 1408388505,
  'epoch': 1606786729,
  'date': '2017-08-22T00:00:00Z',
  'logDate': '2017-08-22T22:07:33Z',
  'grade': '7a',
  'gradeSystem': 'FR',
  'markdown': 'private note',
  'tick': {'label': 'tick', 'name': 'Tick'},
  'type': 'ascent',
  'route': {
    'id': 414461610,
    'name': 'Captain Jack Sparrow',
    'grade': '6c+',
    'style': 'Sport',
    'urlAncestorStub': 'switzerland/alpen/glarner-alpen',
    'ancestors': {
      'TLC': {
        'id': 414459441,
        'name': 'Nordgalerie',
        'geometry': [9.131688, 47.125066],
      },
      'parent': {
        'id': 414460020,
        'name': 'Hauptwand',
        'geometry': [9.122874, 47.125524],
      },
      'country': {
        'id': 11747203,
        'name': 'Switzerland',
        'geometry': [8.24285, 46.800005],
      },
    },
  },
};

final boulderAscent = <String, dynamic>{
  'id': 2,
  'epoch': 1700000000,
  'logDate': '2023-03-04T18:00:00Z',
  'tick': {'label': 'flash', 'name': 'Flash'},
  'route': {
    'id': 7,
    'name': 'Dreamtime',
    'grade': '5+',
    'style': 'Boulder',
    'ancestors': {
      'TLC': {
        'id': 8,
        'name': 'Chironico',
        'geometry': [8.84, 46.43],
      },
      'parent': {'id': 8, 'name': 'Chironico'},
      'country': {'id': 11747203, 'name': 'Switzerland'},
    },
  },
};

class FakeApi extends LogbookApi {
  FakeApi(this.pages) : super(baseUrl: 'https://x', apiKey: 'k');

  /// Responses by `since` value (null = full download), then by page.
  final Map<int?, List<Map<String, dynamic>>> pages;
  final calls = <(int, int?)>[];

  @override
  Future<LogbookPage> fetchPage(int page, {int? since}) async {
    calls.add((page, since));
    return LogbookPage.fromJson(pages[since]![page - 1]);
  }
}

void main() {
  test('parses a logbook page', () {
    final p = LogbookPage.fromJson(response());
    expect(p.ascents, hasLength(2));
    expect(p.page, 1); // given as a string by the API
    expect(p.perPage, 250);
    expect(p.climber, 'chrible');
    expect(p.maxEpoch, 1700000000);
  });

  test('parses a sport ascent', () {
    final a = parseLogbookAscent(sportAscent, 'https://www.thecrag.com')!;
    expect(a.id, '1408388505');
    expect(a.date, DateTime(2017, 8, 22));
    expect(a.route, 'Captain Jack Sparrow');
    expect(a.grade, '7a'); // ascent grade wins over the route grade
    expect(a.style, 'tick');
    expect(a.crag, 'Nordgalerie');
    expect(a.area, 'Hauptwand');
    expect(a.country, 'Switzerland');
    expect((a.lat, a.lon), (47.125524, 9.122874)); // sector, [lon, lat]
    expect(a.discipline, Discipline.route);
    expect(
      a.url,
      'https://www.thecrag.com/climbing/switzerland/alpen/glarner-alpen'
      '/route/414461610',
    );
    expect(jsonEncode(a.toJson()), isNot(contains('private note')));
  });

  test('parses a boulder ascent without date', () {
    final a = parseLogbookAscent(boulderAscent, 'https://x')!;
    expect(a.date, DateTime(2023, 3, 4)); // falls back to logDate
    expect(a.grade, '5+');
    expect(a.crag, 'Chironico');
    expect(a.area, isNull);
    expect((a.lat, a.lon), (46.43, 8.84)); // crag, sector has no geometry
    expect(a.discipline, Discipline.boulder);
    expect(a.parsedGrade!.discipline, Discipline.boulder); // Font, not UIAA
  });

  group('syncLogbook', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('sync'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('full download, then incremental, then weekly full', () async {
      final cache = File('${tmp.path}/cache.json');
      final t0 = DateTime.utc(2026, 11, 1);

      // First run pages through everything.
      final page1 = [
        for (var i = 0; i < 250; i++)
          {...sportAscent, 'id': 1000 + i, 'epoch': i},
      ];
      final api = FakeApi({
        null: [
          response(ascents: page1, total: 251),
          response(ascents: [boulderAscent], total: 251, page: 2),
        ],
      });
      var r = await syncLogbook(api, cache, now: t0);
      expect(r.ascents, hasLength(251));
      expect(r.climber, 'chrible');
      expect(api.calls, [(1, null), (2, null)]);

      // Next day only changes since the highest epoch are requested.
      final changed = {...boulderAscent, 'epoch': 1800000000, 'grade': '6A'};
      final api2 = FakeApi({
        1700000000: [
          response(ascents: [changed]),
        ],
      });
      r = await syncLogbook(api2, cache, now: t0.add(const Duration(days: 1)));
      expect(api2.calls, [(1, 1700000000)]);
      expect(r.ascents, hasLength(251));
      expect(r.ascents.firstWhere((a) => a.id == '2').grade, '6A');

      // A week after the full download, everything is fetched again so
      // deleted ascents disappear.
      final api3 = FakeApi({
        null: [
          response(ascents: [sportAscent]),
        ],
      });
      r = await syncLogbook(api3, cache, now: t0.add(const Duration(days: 8)));
      expect(api3.calls, [(1, null)]);
      expect(r.ascents, hasLength(1));
    });
  });

  test('parses logbook csv', () {
    const csv =
        'Ascent ID,Ascent Date,Route Name,Ascent Type,Route Grade,'
        'Crag Name,Country\n'
        '5,2022-03-04,"Hello, World",redpoint,6a+,Arco,Italy\n';
    final r = parseLogbookCsv(csv);
    expect(r.single.route, 'Hello, World');
    expect(r.single.grade, '6a+');
    expect(r.single.crag, 'Arco');
  });
}
