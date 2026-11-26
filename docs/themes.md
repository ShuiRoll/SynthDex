# Themes

Eight named palettes, each usable in System, Light or Dark appearance. Palette ids
are stable: they are written into local data and cloud backups, so renaming a
palette must not change its id.

## Palettes

| Id | Name | Colours (base, accent, secondary seed, tertiary seed) | Seed |
| --- | --- | --- | --- |
| `dark` | Violet Nocturne | `#0c0d1d` `#b99bff` `#70e5d9` `#fa8acb` | `#8c61cf` |
| `crimson` | Crimson Pulse | `#000000` `#3d0000` `#950101` `#ff0000` | `#950101` |
| `mint` | Mint Reverie | `#0abab5` `#56dfcf` `#adeed9` `#ffedf3` | `#0abab5` |
| `peach` | Peach Petal | `#ffced8` `#ffdddd` `#fff4de` `#ffe8c4` | `#ffced8` |
| `forest` | Forest Echo | `#092328` `#12544f` `#2a835f` `#8bbb92` | `#2a835f` |
| `azure` | Azure Skies | `#e3f2fd` `#90caf9` `#2196f3` `#0d47a1` | `#2196f3` |
| `solar` | Solar Encore | `#e73f1e` `#fb6c00` `#f9b637` `#ffdd9c` | `#fb6c00` |
| `amoled` | Obsidian Violet | `#000000` `#191a2d` `#b99bff` `#70e5d9` | `#8c61cf` |

`dark` is the default for new and reset data.

## How a theme is built

`buildAppTheme(id, brightness)` seeds a Material 3 `ColorScheme` from the palette
seed. `secondary` and `tertiary` come from two further seeded schemes built on the
third and fourth palette colours (their generated `primary`), and the theme keeps
the Inter font family.

Two palettes carry an identity override in dark mode:

- `dark` and `amoled` fix primary `#b99bff`, onPrimary `#201038`, secondary
  `#70e5d9`, tertiary `#fa8acb`, surface `#0c0d1d` and surface container
  `#191a2d`, so the original violet design survives Material's seeded scheme.
- `amoled` additionally uses pure black as the scaffold background.

Shared component styling: filled inputs with 11 px rounded borders, and floating
snackbars.

## Appearance

`system`, `light` and `dark` map to `ThemeMode`, so System follows the device and
updates live when the OS changes. An explicit choice overrides the device.
`test/themes_test.dart` covers both behaviors.

## Storage and validation

`theme` and `appearance` live in the local document alongside scores. On load,
`validPalette` and `appearanceChoices` reject unknown values, and an invalid
document is preserved and reported rather than partially applied. Reset returns
to `dark` / `system`.

Guests can switch palette, appearance and default difficulty. Editing the display
name requires sign-in; Profile and Settings are separate screens. Settings opens
from the top-right gear on Profile and holds the theme and appearance dropdowns
plus the reset action.

## Database

`preferences.theme` is constrained to the eight ids and `preferences.appearance`
to `system`, `light`, `dark` with default `system`. `appearance.sql` widens the
theme constraint from the original `dark`/`amoled` pair to all eight and adds the
appearance column with its own check; backups carry the appearance through
`save_backup_v3` and `load_backup_v3`.
