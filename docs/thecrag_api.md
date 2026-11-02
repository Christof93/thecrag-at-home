# theCrag API notes

**Status: the official documentation page has not been saved here yet.**
The page at <https://www.thecrag.com/article/API> could not be downloaded
from the cloud workspace that bootstrapped this project, because its network
policy blocks `www.thecrag.com`. To store it, run this from your own machine
(or after allowing the domain in the cloud environment):

```bash
curl -L https://www.thecrag.com/article/API -o docs/thecrag_api_article.html
```

## Assumptions the fetcher makes (unverified)

`tool/fetch_ascents.dart` was written without access to the docs or the live
API, so it relies on these assumptions. Each is configurable or
handled tolerantly:

| Assumption | Default | Override |
| --- | --- | --- |
| Base URL | `https://www.thecrag.com` | `THECRAG_BASE_URL` |
| Auth | header `X-CData-Key: key=<api key>` (verified) | edit `TheCragApi._get` |
| Ascent listing | `GET /api/logbook/ascents?perPage=500&page=N` (endpoint verified; paging params not yet) | `THECRAG_ASCENTS_PATH` |
| Node (route/crag) details incl. coordinates | `GET /api/node/id/{id}` | `THECRAG_NODE_PATH` |

Response parsing is shape-agnostic:

* **Ascent rows**: the first list in the response whose objects have a
  date-like key (`date`, `ascentDate`, `tickDate`, `when`, ...), or array rows
  paired with a list of field names.
* **Fields**: route name/grade come from `route.{name,grade}` or flat keys.
  Crag, area and country come from flat keys or the `ancestors` path. Style
  comes from `tick`/`ascentType`/`style`.
* **Coordinates**: any `lat`/`latitude` + `lon`/`long`/`lng`/`longitude`
  pair, or GeoJSON `coordinates: [lon, lat]`, searched in the ascent itself,
  then in the route node, then up the crag/area ancestors.

## Verifying against the real API

```bash
THECRAG_API_KEY=... dart run tool/fetch_ascents.dart --dump api_dump
```

Then inspect `api_dump/*.json` (the key is only sent as a header, so it is not recorded). If
the endpoints or field names differ, adjust the env vars or
`parseAscentMap` / `findCoordinates`. The unit tests in
`test/fetch_parsing_test.dart` are a good place to paste a real (trimmed)
response.
