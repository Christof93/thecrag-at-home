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

/// Sand, the app's accent: a muted yellow-brown.
const sand = Color(0xFFE3CC94);

/// The light theme has a cream surface and a sand app bar, with a darker
/// brown-gold where sand itself would be too pale to read (text, bars, the
/// strongest calendar level). The dark theme uses sand as its accent on a
/// warm dark surface.
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: sand,
    brightness: brightness,
    // "Fidelity" keeps the seed itself as the container colour (#E3CC94).
    dynamicSchemeVariant: light
        ? DynamicSchemeVariant.fidelity
        : DynamicSchemeVariant.tonalSpot,
  );
  if (!light) {
    scheme = scheme.copyWith(primary: sand, onPrimary: const Color(0xFF33290F));
  }
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? scheme.primaryContainer : null,
      // Deep brown: sand is too light for the default on-container colour.
      foregroundColor: light ? const Color(0xFF33290F) : null,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
