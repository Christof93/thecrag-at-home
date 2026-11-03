import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/main.dart';
import 'package:thecrag_at_home/widgets/contribution_grid.dart';

void main() {
  test('light theme: sand container on a cream surface', () {
    final scheme = buildTheme(Brightness.light).colorScheme;
    expect(scheme.primaryContainer, sand); // #E3CC94
    expect(buildTheme(Brightness.light).appBarTheme.backgroundColor, sand);
    // Warm, yellowish surface, not a cool grey or green.
    final hsl = HSLColor.fromColor(scheme.surface);
    expect(hsl.hue, inInclusiveRange(20, 70));
  });

  test('dark theme: sand is the accent', () {
    expect(buildTheme(Brightness.dark).colorScheme.primary, sand);
  });

  test('calendar ramp is sand-coloured and gets stronger', () {
    for (final b in Brightness.values) {
      final scheme = buildTheme(b).colorScheme;
      final levels = [
        for (final t in [0.0, 0.34, 0.67, 1.0])
          ContributionGrid.levelColor(scheme, t),
      ];
      expect(levels.toSet(), hasLength(4)); // four distinct levels
      for (final c in levels) {
        // Warm sand hues only, no green or blue left in the ramp.
        expect(HSLColor.fromColor(c).hue, inInclusiveRange(30, 55));
      }
    }
    // Light: darker is stronger. Dark: brighter is stronger.
    final light = buildTheme(Brightness.light).colorScheme;
    expect(
      ContributionGrid.levelColor(light, 1).computeLuminance(),
      lessThan(ContributionGrid.levelColor(light, 0).computeLuminance()),
    );
    final dark = buildTheme(Brightness.dark).colorScheme;
    expect(
      ContributionGrid.levelColor(dark, 1).computeLuminance(),
      greaterThan(ContributionGrid.levelColor(dark, 0).computeLuminance()),
    );
  });
}
