import 'package:flutter/material.dart';

import '../models/stats.dart';

/// Ranked horizontal bars: the most visited crags by days out.
class TopCragsList extends StatelessWidget {
  const TopCragsList({super.key, required this.crags});

  final List<CragVisits> crags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (crags.isEmpty) {
      return Text(
        'No crags in this period.',
        style: theme.textTheme.bodyMedium,
      );
    }
    final most = crags.first.days;
    return Column(
      children: [
        for (var i = 0; i < crags.length; i++)
          Tooltip(
            message:
                '${crags[i].name}: ${crags[i].days} '
                '${crags[i].days == 1 ? 'day' : 'days'}, '
                '${crags[i].ascents} '
                '${crags[i].ascents == 1 ? 'ascent' : 'ascents'}',
            triggerMode: TooltipTriggerMode.tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: crags[i].name,
                                  children: [
                                    if (crags[i].country != null)
                                      TextSpan(
                                        text: '  ${crags[i].country}',
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${crags[i].days} '
                              '${crags[i].days == 1 ? 'day' : 'days'}',
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: crags[i].days / most,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
