import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ascent.dart';
import '../models/grades.dart';
import 'day_tooltip.dart';

enum GridColorMode { count, grade }

/// A GitHub-style contribution calendar: one column per week, one row per
/// weekday (Mon..Sun), each cell coloured by ascents (or hardest grade).
class ContributionGrid extends StatelessWidget {
  const ContributionGrid({
    super.key,
    required this.days,
    required this.start,
    required this.end,
    this.colorMode = GridColorMode.count,
    this.cellSize = 13,
    this.gap = 3,
    this.onDayTap,
  });

  final List<ClimbingDay> days;
  final DateTime start;
  final DateTime end;
  final GridColorMode colorMode;
  final double cellSize;
  final double gap;
  final ValueChanged<ClimbingDay>? onDayTap;

  static const _labelWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byDay = {for (final d in days) dayKey(d.date): d};

    // Align the first column to Monday.
    final first = DateTime(
      start.year,
      start.month,
      start.day,
    ).subtract(Duration(days: start.weekday - 1));
    final last = DateTime(end.year, end.month, end.day);
    final weeks = (last.difference(first).inDays ~/ 7) + 1;

    final maxCount = days.isEmpty
        ? 1
        : days.map((d) => d.count).reduce(math.max);
    final gradeScores = [
      for (final d in days)
        if (d.hardestRoute?.parsedGrade case final g?) g.score,
    ];
    final minGrade = gradeScores.isEmpty ? 0.0 : gradeScores.reduce(math.min);
    final maxGrade = gradeScores.isEmpty ? 1.0 : gradeScores.reduce(math.max);

    final step = cellSize + gap;
    final monthFmt = DateFormat('MMM');

    Color colorFor(ClimbingDay? d) {
      final empty = scheme.surfaceContainerHighest;
      if (d == null) return empty;
      final double t;
      if (colorMode == GridColorMode.count) {
        t = maxCount <= 1 ? 1 : (d.count - 1) / (maxCount - 1);
      } else {
        final g = d.hardestRoute?.parsedGrade ?? d.hardest?.parsedGrade;
        if (g == null || g.discipline != Discipline.route) {
          t = 0;
        } else {
          t = maxGrade == minGrade
              ? 1
              : (g.score - minGrade) / (maxGrade - minGrade);
        }
      }
      return levelColor(scheme, t);
    }

    final columns = <Widget>[];
    final monthLabels = <Widget>[];
    int? lastMonth;
    for (var w = 0; w < weeks; w++) {
      final weekStart = first.add(Duration(days: w * 7));
      // Month label above the first week that contains the 1st..7th.
      final labelDay = weekStart.add(const Duration(days: 6));
      if (labelDay.month != lastMonth && labelDay.day <= 7) {
        lastMonth = labelDay.month;
        monthLabels.add(
          Positioned(
            left: w * step,
            child: Text(
              monthFmt.format(labelDay),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        );
      }
      final cells = <Widget>[];
      for (var wd = 0; wd < 7; wd++) {
        final date = weekStart.add(Duration(days: wd));
        final inRange =
            !date.isBefore(DateTime(start.year, start.month, start.day)) &&
            !date.isAfter(last);
        final day = byDay[dayKey(date)];
        Widget cell = Container(
          width: cellSize,
          height: cellSize,
          margin: EdgeInsets.only(bottom: gap),
          decoration: BoxDecoration(
            color: inRange ? colorFor(day) : Colors.transparent,
            borderRadius: BorderRadius.circular(2.5),
          ),
        );
        if (inRange) {
          cell = Tooltip(
            message: day == null
                ? 'No ascents on ${DateFormat('EEE d MMM yyyy').format(date)}'
                : describeDay(day),
            waitDuration: const Duration(milliseconds: 100),
            triggerMode: TooltipTriggerMode.tap,
            child: day != null && onDayTap != null
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onDayTap!(day),
                      child: cell,
                    ),
                  )
                : cell,
          );
        }
        cells.add(cell);
      }
      columns.add(
        Padding(
          padding: EdgeInsets.only(right: gap),
          child: Column(children: cells),
        ),
      );
    }

    final weekdayLabels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var wd = 0; wd < 7; wd++)
          SizedBox(
            height: step,
            width: _labelWidth,
            child: wd.isEven
                ? null
                : Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
          ),
      ],
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // show most recent weeks first on narrow screens
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _labelWidth),
            child: SizedBox(
              height: 16,
              width: weeks * step,
              child: Stack(children: monthLabels),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [weekdayLabels, ...columns],
          ),
        ],
      ),
    );
  }

  // Mustard ramps, more intense = stronger. On a light surface the strongest
  // level is the darkest; on a dark surface it is the brightest.
  static const _lightLevels = [
    Color(0xFFFFE680),
    Color(0xFFFFDB58),
    Color(0xFFD9A800),
    Color(0xFF8A6A00),
  ];
  static const _darkLevels = [
    Color(0xFF4F4414),
    Color(0xFF8C7420),
    Color(0xFFD1AE2F),
    Color(0xFFFFDB58),
  ];

  /// Colour for intensity t in [0, 1] using 4 discrete levels like GitHub.
  static Color levelColor(ColorScheme scheme, double t) {
    final levels = scheme.brightness == Brightness.dark
        ? _darkLevels
        : _lightLevels;
    return levels[(t.clamp(0, 1) * (levels.length - 1)).round()];
  }
}

/// "Less ▢▢▢▢ More" legend.
class GridLegend extends StatelessWidget {
  const GridLegend({super.key, required this.colorMode});
  final GridColorMode colorMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget box(Color c) => Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    final lo = colorMode == GridColorMode.count ? 'Fewer' : 'Easier';
    final hi = colorMode == GridColorMode.count ? 'More' : 'Harder';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lo, style: style),
        const SizedBox(width: 4),
        box(scheme.surfaceContainerHighest),
        for (final t in [0.0, 0.34, 0.67, 1.0])
          box(ContributionGrid.levelColor(scheme, t)),
        const SizedBox(width: 4),
        Text(hi, style: style),
      ],
    );
  }
}
