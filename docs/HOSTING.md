# Hosting options

`flutter build web` produces a fully static site (`build/web`), and the data
is baked in at build time. Any static host therefore works, and the main
choices are **how the data gets refreshed** and **who may see the page**.

> ⚠️ The built site contains your ascent history (dates, routes, crag
> locations). On a public host, anyone with the URL can see it. theCrag
> logbooks are often public anyway, but decide whether that's fine for you.

| Option | Cost | Private? | Data refresh | Notes |
| --- | --- | --- | --- | --- |
| **GitHub Pages** (included workflow) | Free | No: public site; a free plan also needs a public repo | Daily scheduled Action | Least setup. Recommended to start. |
| **Cloudflare Pages** + Cloudflare Access | Free (Access is free for ≤50 users) | Yes: email login in front of the site | GitHub Action → `wrangler pages deploy`, or Cloudflare's own build | Best free *private* option. |
| **Firebase Hosting** | Free tier | No, unless you add Firebase Auth in-app | GitHub Action → `firebase deploy` | Easy upgrade path to a live backend (Cloud Functions proxy for theCrag). |
| **Netlify / Vercel** | Free tier; password protection is paid | Paid | Build hook / scheduled Action | Preview deploys per PR. |
| **Self-hosted** (Raspberry Pi, NAS, VPS) with nginx/Caddy | Your hardware | Yes, e.g. on a LAN or Tailscale | cron running `fetch_ascents.dart` + `flutter build web` | Full control; the key never leaves your machine. |
| **Native app** (Android/iOS/desktop) | Free sideload; stores charge fees | Yes | Rebuild, or add an in-app fetch | Same code base: `flutter build apk`, `flutter build macos`, ... |

## GitHub Pages (set up in this repo)

1. Repository **Settings → Secrets and variables → Actions**:
   * Secret `THECRAG_API_KEY`: your API key.
   * Optional variable `THECRAG_DISPLAY_NAME`: the title shown in the app.
2. **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Merge to `main`, or run the workflow manually (**Actions → Build & deploy →
   Run workflow**). The site appears at
   `https://<user>.github.io/thecrag-at-home/` and refreshes daily at 04:17 UTC.

Without the secret, the workflow deploys the demo data.

## Going live instead of snapshots

For data that's fresh on every page load, put a tiny proxy between the
app and theCrag that holds the key server side: a Cloudflare Worker, a
Firebase/Google Cloud Function or a Vercel function. It would forward
`/ascents` to the theCrag API (or run the same normalisation as
`tool/fetch_ascents.dart`) and cache the result. The app's
`AscentRepository` would then fetch from that URL instead of the bundled
asset. Map tiles: for heavy use, swap the public OpenStreetMap tile server
for a provider with a free tier (MapTiler, Stadia, Thunderforest), as
OSM's [tile policy](https://operations.osmfoundation.org/policies/tiles/)
requests.
