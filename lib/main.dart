import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';

void main() => runApp(const TheCragAtHomeApp());

class TheCragAtHomeApp extends StatelessWidget {
  const TheCragAtHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Green, like GitHub's contribution graph.
    const seed = Color(0xFF2DA44E);
    return MaterialApp(
      title: 'theCrag at home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}
