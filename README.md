# wallabag on Railway

One-click, zero-prompt deployment of [wallabag](https://github.com/wallabag/wallabag) — the open-source read-it-later app (Pocket / Instapaper alternative). Save articles from the web, read them in a clean distraction-free view, tag and annotate, export to EPUB/MOBI/PDF, and read on the go with the official Android and iOS apps via the built-in REST API and RSS feeds.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/wallabag-railway-template)

## What gets provisioned

- **1 service** (`wallabag`): the **official `wallabag/wallabag` image, version 2.6.15.1, digest-pinned**, wrapped with a tiny entrypoint that seeds a per-deploy admin password on first boot. Upstream image content is untouched.
- **1 volume** mounted at `/var/www/wallabag/data` — the SQLite database (all articles, users, tags, settings) plus the seeded credentials file.
- **0 variables to fill in** — everything auto-resolves at deploy time.

SQLite is the official image's default database driver and is fully supported upstream; for a single-user read-it-later app it removes the whole second-service (MariaDB) stack. If you later want MariaDB/Postgres for heavy multi-user use, upstream documents the env contract (`SYMFONY__ENV__DATABASE_*`).

## Variables (all automatic, nothing to type)

| Variable | Value | Purpose |
|---|---|---|
| `SYMFONY__ENV__DOMAIN_NAME` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | absolute links in RSS feeds, emails, exports |
| `SYMFONY__ENV__SECRET` | `${{secret(32)}}` | Symfony app secret, unique per deployment |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | generated admin password, consumed by the wrapper on first boot |

## First login

The installer creates the classic default user `wallabag` / `wallabag`; the wrapper immediately replaces the password on first boot with the generated one:

1. Read the generated credentials:
   ```
   railway ssh -s wallabag -- cat /var/www/wallabag/data/default-creds.txt
   ```
   (or open the service's SSH terminal in the Railway dashboard and run the same `cat`).
2. Log in as **`wallabag`** with that password.
3. Change the password in **Profile settings**, then delete the file:
   ```
   railway ssh -s wallabag -- rm /var/www/wallabag/data/default-creds.txt
   ```

Seeding runs exactly once — a marker file (`/var/www/wallabag/data/.admin-seeded`) guards it, so it never re-fires after restarts, redeploys, or password changes. If `ADMIN_PASSWORD` was changed before the first boot, the wrapper uses that value instead of generating one.

## Mobile apps (REST API clients)

wallabag's API is OAuth2-based; third-party apps need per-instance client credentials:

1. Log in to your instance and open `https://YOUR-DOMAIN/developer` (also linked from **Config → Developer** in older UIs).
2. **Create a new client** — copy the **Client ID** and **Client Secret**.
3. In the official [Android](https://f-droid.org/packages/fr.gaulupeau.apps.InThePoche/) or iOS app enter: server URL `https://YOUR-DOMAIN`, the client ID, the client secret, then your wallabag username and password.

Note: a console command (`php bin/console fos:oauth-server:create-client`) technically exists but crashes in wallabag 2.6.x — use the developer page above, which is the supported path.

Raw token flow for scripts:

```
POST /oauth/v2/token?grant_type=password&client_id=CLIENT_ID&client_secret=CLIENT_SECRET&username=USER&password=PASS
```

Use the returned `access_token` as `Authorization: Bearer ...` on `/api/entries.json`, `/api/entries/<id>.json`, and the rest of the documented API.

## First boot

The first boot takes **1–3 minutes**: the container generates `parameters.yml`, runs the SQLite install + migrations, then starts nginx and php-fpm. During that window the page may refuse connections — once `/api/info` answers, the app is ready. Later boots are fast (install is skipped when the database file already exists).

## Persistence

Everything that matters lives on the volume: the SQLite database (`data/db/wallabag.sqlite`), the marker and credentials files. Restarts and redeploys keep your articles.

One caveat: wallabag's optional "store pictures locally" setting writes to `/var/www/wallabag/web/assets/images`, which this template does **not** persist. Either skip that feature or add a second Railway volume at that path yourself.

## Upgrades

1. Back up: snapshot the volume (or run `railway ssh -s wallabag -- php bin/console wallabag:export wallabag /var/www/wallabag/data/backup.json`).
2. Bump the pinned tag/digest in this repo's `Dockerfile` and redeploy.
3. If the new wallabag version ships database migrations, apply them once:
   ```
   railway ssh -s wallabag -- php bin/console doctrine:migrations:migrate --env=prod --no-interaction
   ```

## Notes

- **Registration is disabled by default** — this deploys as a single-user instance. Invite others by creating users from the admin UI or `php bin/console fos:user:create`.
- **Password-reset emails need SMTP**: set `SYMFONY__ENV__MAILER_DSN` (e.g. to a Railway-resident mail service) if you want them.
- **Redis / RabbitMQ are optional** and only used by background import workers for bulk imports; they are not provisioned.
- If a redeploy ever rotates `SYMFONY__ENV__SECRET`, browser sessions reset (log in again). Saved data is unaffected — it all lives on the volume.
- Deployments go active as soon as the container starts; wallabag finishes its boot work in the first minutes. Health is best checked via `GET /api/info` (public, 200 when ready).

## Existing templates disclosure

At publish time (2026-11-11), Railway's marketplace had other wallabag templates: **DS Media (2 deploys)**, A3A (0 deploys), Connor Prussin (0 deploys), Heimdall (0 deploys). This template's differences: digest-pinned official image, single-service SQLite with zero deploy prompts, per-deploy generated admin password instead of the public default credentials, and a documented mobile-app API path.

## Repo layout

- `Dockerfile` — official image, digest-pinned, plus the wrapper entrypoint
- `docker-entrypoint-wrapper.sh` — SQLite dir prep + first-boot admin password seed
- `railway.json` — Dockerfile builder, ON_FAILURE restart policy
