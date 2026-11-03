/// Grade tiers named after item rarities in games, from baseline gear to
/// the real prizes. Pure Dart, shared by the widgets and the tests.
library;

import 'grades.dart';

enum Rarity {
  common('Common'),
  uncommon('Uncommon'),
  rare('Rare'),
  epic('Epic'),
  legendary('Legendary');

  const Rarity(this.label);

  final String label;

  /// Lower bounds of [uncommon], [rare], [epic] and [legendary] on the
  /// grade scale of [Grades] (French for routes, Font for boulders).
  ///
  /// Routes: up to 5c+ is common, 6a-6c uncommon, 6c+-7b+ rare, 7c-8b epic
  /// and 8b+ upwards legendary. Boulders go by leading number: up to 4+ is
  /// common, the 5s uncommon, the 6s rare, the 7s epic and 8A upwards
  /// legendary.
  static const _routeCuts = [9.0, 14.0, 19.0, 24.0]; // 6a, 6c+, 7c, 8b+
  static const _boulderCuts = [3.0, 5.0, 11.0, 17.0]; // 5, 6A, 7A, 8A

  /// The tier of [grade], or null if it can't be read. [discipline] picks
  /// the ranges and how ambiguous grades are read.
  static Rarity? of(String? grade, {Discipline discipline = Discipline.route}) {
    final parsed = Grades.parse(
      grade,
      discipline: discipline == Discipline.boulder ? discipline : null,
    );
    // A grade on the other scale (a route written like a boulder grade)
    // can't be compared with these ranges.
    if (parsed == null || parsed.discipline != discipline) return null;
    final cuts = discipline == Discipline.boulder ? _boulderCuts : _routeCuts;
    var tier = 0;
    for (final cut in cuts) {
      if (parsed.score >= cut) tier++;
    }
    return values[tier];
  }

  /// The grades of this tier, for legends and tooltips.
  String range(Discipline discipline) =>
      (discipline == Discipline.boulder ? _boulderRanges : _routeRanges)[index];

  static const _routeRanges = [
    'up to 5c+',
    '6a – 6c',
    '6c+ – 7b+',
    '7c – 8b',
    '8b+ and up',
  ];
  static const _boulderRanges = [
    'up to 4+',
    '5 – 5+',
    '6A – 6C+',
    '7A – 7C+',
    '8A and up',
  ];
}
