# theCrag API notes

The fetcher uses theCrag's **Logbook Read API** (personal API keys, supporter
feature; see the article "Personal API Keys - Logbook Read Access").

* `GET /api/logbook/ascents?page=N[&since=<epoch>]`, 250 ascents per page.
* Auth header: `X-CData-Key: key=<your-api-key>`. The account is derived
  from the key, so no account parameter exists.
* Response: `data.{account, ascents[], numberAscents, page, perPage}`.
* Ascent: `id, epoch, date, tick{label,name}, route{name, grade, ancestors{parent, TLC, country}}`.
  Ancestor nodes carry `name` and `geometry` (coordinates), so no extra node
  lookups are needed.
* Calls use a weekly token budget; `since` (highest `epoch` seen) allows
  incremental syncs (not yet used by the fetcher).

Mapping to the app: crag = `ancestors.parent`, area = `ancestors.TLC`,
country = `ancestors.country`, coordinates = first geometry found in
parent, TLC, country. The exact `geometry` format is unverified: GeoJSON
points and lat/lon pairs are handled.

## Verifying

```bash
THECRAG_API_KEY=... dart run tool/fetch_ascents.dart --dump api_dump
```

Inspect `api_dump/*.json` and adjust `parseAscentMap` / `findCoordinates`
if field names differ. `THECRAG_BASE_URL` overrides the host
(default `https://www.thecrag.com`).
