# theCrag at home

A personal climbing dashboard built with Flutter, fed by your
[theCrag](https://www.thecrag.com) logbook:

* **Ascent calendar**: a GitHub-style contribution grid with one square per
  day, coloured by number of ascents or by hardest grade. Hover (or tap) a
  square for the date, number of ascents, hardest route/boulder and crag.
  Click it to list every ascent of that day.
* **World map**: one dot per climbing day, sized by number of ascents.
  Days at the same spot share a dot, and its tooltip lists each date with its
  ascent count and hardest grade.
* Period filter (last 12 months, each year, all time) and summary tiles.

It ships with generated demo data (`assets/data/ascents.json`) until you
fetch your own.

## How the data flows

```
theCrag API ──(API key, server side)──▶ tool/fetch_ascents.dart
                                              │ writes
                                              ▼
                               assets/data/ascents.json ──▶ Flutter app
```

The app never calls theCrag directly. Your API key would otherwise be
visible to anyone opening the site, and browsers would likely block the
cross-origin requests anyway. Instead, a small Dart CLI fetches and
normalises your ascents into a JSON snapshot, which is bundled into the app at
build time. The GitHub Actions workflow re-runs it daily.

## Getting started

```bash
bash scripts/setup_cloud_env.sh        # installs Flutter if needed
flutter pub get
flutter run -d chrome                  # or: flutter run -d web-server --web-port 8080
```

### Fetch your own ascents

```bash
export THECRAG_API_KEY=...             # your personal key
export THECRAG_ACCOUNT=your-username   # or numeric account id
dart run tool/fetch_ascents.dart --dump api_dump
```

`--dump` saves the raw API responses to `api_dump/`, which helps check the
parser against the real API (see [docs/thecrag_api.md](docs/thecrag_api.md)).
Coordinates of routes and crags are looked up once and cached in
`tool/.cache/nodes.json`.

No API access, or the endpoints don't match? Export your logbook as CSV from
the theCrag website and run:

```bash
dart run tool/fetch_ascents.dart --csv ~/Downloads/logbook.csv
```

To regenerate the demo data, run `dart run tool/generate_demo.dart`.

### Tests

```bash
flutter analyze && flutter test
```

## Hosting

See [docs/HOSTING.md](docs/HOSTING.md). In short: GitHub Pages and the
included workflow work out of the box. Add `THECRAG_API_KEY` as a repository
secret and `THECRAG_ACCOUNT` as a repository variable, then enable Pages
with "GitHub Actions" as the source.

## Project layout

| Path | What |
| --- | --- |
| `lib/models/ascent.dart` | Ascent / day / dataset models (pure Dart, shared with the CLI) |
| `lib/models/grades.dart` | Grade parser: French, YDS, UIAA, Ewbank, Font, V-scale |
| `lib/widgets/contribution_grid.dart` | GitHub-style calendar |
| `lib/widgets/ascent_map.dart` | `flutter_map` + OpenStreetMap world map |
| `lib/pages/dashboard_page.dart` | Dashboard layout, filters, stats |
| `tool/fetch_ascents.dart` | theCrag API / CSV → `assets/data/ascents.json` |
| `scripts/setup_cloud_env.sh` | Flutter install for cloud workspaces / CI boxes |
| `.devcontainer/` | GitHub Codespaces config |
| `.github/workflows/deploy.yml` | Test, fetch, build and deploy to GitHub Pages |
