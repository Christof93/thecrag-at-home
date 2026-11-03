import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';

void main() => runApp(const TheCragAtHomeApp());

class TheCragAtHomeApp extends StatelessWidget {
  const TheCragAtHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'theCrag at home',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const DashboardPage(),
    );
  }
}

/// Mustard yellow, the app's accent.
const mustard = Color(0xFFFFDB58);

/// The light theme has a cream surface and a mustard app bar, with a darker
/// gold where yellow itself would be too pale to read (text, bars, the
/// calendar). The dark theme uses mustard as its accent on a warm dark
/// surface.
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: mustard,
    brightness: brightness,
    // "Fidelity" keeps the seed itself as the container colour (#FFDB58).
    dynamicSchemeVariant: light
        ? DynamicSchemeVariant.fidelity
        : DynamicSchemeVariant.tonalSpot,
  );
  if (!light) {
    scheme = scheme.copyWith(
      primary: mustard,
      onPrimary: const Color(0xFF3B2F00),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? scheme.primaryContainer : null,
      foregroundColor: light ? scheme.onPrimaryContainer : null,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
