[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/wallabag-railway-template)

wallabag is the open-source read-it-later app — a self-hosted Pocket / Instapaper alternative. Save any article from the web, read it in a clean distraction-free view, organize with tags and filters, export to EPUB, and keep reading on your phone with the official Android and iOS apps. This template deploys the official wallabag image (v2.6.15.1, digest-pinned for reproducibility) as a single Railway service with a single volume — no database server to babysit, no parameters file to edit, no deploy-form fields to fill in.

What makes this template different from deploying wallabag by hand (or from the other wallabag templates on Railway — at publish time there were four others: DS Media with 2 deploys, plus three dormant ones from A3A, Connor Prussin, and Heimdall):

- **One service, one volume.** SQLite — the official image's default and fully supported database driver — is embedded in the container. Articles, users, and settings all live on one persistent volume.
- **Zero prompts.** The public domain, the Symfony app secret, and the admin password all resolve automatically per deployment.
- **No default-credential window.** The wallabag image ships with publicly documented credentials (wallabag / wallabag). This template replaces that password with a generated one on first boot; you read it from the volume via SSH, log in, and change it.
- **Mobile-ready.** The exact steps for creating an API client for the Android / iOS apps are in the repo README and below — client creation, token endpoint, and authenticated calls all verified end to end.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/wallabag-railway-template)

# Deploy and Host

Deploying provisions one service named wallabag, built from this repo's wrapper Dockerfile (official wallabag/wallabag image pinned by digest), and one Railway volume mounted at /var/www/wallabag/data that holds the SQLite database and the seeded credentials file. Three environment variables configure themselves: SYMFONY__ENV__DOMAIN_NAME derives from the auto-provisioned Railway public domain so RSS feeds and exports use correct absolute URLs, SYMFONY__ENV__SECRET gets a unique per-deploy value, and ADMIN_PASSWORD gets a generated value the first-boot wrapper applies to the admin account.

The first boot takes one to three minutes (the container runs the SQLite install and migrations before the web server starts); once the public endpoint answers, the app is ready. Then: read the generated password with railway ssh (or the dashboard SSH terminal) — cat /var/www/wallabag/data/default-creds.txt — log in as user wallabag, change the password in profile settings, and delete the credentials file. Registration is disabled by default, so the instance is single-user until you create more users.

## About Hosting

Hosting wallabag yourself means your reading list, highlights, and archives stay in a database you own — no service can shut down, purge, or monetize them. This template keeps the operational footprint minimal: one service running the official image (nginx + php-fpm inside, listening on port 80), one volume for all state, and three self-resolving variables. There is no separate database service to back up, connect, or pay for; the SQLite file on the volume is the entire datastore, and the repo documents the upgrade path (bump the pinned digest, apply doctrine migrations via SSH).

## Why Deploy

Deploying wallabag manually means wiring a PHP runtime to a database, editing a Symfony parameters file, choosing drivers and secrets, running the interactive installer, and hoping the admin password is not the publicly documented default. This template collapses all of that: the image is digest-pinned so deploys are reproducible, the database decision (SQLite) is made sensibly for a personal instance, migrations run automatically on first boot, and the admin password is generated per deployment instead of being left at the default. The wrapper seeds it exactly once (marker-guarded), so restarts and redeploys never overwrite a password you changed.

## Common Use Cases

- Replace a shutting-down Pocket / Instapaper account with a permanent, self-owned reading queue.
- Save long articles during the day and read them distraction-free on desktop or in the official Android / iOS apps on mobile.
- Archive content you care about: full-text search, tags, annotations, multi-format export (EPUB, MOBI, PDF), and RSS feeds of your unread list.
- Automate saving via the REST API or share an instance with a small group (additional users can be created from the admin UI).

## Dependencies for

This template is intentionally self-contained: wallabag ships with everything it needs at runtime, and the SQLite driver is compiled into the official image. The only required Railway resources are the ones the template itself provisions.

### Deployment Dependencies

- **Volume** — one Railway volume at /var/www/wallabag/data (SQLite database, marker file, credentials file). Attached automatically; deleting it erases all articles and users.
- **Public domain** — auto-provisioned; SYMFONY__ENV__DOMAIN_NAME references it at boot for correct absolute links.
- **Nothing else is required.** Redis and RabbitMQ are optional upstream features for background bulk-import workers and are not provisioned. An SMTP service (optional) is only needed if you want password-reset emails — set SYMFONY__ENV__MAILER_DSN to enable.
