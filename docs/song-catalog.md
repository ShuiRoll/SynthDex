# Song catalog provenance and updates

The playable catalog is generated from a pinned snapshot of the Global / English
(EN) master data. Nothing in the app is typed by hand: `lib/src/catalog.g.dart`,
`supabase/catalog-data/*.sql` and `docs/catalog-provenance.json` are all produced
by the same script from the same inputs. `supabase/schema.sql` is the bootstrap
and seeds four legacy rows by hand; the generated batches replace those values.

## Source

| Field | Value |
| --- | --- |
| Repository | `Sekai-World/sekai-master-db-en-diff` |
| Pinned commit | `1ffbf9a3dc6400310987843ce79d7052e199b258` |
| Snapshot (`as_of`) | `2026-11-13T07:35:05.247815+00:00` |
| Region | `Global / EN` |

`tools/catalog-source/provenance.json` holds the repository, commit and `as_of`
timestamp. The generated Dart file exposes the date as `catalogAsOf` and the
region as `catalogRegion`.

Input files, all stored in `tools/catalog-source/` (the download step re-serialises
the upstream JSON):

- `musics.json` — song rows (id, title, artist or creator, `publishedAt`, pronunciation).
- `musicDifficulties.json` — one row per chart with `musicDifficulty` and `playLevel`.
- `musicTags.json` — unit tags per song.
- `musicArtists.json` — artist id to name.
- `limitedTimeMusics.json` — availability windows for limited-time entries.

## Generation

```sh
python tools/import_catalog.py            # rebuild from the pinned local snapshot
python tools/import_catalog.py --download # refresh the snapshot from upstream first
```

Outputs:

| Output | Contents |
| --- | --- |
| `lib/src/catalog.g.dart` | `bundledSongs`, shipped with the app |
| `supabase/catalog-data/batch-XX.sql` | Upserts, 100 songs per batch |
| `supabase/catalog-data/retire-missing.sql` | Marks absent songs unavailable |
| `docs/catalog-provenance.json` | Counts and the excluded list |

Review generated SQL before applying it to the hosted project. The script never
reads or writes credentials.

## What counts as playable

A source entry is playable only when every condition holds:

1. It is not one of the permanently withheld ids `241` and `290`.
2. `publishedAt` is at or before `as_of`.
3. It has no `limitedTimeMusics` rows, or at least one window satisfies
   `startAt <= as_of < endAt`.
4. At least one difficulty has a level greater than zero.

Everything else is still written to the database and to the provenance report,
but with `available = false`. Future songs, withdrawn entries and expired
limited-time charts are therefore excluded from playable totals rather than
deleted, so existing progress never breaks.

## Current totals

| Metric | Value |
| --- | --- |
| Source entries | 654 |
| Playable songs | 647 |
| Playable charts | 3,356 |
| APPEND charts | 121 |
| Excluded entries | 7 |
| Characters / released cards | 26 / 1,256 (see [character collection](character-collection.md)) |

`test/catalog_test.dart` asserts 647 songs, 3,356 charts and 121 APPEND charts,
and checks every bundled title and level against the pinned JSON.

## Canonical shape

Difficulties are indexed `0..5` as Easy, Normal, Hard, Expert, Master, Append.
A song stores its six levels as `List<int>`, where `0` means "no chart".

Unit tags map to display names:

| Master-data tag | Display name |
| --- | --- |
| `vocaloid` | Virtual Singer |
| `light_music_club` | Leo/need |
| `idol` | MORE MORE JUMP! |
| `street` | Vivid BAD SQUAD |
| `theme_park` | Wonderlands × Showtime |
| `school_refusal` | 25-ji, Nightcord de. |
| `other` | Other |

Tags are de-duplicated in source order after dropping anything not in the table
above; entries left with no recognised tag (limited-event medleys that only carry
the catch-all tag) fall back to `other`. The presentation colour follows the first non-Virtual-Singer,
non-`other` tag, while every tag is kept for filtering.

Stable ids: four legacy songs keep hand-written ids so early local data stays
readable (`1 → tell-your-world`, `126 → cinema`, `138 → king`, `248 → bug`).
Every other song is `sekai-<game id>`. `search_alias` holds an English alias for
three legacy entries (`1` → "Hatsune Miku", `126` → "Cinema", `248` → "Bug Kairiki
Bear") followed by the master-data pronunciation, so searches match kana and
romaji.

## Client behavior

- The app starts from `bundledSongs` and filters to `available` songs, so it
  works with no network at all.
- `AppStore.refresh()` pages through the public `songs` endpoint 100 rows at a
  time (PostgREST caps responses), joins units and charts, and caches the result
  under `synthdex.catalog.en.v2`.
- The same refresh pages through public `character_cards` 1,000 rows at a
  time, merges them with the bundled roster, and caches the merged list under
  `synthdex.cards.en.v1`. Remote rows win; earlier rows are retained, so a saved
  collection stays valid and readable.
- Entries missing from a refresh are retained locally with `available = false`,
  so archived records stay readable.
- A failed refresh only sets a non-blocking message; local tracking continues.

## Database writes

Batches upsert `songs` by `id`, rebuild `song_units` for the touched songs, and
upsert `charts` on `(song_id, difficulty)` for levels above zero. `retire-missing.sql`
runs `update public.songs set available = false where id not in (...)`. No catalog
step deletes songs, so attempts and favorites are never orphaned.

## Verifying

```sh
python tools/verify_catalog.py
```

The script reads the publishable key from `lib/main.dart` and queries the
hard-coded project URL (`https://sgwucpmxkxlgirgoukri.supabase.co/rest/v1/songs`;
it does not honour `SUPABASE_URL`), joining artists, units and charts. Against
`docs/catalog-provenance.json` and the pinned JSON it asserts the row count
(equal to the source entries), the playable-song count, the playable-chart count,
every title, every chart level, and that each song has at least one unit link. It
does not compare unit names. It is read-only and requires network access.

## Updating procedure

1. Run `python tools/import_catalog.py --download`.
2. Review the regenerated Dart file and `supabase/catalog-data/*.sql`.
3. Apply the batches, then `retire-missing.sql`, to the hosted project.
4. Run `python tools/verify_catalog.py`.
5. Run `flutter analyze`, `flutter test` and `flutter build web --release`.
