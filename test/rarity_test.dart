import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/grades.dart';
import 'package:thecrag_at_home/models/rarity.dart';

Rarity? route(String g) => Rarity.of(g);
Rarity? boulder(String g) => Rarity.of(g, discipline: Discipline.boulder);

void main() {
  test('route tiers follow the leading number', () {
    expect(route('3'), Rarity.common);
    expect(route('4c'), Rarity.common);
    expect(route('5a'), Rarity.uncommon);
    expect(route('5c'), Rarity.uncommon);
    expect(route('5c+'), Rarity.uncommon);
    expect(route('6a'), Rarity.rare);
    expect(route('6c+'), Rarity.rare);
    expect(route('7a'), Rarity.epic);
    expect(route('7c+'), Rarity.epic);
    expect(route('8a'), Rarity.legendary);
    expect(route('9b'), Rarity.legendary);
  });

  test('boulder tiers', () {
    expect(boulder('4'), Rarity.common);
    expect(boulder('5+'), Rarity.common);
    expect(boulder('6A'), Rarity.uncommon);
    expect(boulder('6C'), Rarity.uncommon);
    expect(boulder('6C+'), Rarity.rare);
    expect(boulder('7A'), Rarity.rare);
    expect(boulder('7B+'), Rarity.rare);
    expect(boulder('7C'), Rarity.epic);
    expect(boulder('8B'), Rarity.epic);
    expect(boulder('8B+'), Rarity.legendary);
    expect(boulder('9A'), Rarity.legendary);
  });

  test('the same grade differs between routes and boulders', () {
    expect(route('7a'), Rarity.epic);
    expect(boulder('7A'), Rarity.rare);
    expect(boulder('6a'), Rarity.uncommon); // lowercase on a boulder is Font
  });

  test('other grade systems are placed by their French equivalent', () {
    expect(route('5.12a'), Rarity.epic); // YDS ~ 7a+
    expect(route('V4'), isNull); // a boulder grade on a route has no tier
  });

  test('unreadable or missing grades have no tier', () {
    expect(route(''), isNull);
    expect(Rarity.of(null), isNull);
    expect(route('A2'), isNull);
  });

  test('ranges are listed for both disciplines', () {
    expect(Rarity.epic.range(Discipline.route), '7a – 7c+');
    expect(Rarity.epic.range(Discipline.boulder), '7C – 8B');
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
    expect(a('7A', ClimbKind.boulder).rarity, Rarity.rare);
    expect(a('7a', ClimbKind.sport).rarity, Rarity.epic);
    expect(a('6a', ClimbKind.trad).rarity, Rarity.rare);
    expect(Ascent(id: 'x', date: DateTime(2024), route: 'x').rarity, isNull);
  });
}
