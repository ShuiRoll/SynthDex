# SynthDex

Flutter rhythm-game progress tracker based on the SynthDex Figma V2 screens.

## Run

```sh
flutter pub get
flutter run -d chrome --web-port=3000
```

The app connects to the SynthDex Supabase project by default. The bundled publishable key is intended for public clients; row-level security protects personal data. Never replace it with a service-role or secret key.

To use another project:

```sh
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Features

- Next-to-play Home with favorite-first uncleared chart suggestions and latest recorded activity; searchable catalog with unit/difficulty/status filters.
- Signed-in Profile shows unique completed-song totals and owned-card totals from local data.
- Local favorites, chart records, optional scores, and editable attempt history. No login required.
- Current best score and highest completion status calculated independently across active attempts.
- Clearing a current chart record archives its attempts; history remains available. New attempts start a fresh current record.
- Latest-versus-previous comparison, score plot, and computed difficulty statistics.
- Separate Profile and Settings pages: sign-in-gated display-name editing on Profile, plus a top-right settings gear for default difficulty, eight named palettes and System/Light/Dark appearance, backups and confirmed personal-data reset. Guest theme and difficulty changes remain available.
- Optional email/password signup and sign-in, Google sign-in/sign-up, username onboarding, and password recovery. Signing in never replaces local data.
- Character roster and profiles, 1,256 bundled Global cards refreshed from the catalog, owned/wishlist tracking and collection filters. See [collection details](docs/character-collection.md). Scores remain manually entered.
- Versioned JSON progress export and import with the catalog snapshot, so attempts, favorites and cards can be backed up, replaced or merged on a device without an account. Imports validate the format and refuse files recorded against a different catalog pin.
- Song jackets, card artwork, Original/Trained switches and zoomable previews. See [artwork and caching](docs/artwork.md).
- Loading, retry, empty, validation, save and delete confirmation states.

The Global / English catalog contains **647 playable songs and 3,356 charts**, including **121 APPEND charts**, from the November 13, 2026 Sekai Viewer master-data snapshot. Titles and levels match the pinned English source. Future, removed and expired limited-time entries are excluded from playable totals. See [catalog provenance and updates](docs/song-catalog.md). Tracking works offline; clearing browser site data removes local progress.

## Supabase

`supabase/schema.sql` records the initial schema applied to project `sgwucpmxkxlgirgoukri`. It contains songs, attempts, favorites, preferences, grants and ownership policies. The hosted migration is named `synthdex_initial_schema`. Do not reapply this bootstrap SQL to the already initialized project.

`supabase/normalize_and_backup.sql` records the deployed follow-up migration for 1NF/2NF/3NF and transactional backup RPCs, named `normalize_catalog_and_optional_backups`. It has been applied to the SynthDex project. See [use-case coverage and normalization](docs/use-cases-and-normalization.md) for table keys, dependencies and behavior.

The deployed `supabase/account_profiles.sql` migration adds private, unique usernames. See [account setup and callback configuration](docs/auth-setup.md) for required redirect URLs and verification limits. No user credentials or server keys are stored in source.

Supabase Flutter is pinned to 2.10.3 with a lockfile. The UI bundles Inter under its included OFL license.

## Validation

```sh
flutter analyze
flutter test
flutter build web --release
```

All 61 offline tests pass, covering email signup, Google username onboarding, password recovery, duplicate usernames, profile retries, and guest persistence across restarts, best-score aggregation, completion counts, history editing/deletion, reset, corrupted-data preservation, serialized writes, search, favorites, invalid scores, theme changes, backup freshness counters, catalog refresh throttling, card roster caching, progress export and import including the import dialog and toast wording, and mobile rendering. Four opt-in live-CDN artwork checks are skipped by default. Static analysis and the release web build pass.

Every live catalog title and chart level was verified against the pinned English master data. APPEND backup/restore and normalized database backup functions were verified. Transactional tests checked save/restore, invalid-backup rollback, cross-account isolation, and backing up the same local attempt IDs to separate accounts. Test rows were rolled back. Security advisors report no findings; performance advisors report only unused-index information on this new database. Real email confirmation/sign-in and native-device builds have not been exercised.








Theme palettes, appearance defaults and backup behavior: [Themes](docs/themes.md).
