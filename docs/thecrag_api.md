# theCrag Logbook Read API

Summary of [Personal API Keys - Logbook Read Access](https://www.thecrag.com/de/artikel/logbookreadapi),
checked against the live API in November 2026. `tool/fetch_ascents.dart`
implements it.

## Keys and limits

* Only **supporters** can issue and use keys (Settings › API Keys). A key
  reads only the logbook of the account that issued it, including
  **private notes**.
* Keys expire after a maximum lifetime, and an account can only have a
  limited number of active keys.
* Every call uses tokens from a **weekly per-account budget**. The budget
  size isn't published; the remaining balance is shown under Settings › API
  Keys. Use `since` for incremental updates rather than re-downloading the
  whole logbook.

## Endpoint

```
GET https://www.thecrag.com/api/logbook/ascents
X-CData-Key: key=<your-api-key>
```

The account comes from the key. (A `?key=` query parameter also works, but
the header is the documented way and keeps the key out of URLs and logs.)

| Parameter | Type | Meaning |
| --- | --- | --- |
| `page` | integer | Page number, 250 ascents per page |
| `since` | Unix epoch | Only ascents created or updated after this time |

Every request checks that the key exists and hasn't been revoked or
expired, that the owner is still a supporter, and that the weekly budget
isn't used up.

## Response

```json
{
  "data": {
    "account": { "name": "...", "login": "...", "ascentCount": 519, ... },
    "ascents": [ ... ],
    "numberAscents": 520,
    "page": "1",
    "perPage": 250
  }
}
```

* `numberAscents` counts the ascents matching the query, so with `since` it
  is the number of changed ascents, not the logbook size.
* `page` may come back as a string.

### Ascent fields used by the fetcher

| Field | Notes |
| --- | --- |
| `id` | Ascent id |
| `epoch` | Created / last updated (Unix time); the next `since` value |
| `date` | Day of the climb, e.g. `2017-08-22T00:00:00Z`. Missing on a few historical entries; `logDate` is used then |
| `grade` | Grade logged with the ascent (optional); else `route.grade` |
| `tick.label` | `onsight`, `flash`, `redpoint`, `send`, `tick`, `dog`, `working`, `attempt`, `retreat`, ... |
| `climbedGearStyle` | `sport`, `boulder`, `trad`, ... (often missing) |
| `markdown` | Your notes, **including private ones**. Not copied into the snapshot |
| `route.name`, `route.id`, `route.grade`, `route.style` (`Sport` / `Boulder` / `Trad`) | |
| `route.urlAncestorStub` | Route URL: `https://www.thecrag.com/climbing/<stub>/route/<id>` |
| `route.ancestors.TLC` | Top-level crag: `name`, `geometry` `[lon, lat]` |
| `route.ancestors.parent` | Direct parent (sector), `geometry` sometimes missing |
| `route.ancestors.country` | Country |

## How the fetcher syncs

1. First run (or `--full`): download every page and store the normalised
   ascents plus the highest `epoch` in `tool/.cache/ascents.json`.
2. Later runs: request `?since=<highest epoch>` (usually a single call that
   returns nothing or a few ascents) and merge by ascent id.
3. Incremental requests can't report deleted ascents, so a full download is
   repeated once the last one is more than 7 days old.

The GitHub Actions workflow keeps `tool/.cache` between runs with
`actions/cache`, so the daily refresh costs one call on most days.
