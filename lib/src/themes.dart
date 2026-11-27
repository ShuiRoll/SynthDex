import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette(this.id, this.name, this.colors, this.seed);
  final String id, name;
  final List<Color> colors;
  final Color seed;
}

/// Official Project SEKAI: COLORFUL STAGE! semantic design tokens attached
/// to [ThemeData] via [ThemeExtension].
@immutable
class PjskTokens extends ThemeExtension<PjskTokens> {
  const PjskTokens({
    required this.isDark,
    required this.aqua,
    required this.aquaBright,
    required this.aquaInk,
    required this.pink,
    required this.gold,
    required this.violet,
    required this.rainbow,
    required this.heroGradient,
    required this.stageGradient,
    required this.cardSurface,
    required this.cardBorder,
  });

  final bool isDark;
  final Color aqua;
  final Color aquaBright;
  final Color aquaInk;
  final Color pink;
  final Color gold;
  final Color violet;
  final List<Color> rainbow;
  final List<Color> heroGradient;
  final List<Color> stageGradient;
  final Color cardSurface;
  final Color cardBorder;

  /// Official PJSK 6-difficulty colors:
  /// 0 Easy, 1 Normal, 2 Hard, 3 Expert, 4 Master, 5 Append.
  Color difficultyColor(int difficulty) {
    if (isDark) {
      return switch (difficulty) {
        0 => const Color(0xFF66DD11),
        1 => const Color(0xFF33BBEE),
        2 => const Color(0xFFFFAA00),
        3 => const Color(0xFFEE4466),
        4 => const Color(0xFFBB44EE),
        5 => const Color(0xFFF066FF),
        _ => aqua,
      };
    }
    return switch (difficulty) {
      0 => const Color(0xFF3EA600),
      1 => const Color(0xFF0E8AD4),
      2 => const Color(0xFFD67F00),
      3 => const Color(0xFFD92652),
      4 => const Color(0xFF9327D4),
      5 => const Color(0xFFC82CE6),
      _ => aqua,
    };
  }

  /// Official PJSK Clear Lamp colors:
  /// -1 Untracked, 0 Uncleared, 1 Clear (Gold), 2 Full Combo (Pink), 3 All Perfect (Aqua/Prism).
  Color lampColor(int status, Color muted) => switch (status) {
    1 => gold,
    2 => pink,
    3 => aqua,
    _ => muted,
  };

  /// Official Project SEKAI unit accent colors.
  static Color unitColor(String unit) {
    final lower = unit.toLowerCase();
    if (lower.contains('leo/need')) return const Color(0xFF3388FF);
    if (lower.contains('more more jump')) return const Color(0xFF55DD66);
    if (lower.contains('vivid bad')) return const Color(0xFFEE3366);
    if (lower.contains('wonderlands')) return const Color(0xFFFF9900);
    if (lower.contains('nightcord') || lower.contains('25-ji')) {
      return const Color(0xFF9955EE);
    }
    if (lower.contains('virtual')) return const Color(0xFF00CCBB);
    return const Color(0xFF00CCBB);
  }

