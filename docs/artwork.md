# Artwork and caching

Artwork is loaded from a public CDN. Only the asset identity is stored; URLs are
derived on the client, so a host change never requires a data migration.

## Base URL

```sh
flutter run --dart-define=ARTWORK_BASE_URL=https://your-mirror.example/assets
```

The default is `https://storage.sekai.best/sekai-en-assets` (`artworkBase` in
`lib/src/artwork.dart`).

## URL patterns

| Kind | Path | Builder |
| --- | --- | --- |
| Song jacket | `{base}/music/jacket/{bundle}/{bundle}.webp` | `jacketUrl(bundle)` |
| Card, original | `{base}/character/member/{bundle}/card_normal.webp` | `cardArtUrl(bundle)` |
| Card, trained | `{base}/character/member/{bundle}/card_after_training.webp` | `cardArtUrl(bundle, trained: true)` |
| Character portrait | `{base}/character/character_select/chr_tl_{id}.webp` | `characterPortraitUrl(id)` |

An empty bundle yields `null`, and the widget renders its placeholder rather than
requesting an invalid URL.

## Asset identity

Bundles are facts of the data, not of the UI:

- `lib/src/artwork_data.g.dart` maps song ids to jacket bundles
  (`songAssetBundles`) and card ids to card bundles (`cardAssetBundles`).
- `songs.asset_bundle` and `character_cards.asset_bundle` carry the same values
  for remote catalogs. `Song.assetBundle` prefers the remote value and falls back
  to the bundled map.
- `CharacterCard.assetBundle` reads the bundled map directly.

### What the generator writes

`python tools/import_artwork.py` reads `musics.json` and `cards.json` from the
pinned snapshot and writes exactly three files:

| File | Contents |
| --- | --- |
| `lib/src/artwork_data.g.dart` | `songAssetBundles` and `cardAssetBundles` |
| `supabase/artwork_songs.sql` | One `update public.songs ... from jsonb_to_recordset` statement |
| `supabase/artwork_character_cards.sql` | One `update public.character_cards ...` statement |

Details that matter when re-running it:

- Song keys use the same legacy aliases as the catalog (`tell-your-world`,
  `cinema`, `king`, `bug`), so they match `songs.id`; cards are keyed by integer
  id.
- Both maps are built from the whole pinned snapshot. `cardAssetBundles` therefore
  covers every card in `cards.json`, while the in-app roster only shows cards
  released by `as_of`; the extra entries are simply unused.
- The two SQL files only set values. The columns come from the hand-written
  migration `supabase/artwork.sql` (`alter table ... add column asset_bundle
  text`), which is **not** generated: apply it first, then the generated updates.
- It prints `Mapped <n> song jackets and <n> card asset bundles`. Review the
  generated SQL before applying it.

## Rendering

`ArtworkImage` is the single entry point. It always:

- wraps the image in `Semantics(image: true, label: ...)` so screen readers get a
  meaningful description instead of an unlabeled bitmap;
- clips to a 12 px radius and fills its box with `BoxFit.cover`;
- shows a themed surface placeholder with an icon while loading;
- on failure shows a retry button with the tooltip `Artwork unavailable. Retry`.

Platform strategy:

- **Web** uses `Image.network` with `WebHtmlElementStrategy.fallback`. The
  third-party CDN does not always send CORS headers that allow canvas decoding,
  so Flutter falls back to an `<img>` element instead of failing.
- **Native** uses `CachedNetworkImage` with zero fade in/out so lists do not
  flash, backed by the platform cache.

Retry evicts before rebuilding, using `CachedNetworkImage.evictFromCache` on
native and `NetworkImage.evict` on web, then bumps the widget key. Eviction never
throws into the widget tree.

## Previews

- `showJacket` opens a square (`AspectRatio 1`) dialog with `InteractiveViewer`
  zoom and a "Close artwork" button, labeled "<title> jacket".
- `CardArtwork` renders cards at the real 2048×1261 ratio with the same zoomable
  dialog. When the card is rarity 3 or 4 it shows Original/Trained choice chips;
  the label includes which variant is displayed. Switching cards resets the
  variant to Original.

## Offline behavior

Artwork is always optional. Missing images degrade to a labeled placeholder with
a retry affordance, and no screen depends on an image to function. Local progress
and the catalog never wait on the CDN.

## Tests

- `test/artwork_test.dart` — offline. It asserts that every bundled song and card
  has a non-empty bundle, that a cached song without `asset_bundle` falls back to
  the bundled map (`jacket_s_001`), the jacket and trained-card URL shapes, that
  birthday cards never expose trained artwork, that a null URL renders the stable
  `Icons.image_outlined` placeholder at its box size without throwing, and that
  the Original/Trained switch changes only the URL while the zoom dialog opens and
  closes.
- `test/artwork_browser_test.dart` — a live CDN smoke test, skipped by default:

  ```sh
  flutter test --platform chrome --dart-define=LIVE_ARTWORK=true test/artwork_browser_test.dart
  ```

  It loads a song jacket, an original card, a trained card and a recent card with
  a 40 s timeout, and asserts non-zero image dimensions with no
  `Artwork unavailable. Retry` placeholder. Because it goes through
  `artworkBase`, pairing it with `--dart-define=ARTWORK_BASE_URL=...` is how a
  mirror is checked.

## Live CDN probe

```sh
dart run tools/verify_artwork.dart
```

This is a network probe, not a coverage check of the generated maps. It requests
four hard-coded paths — `jacket_s_001`, `res001_no001` (original), `res001_no004`
(trained) and `res008_no049` — from the hard-coded
`https://storage.sekai.best/sekai-en-assets` base, so it ignores
`ARTWORK_BASE_URL`. For each path it prints the status code, whether the bytes
carry the `RIFF`/`WEBP` signature, and the byte length, and it sets a non-zero
exit code if any response is not `200` or is not WebP. It says nothing about
whether every song or card in the snapshot has a bundle.
