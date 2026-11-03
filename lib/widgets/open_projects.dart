import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ascent.dart';
import '../models/stats.dart';
import 'year_chart.dart' show kindColor;

enum ProjectSort { recent, hardest }

/// Routes that were tried (hang dog, working, attempt, ...) but never sent.
class OpenProjectsView extends StatefulWidget {
  const OpenProjectsView({super.key, required this.projects});

  /// Most recently tried first, as returned by [openProjects].
  final List<OpenProject> projects;

  @override
  State<OpenProjectsView> createState() => _OpenProjectsViewState();
}

class _OpenProjectsViewState extends State<OpenProjectsView> {
  ProjectSort _sort = ProjectSort.recent;
  ClimbKind? _kind;

  static String _styleLabel(String? style) => switch (style?.toLowerCase()) {
    'dog' || 'hangdog' => 'hang dog',
    final s? => s,
    null => 'tried',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (widget.projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No open projects: every route you have tried is sent.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final kinds = [
      for (final k in ClimbKind.values)
        if (widget.projects.any((p) => p.kind == k)) k,
    ];
    final shown = [
      for (final p in widget.projects)
        if (_kind == null || p.kind == _kind) p,
    ];
    if (_sort == ProjectSort.hardest) {
      shown.sort((a, b) {
        final ga = a.gradeScore, gb = b.gradeScore;
        if (ga != gb) {
          if (ga == null) return 1;
          if (gb == null) return -1;
          return gb.compareTo(ga);
        }
        return b.lastTried.compareTo(a.lastTried);
      });
    }
    final sessions = shown.fold(0, (n, p) => n + p.sessions);

    final dateFormat = DateFormat.yMMMd();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: shown.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shown.length} open ${shown.length == 1 ? 'project' : 'projects'}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Routes you have tried but not sent yet, over $sessions '
                  '${sessions == 1 ? 'session' : 'sessions'}.',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<ProjectSort>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ProjectSort.recent,
                          label: Text('Last tried'),
                        ),
                        ButtonSegment(
                          value: ProjectSort.hardest,
                          label: Text('Hardest'),
                        ),
                      ],
                      selected: {_sort},
                      onSelectionChanged: (s) =>
                          setState(() => _sort = s.first),
                    ),
                    if (kinds.length > 1) ...[
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _kind == null,
                        onSelected: (_) => setState(() => _kind = null),
                      ),
                      for (final k in kinds)
                        ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 5,
                            backgroundColor: kindColor(k, theme.brightness),
                          ),
                          label: Text(k.label),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }
        final p = shown[i - 1];
        final where = [p.crag, p.country].whereType<String>().join(' · ');
        final small = theme.textTheme.bodySmall!.copyWith(
          color: scheme.onSurfaceVariant,
        );
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: p.url == null ? null : () => launchUrl(Uri.parse(p.url!)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: kindColor(p.kind, theme.brightness),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.grade ?? '–',
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.route,
                          style: theme.textTheme.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (where.isNotEmpty) Text(where, style: small),
                        Text(
                          '${p.sessions} '
                          '${p.sessions == 1 ? 'session' : 'sessions'}'
                          ' · ${_styleLabel(p.lastStyle)}',
                          style: small,
                        ),
                        Text(
                          'Last tried ${dateFormat.format(p.lastTried)}',
                          style: small,
                        ),
                      ],
                    ),
                  ),
                  if (p.url != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
