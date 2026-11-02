import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ascent.dart';
import '../models/stats.dart';

/// Colour of a kind of climbing. Fixed per kind (never by rank), taken from
/// the categorical palette and checked for colour-blind separation in both
/// themes.
Color kindColor(ClimbKind kind, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (kind) {
    ClimbKind.sport => dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6),
    ClimbKind.boulder =>
      dark ? const Color(0xFFD95926) : const Color(0xFFEB6834),
    ClimbKind.trad => dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A),
  };
}

/// Grouped columns: for each year, how many days were spent on each kind of
/// climbing. Every bar carries its value (the lightest colours have low
/// contrast on a light background) and a tooltip.
class DaysPerYearChart extends StatelessWidget {
  const DaysPerYearChart({
    super.key,
    required this.years,
    this.selectedYear,
    this.onYearTap,
    this.plotHeight = 250,
  });

  final List<YearKindDays> years;
  final int? selectedYear;
  final ValueChanged<int>? onYearTap;
  final double plotHeight;

  static const _axisWidth = 32.0;
  static const _labelHeight = 16.0;
  static const _yearLabelHeight = 30.0;
  static const _minGroupWidth = 64.0;

  /// A round axis step giving about four gridlines.
  static int niceStep(int maxValue) {
    final raw = maxValue / 4;
    for (final s in const [1, 2, 5, 10, 20, 25, 50, 100, 200, 500]) {
      if (s >= raw) return s;
    }
    return 1000;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kinds = [
      for (final k in ClimbKind.values)
        if (years.any((y) => y.daysOf(k) > 0)) k,
    ];
    if (kinds.isEmpty) {
      return Text('No ascents yet.', style: theme.textTheme.bodyMedium);
    }

    final maxDays = years.expand((y) => y.days.values).fold(1, math.max);
    final step = niceStep(maxDays);
    final top = (maxDays / step).ceil() * step;
    final ticks = [for (var t = 0; t <= top; t += step) t];
    final scale = (plotHeight - _labelHeight) / top;
    final muted = scheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(color: muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final k in kinds)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kindColor(k, theme.brightness),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(k.label, style: theme.textTheme.labelMedium),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final avail = c.maxWidth - _axisWidth;
            final groupWidth = math.max(_minGroupWidth, avail / years.length);
            final plotWidth = groupWidth * years.length;
            final scrolls = plotWidth > avail;
            final barWidth = math.min(
              28.0,
              (groupWidth - 20 - 2 * (kinds.length - 1)) / kinds.length,
            );

            Widget bar(YearKindDays y, ClimbKind k) {
              final v = y.daysOf(k);
              return Tooltip(
                message:
                    '${y.year} · ${k.label}: $v ${v == 1 ? 'day' : 'days'}',
                triggerMode: TooltipTriggerMode.tap,
                child: SizedBox(
                  width: barWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (v > 0)
                        SizedBox(
                          height: _labelHeight,
                          width: barWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$v',
                              style: labelStyle.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        height: v == 0 ? 0 : math.max(2.0, v * scale),
                        decoration: BoxDecoration(
                          color: kindColor(k, theme.brightness),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final plot = SizedBox(
              width: plotWidth,
              height: plotHeight + _yearLabelHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: plotHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridPainter(
                              ticks: ticks,
                              scale: scale,
                              color: scheme.outlineVariant,
                              baseline: scheme.outline,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final y in years)
                              SizedBox(
                                width: groupWidth,
                                height: plotHeight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var i = 0; i < kinds.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 2),
                                      bar(y, kinds[i]),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _yearLabelHeight,
                    child: Row(
                      children: [
                        for (final y in years)
                          SizedBox(
                            width: groupWidth,
                            child: Center(
                              child: _YearLabel(
                                year: y.year,
                                selected: y.year == selectedYear,
                                onTap: onYearTap == null
                                    ? null
                                    : () => onYearTap!(y.year),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _axisWidth,
                  height: plotHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final t in ticks)
                        Positioned(
                          right: 6,
                          bottom: t * scale - 7,
                          child: Text('$t', style: labelStyle),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: scrolls
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true, // newest years first in view
                          child: plot,
                        )
                      : plot,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _YearLabel extends StatelessWidget {
  const _YearLabel({required this.year, required this.selected, this.onTap});

  final int year;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? scheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$year',
          style: theme.textTheme.labelMedium!.copyWith(
            fontWeight: selected ? FontWeight.w700 : null,
            color: selected ? scheme.onSecondaryContainer : null,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.ticks,
    required this.scale,
    required this.color,
    required this.baseline,
  });

  final List<int> ticks;
  final double scale;
  final Color color;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in ticks) {
      final y = size.height - t * scale;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = t == 0 ? baseline : color
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.ticks != ticks || old.scale != scale || old.color != color;
}
