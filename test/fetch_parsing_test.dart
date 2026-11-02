import 'package:flutter_test/flutter_test.dart';

import '../tool/fetch_ascents.dart';

void main() {
  test('finds ascent rows as maps', () {
    final body = {
      'data': {
        'numberAscents': 1,
        'ascents': [
          {
            'id': 99,
            'date': '2024-06-01T10:00:00Z',
            'tick': 'onsight',
            'route': {'id': 123, 'name': 'Foo', 'grade': '6c'},
            'ancestors': [
              {'id': 1, 'name': 'World'},
              {'id': 2, 'name': 'Germany'},
              {'id': 3, 'name': 'Frankenjura'},
              {'id': 4, 'name': 'Walberla'},
            ],
          },
        ],
      },
    };
    final rows = findAscentRows(body);
    expect(rows, hasLength(1));
    final a = parseAscentMap(rows.first, 'https://x')!;
    expect(a.route, 'Foo');
    expect(a.grade, '6c');
    expect(a.style, 'onsight');
    expect(a.crag, 'Walberla');
    expect(a.country, 'Germany');
    expect(a.nodeIds.first, '123');
    expect(a.date, DateTime(2024, 6, 1));
  });

  test('finds ascent rows as arrays with field list', () {
    final body = {
      'data': {
        'fields': ['ascentID', 'date', 'routeName', 'grade'],
        'rows': [
          [1, '2023-01-02', 'Bar', '7a'],
        ],
      },
    };
    final a = parseAscentMap(findAscentRows(body).first, 'https://x')!;
    expect(a.route, 'Bar');
    expect(a.id, '1');
  });

  test('finds coordinates', () {
    expect(
      findCoordinates({
        'data': {'lat': 47.1, 'long': 8.2},
      }),
      (47.1, 8.2),
    );
    expect(
      findCoordinates({
        'geometry': {
          'type': 'Point',
          'coordinates': [8.2, 47.1],
        },
      }),
      (47.1, 8.2),
    );
    expect(findCoordinates({'lat': 0, 'lon': 0}), isNull);
  });

  test('parses logbook csv', () {
    const csv =
        'Ascent ID,Ascent Date,Route Name,Ascent Type,Route Grade,'
        'Crag Name,Crag Link,Country\n'
        '5,2022-03-04,"Hello, World",redpoint,6a+,Arco,'
        'https://www.thecrag.com/climbing/italy/arco/area/12345,Italy\n';
    final r = parseLogbookCsv(csv);
    expect(r.single.route, 'Hello, World');
    expect(r.single.grade, '6a+');
    expect(r.single.nodeIds, ['12345']);
  });
}
