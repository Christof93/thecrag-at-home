import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ascent.dart';
import '../models/stats.dart';
import 'year_chart.dart' show kindColor;

enum ProjectSort { recent, hardest }

/// Routes that were tried but never sent, in a column per [ProjectStage]
/// (hang dog, projected, try). Stacked sections on narrow screens.
class OpenProjectsView extends StatefulWidget {
  const OpenProjectsView({super.key, required this.projects});

  /// Most recently tried first, as returned by [openProjects].
  final List<OpenProject> projects;

  /// Width from which the stages sit side by side.
  static const columnsBreakpoint = 900.0;

  @override
  State<OpenProjectsView> createState() => _OpenProjectsViewState();
}

class _OpenProjectsViewState extends State<OpenProjectsView> {
  ProjectSort _sort = ProjectSort.recent;
  ClimbKind? _kind;

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

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                onSelectionChanged: (s) => setState(() => _sort = s.first),
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

    Widget stageColumn(ProjectStage stage) => _StageColumn(
      stage: stage,
      projects: [
        for (final p in shown)
          if (p.stage == stage) p,
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= OpenProjectsView.columnsBreakpoint;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            header,
            if (columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, stage) in ProjectStage.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: stageColumn(stage)),
                  ],
                ],
              )
            else
              for (final stage in ProjectStage.values) ...[
                stageColumn(stage),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

/// One stage: a heading with the count, then a card per project.
class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.stage, required this.projects});

  final ProjectStage stage;
  final List<OpenProject> projects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(stage.label, style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${projects.length}',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        Text(stage.description, style: muted),
        const SizedBox(height: 8),
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Nothing here.', style: muted),
          )
        else
          for (final p in projects) _ProjectCard(project: p),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final OpenProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = project;
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
                      '${p.sessions == 1 ? 'session' : 'sessions'}',
                      style: small,
                    ),
                    Text(
                      'Last tried ${DateFormat.yMMMd().format(p.lastTried)}',
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
  }
}
