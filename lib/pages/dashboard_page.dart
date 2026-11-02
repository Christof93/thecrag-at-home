import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ascent_repository.dart';
import '../models/ascent.dart';
import '../models/grades.dart';
import '../models/stats.dart';
import '../widgets/ascent_map.dart';
import '../widgets/contribution_grid.dart';
import '../widgets/top_crags.dart';
import '../widgets/year_chart.dart';

/// Selected time range: the last 12 months, a calendar year, or everything.
sealed class Period {
  const Period();
}

class LastYear extends Period {
  const LastYear();
}

class AllTime extends Period {
  const AllTime();
}

class CalendarYear extends Period {
  const CalendarYear(this.year);
  final int year;
  @override
  bool operator ==(Object other) => other is CalendarYear && other.year == year;
  @override
  int get hashCode => year;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.repository});
  final AscentRepository? repository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Future<AscentDataset> _data =
      (widget.repository ?? AscentRepository()).load();
  Period _period = const LastYear();
  GridColorMode _colorMode = GridColorMode.count;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AscentDataset>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Could not load ascents: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildDashboard(context, snap.data!);
      },
    );
  }

  (DateTime, DateTime) _range(List<Ascent> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      LastYear() => (
        DateTime(today.year - 1, today.month, today.day + 1),
        today,
      ),
      CalendarYear(:final year) => (DateTime(year), DateTime(year, 12, 31)),
      AllTime() => (
        all.isEmpty ? today : all.first.date,
        all.isEmpty ? today : all.last.date,
      ),
    };
  }

  Widget _buildDashboard(BuildContext context, AscentDataset data) {
    final theme = Theme.of(context);
    final all = data.ascents;
    final (start, end) = _range(all);
    final inRange = all
        .where((a) => !a.date.isBefore(start) && !a.date.isAfter(end))
        .toList();
    final days = ClimbingDay.group(inRange);
    final years = {for (final a in all) a.date.year}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data.climber == null
              ? 'theCrag at home'
              : '${data.climber} · ascents',
        ),
        actions: [
          if (data.generated != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Updated ${DateFormat.yMMMd().format(data.generated!.toLocal())}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (data.demo)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Showing generated demo data. Run '
                  '`dart run tool/fetch_ascents.dart` with your theCrag API '
                  'key (or let the GitHub Actions workflow do it) to see '
                  'your own ascents.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Last 12 months', const LastYear()),
              for (final y in years) _chip('$y', CalendarYear(y)),
              _chip('All time', const AllTime()),
            ],
          ),
          const SizedBox(height: 16),
          _Stats(days: days),
          const SizedBox(height: 16),
          _insights(theme, all, inRange),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${inRange.length} ascents on ${days.length} days',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      SegmentedButton<GridColorMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: GridColorMode.count,
                            label: Text('Count'),
                          ),
                          ButtonSegment(
                            value: GridColorMode.grade,
                            label: Text('Grade'),
                          ),
                        ],
                        selected: {_colorMode},
                        onSelectionChanged: (s) =>
                            setState(() => _colorMode = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._grids(days, start, end),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GridLegend(colorMode: _colorMode),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(height: 480, child: AscentMap(days: days)),
          ),
        ],
      ),
    );
  }

  /// Days per year by kind of climbing (always every year, whatever the
  /// period) next to the most visited crags of the selected period.
  Widget _insights(ThemeData theme, List<Ascent> all, List<Ascent> inRange) {
    Widget card(String title, String subtitle, Widget child) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );

    final period = switch (_period) {
      LastYear() => 'last 12 months',
      CalendarYear(:final year) => '$year',
      AllTime() => 'all time',
    };
    final years = card(
      'Days out per year',
      'Days with at least one ascent, by kind of climbing. A day with '
          'sport and boulders counts for both. Tap a year to select it.',
      DaysPerYearChart(
        years: daysPerYearByKind(all),
        selectedYear: switch (_period) {
          CalendarYear(:final year) => year,
          _ => null,
        },
        onYearTap: (y) => setState(() => _period = CalendarYear(y)),
      ),
    );
    final crags = card(
      'Most visited crags',
      'By days out, $period',
      TopCragsList(crags: mostVisitedCrags(inRange)),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 900
          ? Row(
              // Not `stretch`: the list gives this row unbounded height.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: years),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: crags),
              ],
            )
          : Column(children: [years, const SizedBox(height: 16), crags]),
    );
  }

  List<Widget> _grids(List<ClimbingDay> days, DateTime start, DateTime end) {
    Widget grid(List<ClimbingDay> d, DateTime s, DateTime e) =>
        ContributionGrid(
          days: d,
          start: s,
          end: e,
          colorMode: _colorMode,
          onDayTap: _showDay,
        );
    if (_period is! AllTime) return [grid(days, start, end)];
    // One calendar per year, newest first.
    return [
      for (var y = end.year; y >= start.year; y--) ...[
        Text('$y', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        grid(
          days.where((d) => d.date.year == y).toList(),
          DateTime(y),
          DateTime(y, 12, 31),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _chip(String label, Period p) => ChoiceChip(
    label: Text(label),
    selected:
        _period == p ||
        (p is LastYear && _period is LastYear) ||
        (p is AllTime && _period is AllTime),
    onSelected: (_) => setState(() => _period = p),
  );

  void _showDay(ClimbingDay day) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(DateFormat('EEEE d MMMM yyyy').format(day.date)),
            subtitle: Text(day.crags.join(', ')),
          ),
          for (final a in day.ascents)
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 48,
                child: Text(
                  a.grade ?? '–',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              title: Text(a.route),
              subtitle: Text([a.style, a.crag].whereType<String>().join(' · ')),
              onTap: a.url == null ? null : () => launchUrl(Uri.parse(a.url!)),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.days});
  final List<ClimbingDay> days;

  @override
  Widget build(BuildContext context) {
    final ascents = days.expand((d) => d.ascents).toList();
    Ascent? hardest(Discipline disc) {
      Ascent? best;
      for (final d in days) {
        final h = disc == Discipline.route ? d.hardestRoute : d.hardestBoulder;
        if (h != null &&
            (best == null || h.parsedGrade!.score > best.parsedGrade!.score)) {
          best = h;
        }
      }
      return best;
    }

    final hr = hardest(Discipline.route);
    final hb = hardest(Discipline.boulder);
    final crags = {for (final a in ascents) a.crag ?? a.area}..remove(null);
    final countries = {for (final a in ascents) a.country}..remove(null);

    final tiles = [
      ('Ascents', '${ascents.length}', null),
      ('Days out', '${days.length}', null),
      ('Crags', '${crags.length}', '${countries.length} countries'),
      if (hr != null) ('Hardest route', hr.grade!, hr.route),
      if (hb != null) ('Hardest boulder', hb.grade!, hb.route),
    ];
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, value, sub) in tiles)
          SizedBox(
            width: 170,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(value, style: theme.textTheme.headlineSmall),
                    if (sub != null)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
