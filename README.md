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
* **Days out per year**: grouped columns of how many days you climbed sport,
  boulders and trad each year. Tap a year to select it.
* **Most visited crags**: ranked by days out in the selected period.
* Period filter (last 12 months, each year, all time) and summary tiles,
  including a **Multipitch** tile: ascents where you logged two or more
  pitches, and how many pitches that adds up to. theCrag doesn't expose a
  route's total pitch count, so only the pitches you logged individually
  are counted.

It ships with generated demo data (`assets/data/ascents.json`) until you
fetch your own.

## How the data flows

```
theCrag Logbook Read API ──(API key, server side)──▶ tool/fetch_ascents.dart
                                              │ writes
                                              ▼
                               assets/data/ascents.json ──▶ Flutter app
```

The app never calls theCrag directly. Your API key would otherwise be
visible to anyone opening the site, and browsers would likely block the
cross-origin requests anyway. Instead, a small Dart CLI fetches and
normalises your ascents into a JSON snapshot, which is bundled into the app at
build time. The GitHub Actions workflow re-runs it daily. Your private
ascent notes are never copied into the snapshot.

## Getting started

```bash
bash scripts/setup_cloud_env.sh        # installs Flutter if needed
flutter pub get
flutter run -d chrome                  # or: flutter run -d web-server --web-port 8080
```

### Fetch your own ascents

Create a personal API key under theCrag **Settings › API Keys** (needs
supporter status), then:

```bash
export THECRAG_API_KEY=...             # your personal key
dart run tool/fetch_ascents.dart
```

The first run downloads the whole logbook (250 ascents per call). API calls
use tokens from a weekly budget, so later runs only ask for ascents changed
since the last one, using the cache in `tool/.cache/ascents.json`. Once a
week, or with `--full`, everything is downloaded again so deleted ascents
disappear. `--dump api_dump` saves the raw responses. See
[docs/thecrag_api.md](docs/thecrag_api.md) for the API details.

No API key? Export your logbook as CSV from the theCrag website and run
(the map stays empty, as the CSV has no coordinates):

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
secret, then enable Pages
with "GitHub Actions" as the source.

## Project layout

| Path | What |
| --- | --- |
| `lib/models/ascent.dart` | Ascent / day / dataset models (pure Dart, shared with the CLI) |
| `lib/models/grades.dart` | Grade parser: French, YDS, UIAA, Ewbank, Font, V-scale |
| `lib/widgets/contribution_grid.dart` | GitHub-style calendar |
| `lib/models/stats.dart` | Days per year by kind, most visited crags |
| `lib/widgets/year_chart.dart`, `top_crags.dart` | The two charts |
| `lib/widgets/ascent_map.dart` | `flutter_map` + OpenStreetMap world map |
| `lib/pages/dashboard_page.dart` | Dashboard layout, filters, stats |
| `tool/fetch_ascents.dart` | theCrag Logbook Read API / CSV → `assets/data/ascents.json` |
| `scripts/setup_cloud_env.sh` | Flutter install for cloud workspaces / CI boxes |
| `.devcontainer/` | GitHub Codespaces config |
| `.github/workflows/deploy.yml` | Test, fetch, build and deploy to GitHub Pages |