  static PjskTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<PjskTokens>();
    if (ext != null) return ext;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? PjskTokens.darkDefault : PjskTokens.lightDefault;
  }

  static const darkDefault = PjskTokens(
    isDark: true,
    aqua: Color(0xFF00E5D0),
    aquaBright: Color(0xFF4CF7E6),
    aquaInk: Color(0xFF061B26),
    pink: Color(0xFFFF55AA),
    gold: Color(0xFFFFCC33),
    violet: Color(0xFFBB44EE),
    rainbow: [
      Color(0xFF00E5D0),
      Color(0xFFFFCC33),
      Color(0xFFFF55AA),
      Color(0xFFBB44EE),
    ],
    heroGradient: [
      Color(0xFF11234C),
      Color(0xFF21174A),
      Color(0xFF0E1733),
    ],
    stageGradient: [
      Color(0xFF0B1328),
      Color(0xFF111532),
      Color(0xFF0A0D1D),
    ],
    cardSurface: Color(0xFF131D38),
    cardBorder: Color(0xFF2A3C6B),
  );

  static const lightDefault = PjskTokens(
    isDark: false,
    aqua: Color(0xFF00B8A8),
    aquaBright: Color(0xFF3DF5E3),
    aquaInk: Color(0xFF051E24),
    pink: Color(0xFFE0287E),
    gold: Color(0xFFD68600),
    violet: Color(0xFF8B38DB),
    rainbow: [
      Color(0xFF00CCBB),
      Color(0xFFFFAA00),
      Color(0xFFFF4499),
      Color(0xFF9933EE),
    ],
    heroGradient: [
      Color(0xFFE2FAF6),
      Color(0xFFF1EAFF),
      Color(0xFFFFEBF5),
    ],
    stageGradient: [
      Color(0xFFF2FAFF),
      Color(0xFFF6F3FF),
      Color(0xFFFFF4FA),
    ],
    cardSurface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFCADAF5),
  );

  @override
  PjskTokens copyWith({
    bool? isDark,
    Color? aqua,
    Color? aquaBright,
    Color? aquaInk,
    Color? pink,
    Color? gold,
    Color? violet,
    List<Color>? rainbow,
    List<Color>? heroGradient,
    List<Color>? stageGradient,
    Color? cardSurface,
    Color? cardBorder,
  }) => PjskTokens(
    isDark: isDark ?? this.isDark,
    aqua: aqua ?? this.aqua,
    aquaBright: aquaBright ?? this.aquaBright,
    aquaInk: aquaInk ?? this.aquaInk,
    pink: pink ?? this.pink,
    gold: gold ?? this.gold,
    violet: violet ?? this.violet,
    rainbow: rainbow ?? this.rainbow,
    heroGradient: heroGradient ?? this.heroGradient,
    stageGradient: stageGradient ?? this.stageGradient,
    cardSurface: cardSurface ?? this.cardSurface,
    cardBorder: cardBorder ?? this.cardBorder,
  );

  @override
  PjskTokens lerp(ThemeExtension<PjskTokens>? other, double t) {
    if (other is! PjskTokens) return this;
    return PjskTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      aquaBright: Color.lerp(aquaBright, other.aquaBright, t)!,
      aquaInk: Color.lerp(aquaInk, other.aquaInk, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      rainbow: t < 0.5 ? rainbow : other.rainbow,
      heroGradient: t < 0.5 ? heroGradient : other.heroGradient,
      stageGradient: t < 0.5 ? stageGradient : other.stageGradient,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }
}

