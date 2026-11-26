import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette(this.id, this.name, this.colors, this.seed);
  final String id, name;
  final List<Color> colors;
  final Color seed;
}

// Keep legacy IDs so existing local data and backups remain readable.
const appPalettes = [
  AppPalette('dark', 'Violet Nocturne', [
    Color(0xff0c0d1d),
    Color(0xffb99bff),
    Color(0xff70e5d9),
    Color(0xfffa8acb),
  ], Color(0xff8c61cf)),
  AppPalette('crimson', 'Crimson Pulse', [
    Color(0xff000000),
    Color(0xff3d0000),
    Color(0xff950101),
    Color(0xffff0000),
  ], Color(0xff950101)),
  AppPalette('mint', 'Mint Reverie', [
    Color(0xff0abab5),
    Color(0xff56dfcf),
    Color(0xffadeed9),
    Color(0xffffedf3),
  ], Color(0xff0abab5)),
  AppPalette('peach', 'Peach Petal', [
    Color(0xffffced8),
    Color(0xffffdddd),
    Color(0xfffff4de),
    Color(0xffffe8c4),
  ], Color(0xffffced8)),
  AppPalette('forest', 'Forest Echo', [
    Color(0xff092328),
    Color(0xff12544f),
    Color(0xff2a835f),
    Color(0xff8bbb92),
  ], Color(0xff2a835f)),
  AppPalette('azure', 'Azure Skies', [
    Color(0xffe3f2fd),
    Color(0xff90caf9),
    Color(0xff2196f3),
    Color(0xff0d47a1),
  ], Color(0xff2196f3)),
  AppPalette('solar', 'Solar Encore', [
    Color(0xffe73f1e),
    Color(0xfffb6c00),
    Color(0xfff9b637),
    Color(0xffffdd9c),
  ], Color(0xfffb6c00)),
  AppPalette('amoled', 'Obsidian Violet', [
    Color(0xff000000),
    Color(0xff191a2d),
    Color(0xffb99bff),
    Color(0xff70e5d9),
  ], Color(0xff8c61cf)),
];

bool validPalette(Object? id) => appPalettes.any((p) => p.id == id);
const appearanceChoices = ['system', 'light', 'dark'];
ThemeMode appearanceMode(String mode) => switch (mode) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

ThemeData buildAppTheme(String id, Brightness brightness) {
  final palette = appPalettes.firstWhere(
    (p) => p.id == id,
    orElse: () => appPalettes.first,
  );
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: palette.seed,
    brightness: brightness,
    secondary: ColorScheme.fromSeed(
      seedColor: palette.colors[2],
      brightness: brightness,
    ).primary,
    tertiary: ColorScheme.fromSeed(
      seedColor: palette.colors[3],
      brightness: brightness,
    ).primary,
  );
  // Preserve the original identity in dark mode, with a matching light variant.
  if (dark && (id == 'dark' || id == 'amoled')) {
    scheme = scheme.copyWith(
      primary: const Color(0xffb99bff),
      onPrimary: const Color(0xff201038),
      secondary: const Color(0xff70e5d9),
      tertiary: const Color(0xfffa8acb),
      surface: const Color(0xff0c0d1d),
      surfaceContainer: const Color(0xff191a2d),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: dark && id == 'amoled'
        ? Colors.black
        : scheme.surface,
    fontFamily: 'Inter',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
