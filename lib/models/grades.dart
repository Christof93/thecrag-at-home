/// Grade parsing and normalisation across common grading systems.
///
/// Every route grade is mapped onto a single numeric scale where the
/// French sport grades are evenly spaced (6a = 10, 6a+ = 11, ... 9c = 33).
/// Boulder grades use their own scale based on Fontainebleau grades. The
/// conversions are approximate, which is fine for picking the "hardest"
/// climb of a day.
library;

enum Discipline { route, boulder }

class ParsedGrade {
  const ParsedGrade(this.raw, this.score, this.discipline);
  final String raw;
  final double score;
  final Discipline discipline;
}

class Grades {
  Grades._();

  static const french = [
    '1', '2', '3', '4a', '4b', '4c', '5a', '5b', '5c', // 0..8
    '6a', '6a+', '6b', '6b+', '6c', '6c+', // 9..14
    '7a', '7a+', '7b', '7b+', '7c', '7c+', // 15..20
    '8a', '8a+', '8b', '8b+', '8c', '8c+', // 21..26
    '9a', '9a+', '9b', '9b+', '9c', // 27..31
  ];

  static const font = [
    '3', '4', '4+', '5', '5+', '6A', '6A+', '6B', '6B+', '6C', '6C+', //
    '7A', '7A+', '7B', '7B+', '7C', '7C+', '8A', '8A+', '8B', '8B+', //
    '8C', '8C+', '9A',
  ];

  static int _f(String g) => french.indexOf(g);
  static int _fb(String g) => font.indexOf(g);

  // YDS 5.x -> French index.
  static final Map<String, double> _yds = {
    '5.0': 1, '5.1': 1.5, '5.2': 2, '5.3': 2.5, '5.4': 3, //
    '5.5': 4, '5.6': 5, '5.7': 6, '5.8': 7, '5.9': 8,
    '5.10a': 9, '5.10b': 9.5, '5.10c': 10, '5.10d': 11,
    '5.11a': 12, '5.11b': 13, '5.11c': 14, '5.11d': 15,
    '5.12a': 16, '5.12b': 17, '5.12c': 18, '5.12d': 19,
    '5.13a': 20, '5.13b': 21, '5.13c': 22, '5.13d': 23,
    '5.14a': 24, '5.14b': 25, '5.14c': 26, '5.14d': 27,
    '5.15a': 28, '5.15b': 29, '5.15c': 30, '5.15d': 31,
  };

  // UIAA (arabic numerals, with +/-) -> French index.
  static final Map<String, double> _uiaa = {
    '3': 2,
    '4': 3,
    '5-': 3.5,
    '5': 4,
    '5+': 5,
    '6-': 5.5,
    '6': 6.5,
    '6+': 7.5,
    '7-': 8,
    '7': 9,
    '7+': 10,
    '8-': 11.5,
    '8': 13,
    '8+': 14.5,
    '9-': 16,
    '9': 17.5,
    '9+': 19,
    '10-': 20.5,
    '10': 22,
    '10+': 23,
    '11-': 24.5,
    '11': 26,
    '11+': 27,
    '12-': 28,
    '12': 29.5,
  };

  // Ewbank (AU/NZ) -> French index.
  static double? _ewbank(int n) {
    if (n < 10 || n > 39) return null;
    const table = {
      10: 2,
      11: 2.5,
      12: 3,
      13: 3.5,
      14: 4,
      15: 4.5,
      16: 5,
      17: 6,
      18: 7,
      19: 8,
      20: 9,
      21: 10,
      22: 11,
      23: 12.5,
      24: 15,
      25: 16,
      26: 17,
      27: 18.5,
      28: 20,
      29: 21,
      30: 22,
      31: 23,
      32: 24,
      33: 25,
      34: 26,
      35: 27,
      36: 28,
      37: 29,
      38: 30,
      39: 31,
    };
    return table[n]?.toDouble();
  }

  // Hueco V-scale -> Font index.
  static double? _vScale(String v) {
    if (v == 'B' || v == 'b') return 1;
    final n = int.tryParse(v);
    if (n == null || n < 0 || n > 17) return null;
    const table = [
      2,
      4,
      5,
      6,
      7.5,
      9.5,
      11,
      12,
      13.5,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
    ];
    return table[n].toDouble();
  }

  static final _romanToInt = {
    'I': 1,
    'II': 2,
    'III': 3,
    'IV': 4,
    'V': 5,
    'VI': 6,
    'VII': 7,
    'VIII': 8,
    'IX': 9,
    'X': 10,
    'XI': 11,
    'XII': 12,
  };

