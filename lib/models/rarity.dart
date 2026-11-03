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
  /// Routes by their leading number: up to 4c is common, the 5s uncommon,
  /// the 6s rare, the 7s epic and 8a upwards legendary. Boulders: up to 5+,
  /// 6A-6C, 6C+-7B+, 7C-8B and 8B+ upwards.
  static const _routeCuts = [6.0, 9.0, 15.0, 21.0]; // 5a, 6a, 7a, 8a
  static const _boulderCuts = [5.0, 10.0, 15.0, 20.0]; // 6A, 6C+, 7C, 8B+

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
    'up to 4c',
    '5a – 5c+',
    '6a – 6c+',
    '7a – 7c+',
    '8a and up',
  ];
  static const _boulderRanges = [
    'up to 5+',
    '6A – 6C',
    '6C+ – 7B+',
    '7C – 8B',
    '8B+ and up',
  ];
}
