import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/data/ascent_repository.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/rarity.dart';
import 'package:thecrag_at_home/pages/dashboard_page.dart';
import 'package:thecrag_at_home/widgets/ascent_map.dart';
import 'package:thecrag_at_home/widgets/contribution_grid.dart';
import 'package:thecrag_at_home/widgets/grade_badge.dart';
import 'package:thecrag_at_home/widgets/year_chart.dart';

class _FakeRepo extends AscentRepository {
  @override
  Future<AscentDataset> load() async {
    final today = DateTime.now();
    final d = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 3));
    return AscentDataset(
      climber: 'Tester',
      ascents: [
        Ascent(
          id: '1',
          date: d,
          route: 'Alpha',
          pitches: 3,
          grade: '6b',
          crag: 'Crag A',
          lat: 47,
          lon: 8,
        ),
        Ascent(
          id: '2',
          date: d,
          route: 'Beta',
          grade: '7a',
          crag: 'Crag A',
          lat: 47,
          lon: 8,
        ),
      ],
    );
  }
}

void main() {
  layoutTests();
  projectColumnTests();
  projectsTests();
  testWidgets('dashboard shows stats and grid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(repository: _FakeRepo())),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Tester · ascents'), findsOneWidget);
    expect(find.text('2 ascents on 1 days'), findsOneWidget);
    expect(find.text('7a'), findsOneWidget); // hardest route tile
    expect(find.byType(ContributionGrid), findsOneWidget);
    expect(find.text('Multipitch'), findsOneWidget);
    expect(find.text('3 pitches logged'), findsOneWidget);
    expect(find.text('Days out per year'), findsOneWidget);
    expect(find.byType(DaysPerYearChart), findsOneWidget);
    expect(find.text('Most visited crags'), findsOneWidget);
    expect(find.text('Crag A'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget); // two ascents, one day
  });
}

class _ProjectsRepo extends AscentRepository {
  @override
  Future<AscentDataset> load() async => AscentDataset(
    climber: 'Tester',
    ascents: [
      Ascent(
        id: '1',
        date: DateTime(2025, 5, 1),
        route: 'Sent route',
        grade: '6b',
        style: 'redpoint',
        routeId: 'r1',
      ),
      Ascent(
        id: '2',
        date: DateTime(2025, 6, 1),
        route: 'Hard project',
        grade: '7c',
        style: 'dog',
        crag: 'Crag B',
        country: 'Italy',
        routeId: 'r2',
      ),
    ],
  );
}

void layoutTests() {
  Future<void> pump(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(repository: _FakeRepo())),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('very wide screens put the map next to the calendar', (
    tester,
  ) async {
    await pump(tester, const Size(2000, 1400));
    final grid = tester.getRect(find.byType(ContributionGrid));
    final map = tester.getRect(find.byType(AscentMap));
    expect(map.left, greaterThan(grid.right)); // beside it, not below
    expect(map.top, lessThan(grid.bottom));
  });

  testWidgets('narrower screens stack the map below the calendar', (
    tester,
  ) async {
    await pump(tester, const Size(1500, 2000));
    final grid = tester.getRect(find.byType(ContributionGrid));
    final map = tester.getRect(find.byType(AscentMap));
    expect(map.top, greaterThan(grid.bottom));
  });
}

void projectColumnTests() {
  Future<void> openTab(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(repository: _ProjectsRepo())),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Open projects (1)'));
    await tester.pumpAndSettle();
  }

  testWidgets('wide screens show the stages side by side', (tester) async {
    await openTab(tester, const Size(1400, 1000));
    final dog = tester.getTopLeft(find.text('Hang dog'));
    final projected = tester.getTopLeft(find.text('Projected'));
    final tried = tester.getTopLeft(find.text('Attempted'));
    expect(projected.dx, greaterThan(dog.dx));
    expect(tried.dx, greaterThan(projected.dx));
    expect(projected.dy, dog.dy);
  });

  testWidgets('narrow screens show one stage, picked with chips', (
    tester,
  ) async {
    await openTab(tester, const Size(600, 1600));
    // Chips carry the counts; only the selected stage is listed.
    expect(find.text('Hang dog (1)'), findsOneWidget);
    expect(find.text('Projected (0)'), findsOneWidget);
    expect(find.text('Attempted (0)'), findsOneWidget);
    expect(find.text('Hard project'), findsOneWidget);

    await tester.tap(find.text('Attempted (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Hard project'), findsNothing);
    expect(find.text('Nothing here.'), findsOneWidget);

    await tester.tap(find.text('Hang dog (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Hard project'), findsOneWidget);
  });
}

void projectsTests() {
  testWidgets('open projects tab lists routes that were never sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(repository: _ProjectsRepo())),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Open projects (1)'), findsOneWidget);
    expect(find.text('Hard project'), findsNothing); // on the other tab

    await tester.tap(find.text('Open projects (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Hard project'), findsOneWidget);
    expect(find.text('Sent route'), findsNothing);
    expect(find.text('7c'), findsOneWidget);
    expect(find.text('1 open project'), findsOneWidget);
    // Hang dog column holds it; the other two stages are empty.
    expect(find.text('Hang dog'), findsOneWidget);
    expect(find.text('Projected'), findsOneWidget);
    expect(find.text('Attempted'), findsOneWidget);
    expect(find.text('Nothing here.'), findsNWidgets(2));

    // The 7c project is epic: its card is outlined in the epic colour and
    // its grade sits in a badge that names the tier.
    final card = tester.widget<Card>(
      find.ancestor(of: find.text('Hard project'), matching: find.byType(Card)),
    );
    expect(
      (card.shape! as RoundedRectangleBorder).side.color,
      rarityColor(Rarity.epic, Brightness.light),
    );
    expect(find.byType(GradeBadge), findsOneWidget);
    expect(find.byTooltip('Epic: 7a – 7c+'), findsOneWidget);
    // The legend names all five tiers with both grade ranges.
    expect(find.text('Grade tiers'), findsOneWidget);
    for (final r in Rarity.values) {
      expect(find.text(r.label), findsOneWidget);
    }
    expect(find.byTooltip('Sport: 7a – 7c+\nBoulder: 7C – 8B'), findsOneWidget);
  });
}
