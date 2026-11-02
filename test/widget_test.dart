import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/data/ascent_repository.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/pages/dashboard_page.dart';
import 'package:thecrag_at_home/widgets/contribution_grid.dart';
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
    expect(find.text('Days out per year'), findsOneWidget);
    expect(find.byType(DaysPerYearChart), findsOneWidget);
    expect(find.text('Most visited crags'), findsOneWidget);
    expect(find.text('Crag A'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget); // two ascents, one day
  });
}