// Keep legacy IDs so existing local data and backups remain readable.
const appPalettes = [
  AppPalette('dark', 'Violet Nocturne', [
    Color(0xff0b1226),
    Color(0xff00e5d0),
    Color(0xffbb99ff),
    Color(0xffff55aa),
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
    Color(0xff141d38),
    Color(0xff00e5d0),
    Color(0xffff55aa),
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

  // Project SEKAI: COLORFUL STAGE! signature Night Stage (Dark) & SEKAI Lobby (Light)
  if (dark && (id == 'dark' || id == 'amoled')) {
    scheme = scheme.copyWith(
      primary: const Color(0xFF00E5D0),
      onPrimary: const Color(0xFF061B26),
      primaryContainer: const Color(0xFF17274E),
      onPrimaryContainer: const Color(0xFFEAF6FF),
      secondary: const Color(0xFF66EFE0),
      onSecondary: const Color(0xFF061B26),
      tertiary: const Color(0xFFFF6EB8),
      onTertiary: const Color(0xFF2B071B),
      surface: const Color(0xFF0B1226),
      onSurface: const Color(0xFFF2F6FF),
      onSurfaceVariant: const Color(0xFFA6B6D9),
      surfaceContainer: const Color(0xFF141E3A),
      surfaceContainerHighest: const Color(0xFF1E2B4F),
      outlineVariant: const Color(0xFF2B3D6B),
    );
  } else if (!dark && id == 'dark') {
    scheme = scheme.copyWith(
      primary: const Color(0xFF00736B),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFE0F7F4),
      onPrimaryContainer: const Color(0xFF072B29),
      secondary: const Color(0xFF6D35D6),
      onSecondary: const Color(0xFFFFFFFF),
      tertiary: const Color(0xFFC41D73),
      onTertiary: const Color(0xFFFFFFFF),
      surface: const Color(0xFFF3F8FF),
      onSurface: const Color(0xFF0E1B3A),
      onSurfaceVariant: const Color(0xFF425478),
      surfaceContainer: const Color(0xFFFFFFFF),
      surfaceContainerHighest: const Color(0xFFE5EEFC),
      outlineVariant: const Color(0xFFCADAF5),
    );
  }

  final isDefaultPjsk = id == 'dark' || id == 'amoled';
  final pjsk = dark
      ? PjskTokens.darkDefault.copyWith(
          aqua: isDefaultPjsk ? const Color(0xFF00E5D0) : scheme.primary,
          aquaBright: isDefaultPjsk
              ? const Color(0xFF4CF7E6)
              : Color.lerp(scheme.primary, Colors.white, 0.25)!,
          aquaInk: isDefaultPjsk ? const Color(0xFF061B26) : scheme.onPrimary,
          cardSurface: scheme.surfaceContainer,
          cardBorder: scheme.outlineVariant,
          stageGradient: id == 'amoled'
              ? const [Color(0xFF000000), Color(0xFF0A0F24), Color(0xFF000000)]
              : isDefaultPjsk
              ? PjskTokens.darkDefault.stageGradient
              : [
                  scheme.surface,
                  Color.lerp(scheme.surface, scheme.primaryContainer, 0.35)!,
                  scheme.surface,
                ],
          heroGradient: isDefaultPjsk
              ? PjskTokens.darkDefault.heroGradient
              : [
                  Color.lerp(scheme.surfaceContainer, scheme.primary, 0.22)!,
                  scheme.primaryContainer,
                  scheme.surfaceContainer,
                ],
        )
      : PjskTokens.lightDefault.copyWith(
          aqua: isDefaultPjsk ? const Color(0xFF00B8A8) : scheme.primary,
          aquaBright: isDefaultPjsk
              ? const Color(0xFF3DF5E3)
              : Color.lerp(scheme.primary, Colors.white, 0.14)!,
          aquaInk: isDefaultPjsk ? const Color(0xFF051E24) : scheme.onPrimary,
          cardSurface: scheme.surfaceContainer,
          cardBorder: scheme.outlineVariant,
          stageGradient: isDefaultPjsk
              ? PjskTokens.lightDefault.stageGradient
              : [
                  scheme.surface,
                  Color.lerp(scheme.surface, scheme.primaryContainer, 0.3)!,
                  scheme.surface,
                ],
          heroGradient: isDefaultPjsk
              ? PjskTokens.lightDefault.heroGradient
              : [
                  Color.lerp(scheme.surfaceContainer, scheme.primaryContainer, 0.65)!,
                  scheme.primaryContainer,
                  Color.lerp(scheme.surfaceContainer, scheme.tertiaryContainer, 0.35)!,
                ],
        );

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    extensions: [pjsk],
    scaffoldBackgroundColor: dark && id == 'amoled'
        ? Colors.black
        : scheme.surface,
    fontFamily: 'Inter',
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? scheme.surfaceContainer.withValues(alpha: 0.92)
          : scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: pjsk.aqua, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: pjsk.aqua.withValues(alpha: 0.45), width: 1.2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: pjsk.aqua.withValues(alpha: 0.5)),
      ),
    ),
  );
}
