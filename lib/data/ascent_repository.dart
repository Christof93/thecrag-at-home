import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ascent.dart';

/// Loads the ascent snapshot bundled with the app.
///
/// The snapshot is produced by `dart run tool/fetch_ascents.dart` (locally or
/// in the GitHub Actions deploy workflow), so the theCrag API key never ships
/// to the browser.
class AscentRepository {
  static const assetPath = 'assets/data/ascents.json';

  Future<AscentDataset> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return AscentDataset.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
