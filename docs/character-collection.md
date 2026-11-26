# Characters and card collection

The roster and card list come from the same pinned Global snapshot as the song
catalog (see [song catalog](song-catalog.md)). Ownership is personal data and is
stored locally first; it reaches the database only through an explicit backup.

## Data

`python tools/import_characters.py` generates everything:

| Output | Contents |
| --- | --- |
| `lib/src/characters.g.dart` | `gameCharacters` and `gameCards` |
| `supabase/character-data/characters.sql` | 26 character rows |
| `supabase/character-data/cards-XX.sql` | Cards, 300 per batch |
| `docs/character-provenance.json` | Repository, commit, `as_of` and counts |

Inputs are `gameCharacters.json`, `characterProfiles.json` and `cards.json` in
`tools/catalog-source/`, plus `provenance.json` for the `as_of` cutoff. Only cards
with `releaseAt <= as_of` are included, which yields **1,256 released Global
cards** across **26 characters**.

Display names join the master-data fields: characters with id up to 20 use
`givenName` then `firstName`, later ids use `firstName` then `givenName`, and
empty parts are skipped.

Characters carry unit, birthday, voice, height and hobby from the profile file;
missing profile fields become empty strings. Unit ids map as `light_sound` →
Leo/need, `idol` → MORE MORE JUMP!, `street` → Vivid BAD SQUAD, `theme_park` →
Wonderlands × Showtime, `school_refusal` → 25-ji, Nightcord de. and `piapro` →
Virtual Singer.

Cards carry id, character id, title (`prefix`), rarity, attribute and release
time. The rarity
is the master-data type without its `rarity_` prefix, so values are `1`, `2`,
`3`, `4` or `birthday`; `rarityLabel` renders `Birthday` or `N★`. Attributes are
`cool`, `cute`, `happy`, `mysterious` and `pure`. Cards of rarity 3 and 4 expose
trained artwork; see [artwork and caching](artwork.md).

## Local model

A card is tracked as `CollectedCard(cardId, owned, wishlist)`. Entries live in
the `cards` array of the single local document (`synthdex.personal.v1`), are
deduplicated by card id, and are dropped entirely when neither flag is set, so
clearing both flags leaves no residue.

Validation runs on every load and every write:

- the card id must exist in the merged roster (bundled cards plus any cached
  refresh);
- no duplicate card ids;
- `owned` or `wishlist` must be true.

A document that fails validation is preserved untouched and reported, and
mutations are refused until the user restores a backup or resets local data.
Validation checks card ids against the merged roster, and a refresh retains
cards that disappear upstream, so a catalog refresh cannot invalidate a saved
collection. A backup that references a card newer than both this build and its
cached roster is still rejected.

Collection changes are serialized through the same write queue as scores, so a
rapid Owned/Wishlist toggle cannot interleave with another save.

## Interface

`CharacterCollection` offers two views:

- **Characters** — roster list with unit subtitle, plus a profile panel showing
  birthday, voice, height and hobbies when a character is selected.
- **Cards** — one panel per card with artwork, title, character link, rarity,
  attribute and id, plus Owned and Wishlist chips.

Filters available in card view: unit, collection state (`All cards`, `Owned`,
`Wishlist`, `Not owned`), rarity (`1★` to `4★`, `Birthday`) and attribute. Search
matches card title or character name. Results sort by descending card id and page
in blocks of 30 with a "Show more" button that reports the remaining count.

Profile shows the owned total (`collectedCardCount`), and the collection header
shows owned and wishlist counts. Total owned cards is independent of song
progress. Reset in Settings clears the collection along with attempts and
favorites; backups include it.

## Database

| Table | Key | Notes |
| --- | --- | --- |
| `characters` | `id` | `unit_id → units`, profile fields |
| `card_rarities` | `id` | `1`, `2`, `3`, `4`, `birthday` |
| `card_attributes` | `id` | `cool`, `cute`, `happy`, `mysterious`, `pure` |
| `character_cards` | `id` | `character_id`, `rarity_id`, `attribute_id`, `released_at`, `asset_bundle` |
| `card_collection` | `(user_id, card_id)` | `owned`, `wishlist`, `check(owned or wishlist)` |

Catalog tables are readable by `anon` and `authenticated` through `catalog_read`
policies. `card_collection` is owner-only through `own_collection`, which compares
`auth.uid()` with `user_id` for both `using` and `with check`. `anon` is revoked.

Backups reach cards through `save_backup_v2`/`load_backup_v3`; the v1 RPC is kept
so older clients still save attempts and favorites without erasing a collection.
