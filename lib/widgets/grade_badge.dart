import 'package:flutter/material.dart';

import '../models/grades.dart';
import '../models/rarity.dart';

/// Outline colour of a grade tier, in the usual game-rarity order: grey,
/// green, blue, purple, orange. Each is at least 3:1 against the card
/// surfaces in both themes, and the tier is always named in text too.
Color rarityColor(Rarity rarity, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (rarity) {
    Rarity.common => dark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
    Rarity.uncommon => dark ? const Color(0xFF3FB950) : const Color(0xFF2E9E4A),
    Rarity.rare => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    Rarity.epic => dark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
    Rarity.legendary =>
      dark ? const Color(0xFFFFA726) : const Color(0xFFD06C00),
  };
}

/// A grade in a pill outlined in its tier colour. Without a tier (an
/// unreadable grade) it is plain text.
class GradeBadge extends StatelessWidget {
  const GradeBadge({
    super.key,
    required this.grade,
    required this.rarity,
    this.discipline = Discipline.route,
  });

  final String? grade;
  final Rarity? rarity;

  /// Which scale the tooltip names the tier's range on.
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = grade ?? '–';
    final tier = rarity;
    if (tier == null) {
      return Text(text, style: theme.textTheme.titleSmall);
    }
    final color = rarityColor(tier, theme.brightness);
    return Tooltip(
      message: '${tier.label}: ${tier.range(discipline)}',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: theme.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The five tiers with their grade ranges for routes and boulders.
class RarityLegend extends StatelessWidget {
  const RarityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Grade tiers', style: muted),
        for (final r in Rarity.values)
          Tooltip(
            message:
                'Sport: ${r.range(Discipline.route)}\n'
                'Boulder: ${r.range(Discipline.boulder)}',
            triggerMode: TooltipTriggerMode.tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: rarityColor(r, theme.brightness).withValues(alpha: 0.14),
                border: Border.all(
                  color: rarityColor(r, theme.brightness),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(r.label, style: theme.textTheme.labelMedium),
            ),
          ),
      ],
    );
  }
}
