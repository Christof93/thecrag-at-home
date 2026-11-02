import 'package:flutter_test/flutter_test.dart';
import 'package:thecrag_at_home/models/ascent.dart';
import 'package:thecrag_at_home/models/grades.dart';

double s(String g) => Grades.parse(g)!.score;

void main() {
  test('french ordering', () {
    expect(s('6a') < s('6a+'), isTrue);
    expect(s('7c+') < s('8a'), isTrue);
  });
  test('systems roughly agree', () {
    expect(s('5.12a'), closeTo(s('7a+'), 1));
    expect(s('24'), closeTo(s('7a'), 1)); // Ewbank
    expect(s('8+'), closeTo(s('7a'), 1)); // UIAA
    expect(s('VII'), closeTo(s('6a'), 1)); // UIAA roman
  });
  test('boulder grades', () {
    expect(Grades.parse('V4')!.discipline, Discipline.boulder);
    expect(Grades.parse('7A')!.discipline, Discipline.boulder);
    expect(Grades.parse('7a')!.discipline, Discipline.route);
    expect(s('V6'), s('7A'));
  });
  test('boulder hint reads ambiguous grades as Font', () {
    ParsedGrade? b(String g) => Grades.parse(g, discipline: Discipline.boulder);
    expect(b('5+')!.discipline, Discipline.boulder);
    expect(b('6a')!.score, s('6A'));
    expect(b('5B')!.score < b('6A')!.score, isTrue);
    expect(b('4')!.score < b('6A')!.score, isTrue);
    expect(Grades.parse('5+')!.discipline, Discipline.route); // UIAA
    expect(
      Grades.parse('5+', discipline: Discipline.route)!.discipline,
      Discipline.route,
    );
  });
  test('unknown grades', () {
    expect(Grades.parse('A2'), isNull);
    expect(Grades.parse(''), isNull);
  });
  test('hardest of day ignores attempts', () {
    final d = DateTime(2024, 5, 1);
    final day = ClimbingDay(d, [
      Ascent(id: '1', date: d, route: 'a', grade: '6b', style: 'redpoint'),
      Ascent(id: '2', date: d, route: 'b', grade: '7b', style: 'attempt'),
      Ascent(id: '3', date: d, route: 'c', grade: '6V', style: 'onsight'),
      Ascent(id: '4', date: d, route: 'd', grade: '7A', style: 'flash'),
    ]);
    expect(day.hardestRoute!.route, 'a');
    expect(day.hardestBoulder!.route, 'd');
  });
}
