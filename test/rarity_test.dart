import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/grades.dart';
import 'package:thecrag_at_home/models/rarity.dart';

Rarity? route(String g) => Rarity.of(g);
Rarity? boulder(String g) => Rarity.of(g, discipline: Discipline.boulder);

void main() {
  test('route tiers: up to 5c+, 6a-6c, 6c+-7b+, 7c-8b, 8b+', () {
    expect(route('3'), Rarity.common);
    expect(route('4c'), Rarity.common);
    expect(route('5a'), Rarity.common);
    expect(route('5c+'), Rarity.common);
    expect(route('6a'), Rarity.uncommon);
    expect(route('6c'), Rarity.uncommon);
    expect(route('6c+'), Rarity.rare);
    expect(route('7a'), Rarity.rare);
    expect(route('7b+'), Rarity.rare);
    expect(route('7c'), Rarity.epic);
    expect(route('8b'), Rarity.epic);
    expect(route('8b+'), Rarity.legendary);
    expect(route('9b'), Rarity.legendary);
  });

  test('boulder tiers go by leading number: up to 4+, 5s, 6s, 7s, 8A+', () {
    expect(boulder('3'), Rarity.common);
    expect(boulder('4'), Rarity.common);
    expect(boulder('4+'), Rarity.common);
    expect(boulder('5'), Rarity.uncommon);
    expect(boulder('5+'), Rarity.uncommon);
    expect(boulder('6A'), Rarity.rare);
    expect(boulder('6C+'), Rarity.rare);
    expect(boulder('7A'), Rarity.epic);
    expect(boulder('7C+'), Rarity.epic);
    expect(boulder('8A'), Rarity.legendary);
    expect(boulder('9A'), Rarity.legendary);
  });

  test('the same grade differs between routes and boulders', () {
    expect(route('7a'), Rarity.rare);
    expect(boulder('7A'), Rarity.epic);
    expect(boulder('6a'), Rarity.rare); // lowercase on a boulder is Font
  });

  test('other grade systems are placed by their French equivalent', () {
    expect(route('5.12a'), Rarity.rare); // YDS ~ 7a+
    expect(route('V4'), isNull); // a boulder grade on a route has no tier
  });

  test('unreadable or missing grades have no tier', () {
    expect(route(''), isNull);
    expect(Rarity.of(null), isNull);
    expect(route('A2'), isNull);
  });

  test('ranges are listed for both disciplines', () {
    expect(Rarity.epic.range(Discipline.route), '7c – 8b');
    expect(Rarity.epic.range(Discipline.boulder), '7A – 7C+');
    for (final r in Rarity.values) {
      expect(r.range(Discipline.route), isNotEmpty);
      expect(r.range(Discipline.boulder), isNotEmpty);
    }
  });

  test('an ascent is judged on its own scale', () {
    Ascent a(String grade, ClimbKind kind) => Ascent(
      id: grade,
      date: DateTime(2024),
      route: grade,
      grade: grade,
      kind: kind,
    );
    expect(a('7A', ClimbKind.boulder).rarity, Rarity.epic);
    expect(a('7a', ClimbKind.sport).rarity, Rarity.rare);
    expect(a('6a', ClimbKind.trad).rarity, Rarity.uncommon);
    expect(Ascent(id: 'x', date: DateTime(2024), route: 'x').rarity, isNull);
  });
}