  // Low Font grades with letters, folded onto the coarse low end of [font].
  static const _fontLow = {
    '3+': '3', '4A': '4', '4A+': '4', '4B': '4', '4B+': '4+', '4C': '4+', //
    '4C+': '4+', '5A': '5', '5A+': '5', '5B': '5', '5B+': '5+', '5C': '5+',
    '5C+': '5+',
  };

  /// Parses a Font grade such as `6B+`, `5+` or `4c`.
  static ParsedGrade? _parseFont(String input, String g) {
    final m = RegExp(r'^(?:[Ff][Bb]?)?([3-9][ABCabc]?\+?)').firstMatch(g);
    if (m == null) return null;
    var f = m.group(1)!.toUpperCase();
    f = _fontLow[f] ?? f;
    final i = _fb(f);
    return i < 0 ? null : ParsedGrade(input, i.toDouble(), Discipline.boulder);
  }

  /// Parse a grade string. Returns null if it is not recognised.
  ///
  /// [discipline] is a hint for grades that are ambiguous on their own: a
  /// boulder graded `5+` or `6a` is read as Font rather than UIAA / French.
  static ParsedGrade? parse(String? input, {Discipline? discipline}) {
    if (input == null) return null;
    var g = input.trim();
    if (g.isEmpty) return null;
    // theCrag sometimes gives slash grades ("6b/+", "V4/5"): use first part.
    // Keep "5.10a/b" style by only splitting when there's a space or after
    // a full grade token.
    g = g.split(RegExp(r'\s+')).first;

    if (discipline == Discipline.boulder) {
      final f = _parseFont(input, g);
      if (f != null) return f;
    }

    // V-scale: V4, V4/5, V4-5, VB
    final v = RegExp(r'^[Vv](B|\d{1,2})').firstMatch(g);
    if (v != null) {
      final s = _vScale(v.group(1)!);
      if (s != null) return ParsedGrade(input, s, Discipline.boulder);
    }

    // Font: f6A / Fb7A+ / 7A+ (uppercase letter => boulder)
    final fb = RegExp(r'^(?:[Ff][Bb]?)?([3-9][ABC]\+?)$').firstMatch(g);
    if (fb != null) {
      final f = _parseFont(input, g);
      if (f != null) return f;
    }

    // YDS: 5.10a, 5.11, 5.12b/c
    final y = RegExp(r'^(5\.\d{1,2})([a-d])?').firstMatch(g);
    if (y != null) {
      final base = y.group(1)!;
      final letter = y.group(2);
      double? s = _yds['$base${letter ?? ''}'];
      if (s == null && letter == null) {
        // 5.11 without letter: take the "b" value.
        s = _yds['${base}b'];
      }
      if (s != null) return ParsedGrade(input, s, Discipline.route);
    }

    // French: 6a, 6a+, 7b/+, 5c
    final fr = RegExp(r'^[Ff]?([1-9][abc]?\+?)').firstMatch(g);
    if (fr != null && RegExp(r'[abc]').hasMatch(fr.group(1)!)) {
      final i = _f(fr.group(1)!);
      if (i >= 0) return ParsedGrade(input, i.toDouble(), Discipline.route);
    }

    // UIAA roman: VI+, VII-, IX
    final r = RegExp(r'^([IVX]+)([+-]?)$').firstMatch(g);
    if (r != null) {
      final n = _romanToInt[r.group(1)!];
      if (n != null) {
        final s = _uiaa['$n${r.group(2)}'] ?? _uiaa['$n'];
        if (s != null) return ParsedGrade(input, s, Discipline.route);
      }
    }

    // Plain integer: Ewbank (>= 10) or UIAA (< 13 with +/-).
    final num = RegExp(r'^(\d{1,2})([+-]?)').firstMatch(g);
    if (num != null) {
      final n = int.parse(num.group(1)!);
      final mod = num.group(2)!;
      if (mod.isEmpty && n >= 14) {
        final s = _ewbank(n);
        if (s != null) return ParsedGrade(input, s, Discipline.route);
      }
      final s = _uiaa['$n$mod'] ?? _uiaa['$n'];
      if (s != null) return ParsedGrade(input, s, Discipline.route);
      final e = _ewbank(n);
      if (e != null) return ParsedGrade(input, e, Discipline.route);
    }
    return null;
  }
}
