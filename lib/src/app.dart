import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_panel.dart';
import 'artwork.dart';
import 'character_collection.dart';
import 'export_file.dart';
import 'import_file.dart';
import 'pjsk_ui.dart';
import 'store.dart';
import 'themes.dart';


part 'score_plot.dart';
part 'screens/library_screens.dart';
part 'screens/progress_screens.dart';
part 'screens/account_screens.dart';

Widget gap([double h = 20]) => SizedBox(height: h);
String statusName(int s) => s < 0 ? 'Untracked' : statuses[s];
String number(int? n) => n == null
    ? '—'
    : n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

class SynthDexApp extends StatelessWidget {
  const SynthDexApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SynthDex',
      theme: buildAppTheme(store.theme, Brightness.light),
      darkTheme: buildAppTheme(store.theme, Brightness.dark),
      themeMode: appearanceMode(store.appearance),
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      home: AccountGate(
        accounts: store.accounts,
        child: Hub(store: store),
      ),
    ),
  );
}

class Hub extends StatefulWidget {
  const Hub({super.key, required this.store});
  final AppStore store;
  @override
  State<Hub> createState() => _HubState();
}

class _HubState extends State<Hub> {
  ColorScheme get scheme => Theme.of(context).colorScheme;
  PjskTokens get tokens => PjskTokens.of(context);
  Color get bg => Theme.of(context).scaffoldBackgroundColor;
  Color get panel =>
      scheme.surfaceContainer.withValues(alpha: tokens.isDark ? 0.90 : 0.96);
  Color get muted => scheme.onSurfaceVariant;
  Color get purple => scheme.primary;
  Color get teal => tokens.aqua;
  Color get pink => tokens.pink;
  Color statusColor(int s) => tokens.lampColor(s, muted);

  Widget label(String s, {Color? color}) => Text(
    s,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
      color: color ?? muted,
    ),
  );

  Widget box(
    Widget child, {
    Color? color,
    double padding = 18,
    bool prism = false,
  }) {
    if (prism) {
      return PjskPrismCard(
        padding: EdgeInsets.all(padding),
        backgroundColor: color ?? panel,
        rainbowOpacity: 0.55,
        child: child,
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color ?? panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: tokens.isDark ? 0.55 : 0.65,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget heading(String eyebrow, String title, String sub) =>
      PjskPageHeader(eyebrow: eyebrow, title: title, subtitle: sub);

  Widget action(
    String text,
    VoidCallback? tap, {
    bool secondary = false,
    IconData? icon,
  }) => PjskGlossyButton(
    label: text,
    onPressed: tap,
    secondary: secondary,
    icon: icon,
  );

  AppStore get s => widget.store;
  int tab = 0;
  int navDirection = 1;
  int visibleSongs = 50;
  String page = '', query = '', unit = 'All units', sort = 'Title A–Z';
  int? difficulty, filterStatus;
  bool onlyFavorites = false, missingFc = false, busy = false, newest = true;
  Song? selected;
  int chart = 3, chosenStatus = 0;
  Attempt? editing;
  final score = TextEditingController();
  final search = TextEditingController();
  final displayName = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _settingsReturnTab = 5;
  String _settingsReturnPage = 'account';
  String? formError;
  @override
  void initState() {
    super.initState();
    s.addListener(changed);
    s.accounts.addListener(changed);
    s.refresh();
  }

  String settingsTheme = 'dark', settingsAppearance = 'system';
  bool importingProgress = false;
  void _update(VoidCallback fn) => setState(fn);

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(changed);
    s.accounts.removeListener(changed);
    for (final c in [score, search, displayName]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  int _pageDepth(String p) => switch (p) {
    '' || 'account' => 0,
    'filter' || 'detail' || 'allHistory' || 'settings' || 'login' => 1,
    'record' || 'history' => 2,
    'compare' => 3,
    _ => 1,
  };

  void go(String next, {int? targetTab}) => setState(() {
    final prevTab = tab;
    final prevPage = page;
    if (next == 'settings' && prevPage != 'settings') {
      _settingsReturnTab = prevTab;
      _settingsReturnPage = prevPage;
    }
    final nextTab =
        targetTab ??
        ((next == 'account' || next == 'settings' || next == 'login')
            ? 5
            : tab);
    if (next == 'account' && prevTab != 5) {
      navDirection = 5 > prevTab ? 1 : -1;
    } else if (targetTab != null && targetTab != prevTab) {
      navDirection = -1;
    } else {
      navDirection = _pageDepth(next) >= _pageDepth(prevPage) ? 1 : -1;
    }
    page = next;
    tab = nextTab;
    formError = null;
    if (next == 'account' || next == 'settings') {
      chart = s.defaultDifficulty;
      displayName.text = s.name;
      settingsTheme = s.theme;
      settingsAppearance = s.appearance;
    }
  });
  void _handleBack() {
    if (busy) return;
    if (page == 'settings') {
      go(_settingsReturnPage, targetTab: _settingsReturnTab);
      return;
    }
    go(
      page == 'record' || page == 'history'
          ? 'detail'
          : page == 'compare'
          ? 'history'
          : page == 'login'
          ? 'account'
          : '',
    );
  }

  void navigate(int i) {
    if (i == 5) {
      if (tab == 5 && page == 'account') {
        _scrollToTop();
        return;
      }
      go('account');
      return;
    }
    if (i == tab && page.isEmpty) {
      _scrollToTop();
      return;
    }
    setState(() {
      if (i != tab) {
        navDirection = i > tab ? 1 : -1;
      } else if (page.isNotEmpty) {
        navDirection = -1;
      }
      tab = i;
      page = '';
      formError = null;
    });
  }

  void _scrollToTop() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: tokens.isDark
          ? const Color(0xFF162447)
          : const Color(0xFF0E1B3A),
      content: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
  Future<void> run(Future<void> Function() work, {String? success}) async {
    if (busy) return;
    setState(() {
      busy = true;
      formError = null;
    });
    try {
      await work();
      if (mounted && success != null) toast(success);
    } on AuthException catch (e) {
      if (mounted) setState(() => formError = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => formError = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => formError =
              'Could not save. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openSong(Song song) {
    selected = song;
    chart = song.hasChart(s.defaultDifficulty)
        ? s.defaultDifficulty
        : song.chartDifficulties.first;
    go('detail');
  }

  void openRecord({Attempt? attempt}) {
    editing = attempt;
    chosenStatus =
        attempt?.status ??
        (s.status(selected!.id, chart) < 0 ? 0 : s.status(selected!.id, chart));
    score.text = attempt?.score?.toString() ?? '';
    go('record');
  }

  Widget chip(String text, bool active, VoidCallback tap, {Color? accent}) {
    final activeColor = accent ?? (tokens.isDark ? tokens.aqua : scheme.primary);
    return ChoiceChip(
      label: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active
              ? (tokens.isDark ? Colors.white : scheme.onSurface)
              : muted,
        ),
      ),
      selected: active,
      onSelected: (_) => tap(),
      showCheckmark: false,
      selectedColor: activeColor.withValues(alpha: tokens.isDark ? 0.24 : 0.16),
      backgroundColor: tokens.isDark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
          : scheme.surfaceContainer,
      side: BorderSide(
        color: active
            ? activeColor.withValues(alpha: 0.85)
            : scheme.outlineVariant.withValues(alpha: 0.55),
        width: active ? 1.3 : 1,
      ),
      shape: const StadiumBorder(),
    );
  }

  List<(int, int)> _songLamps(Song song) => [
    for (final d in song.chartDifficulties) (d, s.status(song.id, d)),
  ];

  Widget songRow(
    Song song, {
    String? subtitle,
    int? chartDifficulty,
    int? overrideStatus,
    int? staggerIndex,
  }) {
    final preferred = chartDifficulty ?? difficulty ?? s.defaultDifficulty;
    final d = song.hasChart(preferred)
        ? preferred
        : song.chartDifficulties.first;
    final st = overrideStatus ?? s.status(song.id, d);
    final unitColor = PjskTokens.unitColor(song.unit);
    final fav = s.favorites.contains(song.id);

    final rowCard = PjskPressScale(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: fav
                  ? tokens.pink.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(
                      alpha: tokens.isDark ? 0.52 : 0.65,
                    ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                openSong(song);
                setState(() => chart = d);
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Official PJSK unit-colored left EnergyRail
                    Container(width: 4, color: unitColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 10, 4, 10),
                        child: Row(
                          children: [
                            // White-beveled song jacket
                            Container(
                              width: 50,
                              height: 50,
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: tokens.isDark ? 0.35 : 0.9,
                                  ),
                                  width: 1.2,
                                ),
                                color: Color(song.color),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ArtworkImage(
                                  url: jacketUrl(song.assetBundle),
                                  label: '${song.title} jacket',
                                  icon: Icons.music_note_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${song.artist} · ${song.unit}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  PjskSixLampStrip(
                                    statusesByDifficulty: _songLamps(song),
                                    size: 6.5,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      PjskDifficultyBadge(
                                        difficulty: d,
                                        label:
                                            '${difficulties[d].toUpperCase()} · Lv. ${song.levels[d]}',
                                      ),
                                      PjskStatusLamp(
                                        status: st,
                                        label: statusName(st).toUpperCase(),
                                      ),
                                    ],
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: fav ? 'Remove favorite' : 'Add favorite',
                              onPressed: busy
                                  ? null
                                  : () {
                                      run(() => s.favorite(song));
                                    },
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOutBack,
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  fav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey('fav-${song.id}-$fav'),
                                  color: fav ? tokens.pink : muted,
                                  size: 21,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (staggerIndex != null) {
      return PjskStaggerItem(index: staggerIndex, child: rowCard);
    }
    return rowCard;
  }

  Widget totals({bool stats = false}) {
    final total = s.chartCount(),
        cleared = s.count(1),
        ratio = total == 0 ? 0.0 : cleared / total;
    return Column(
      children: [
        PjskPrismCard(
          gradient: tokens.heroGradient,
          showArtOverlay: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats
                          ? 'TOTAL CHART COMPLETION'
                          : 'OVERALL CHART COMPLETION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: tokens.isDark ? tokens.aqua : scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(ratio * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$cleared / $total tracked charts cleared',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PjskCompletionRing(ratio: ratio, size: 78),
            ],
          ),
        ),
        gap(14),
        Row(
          children: [
            Expanded(
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PjskSlashes(height: 9),
                    const SizedBox(height: 8),
                    Text(
                      '${s.count(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        color: tokens.pink,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    gap(4),
                    label('FULL COMBOS'),
                  ],
                ),
                padding: 15,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PjskSlashes(height: 9),
                    const SizedBox(height: 8),
                    Text(
                      '${s.count(3)}',
                      style: TextStyle(
                        fontSize: 28,
                        color: tokens.isDark ? tokens.aqua : scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    gap(4),
                    label('ALL PERFECTS'),
                  ],
                ),
                padding: 15,
              ),
            ),
          ],
        ),
        gap(22),
      ],
    );
  }

  Widget content() => switch (page) {
    'filter' => filters(),
    'detail' => detail(),
    'record' => record(),
    'history' => history(),
    'allHistory' => history(all: true),
    'compare' => comparison(),
    'account' => profile(),
    'settings' => settings(),
    'login' => login(),
    _ => tab == 0 ? home() : stats(),
  };

  Widget _buildActiveBody() {
    if (page.isEmpty && (tab == 1 || tab == 2)) {
      return libraryScrollView();
    }
    if (page.isEmpty && tab == 4) {
      return CharacterCollection(
        store: s,
        scrollController: _scroll,
        onRefresh: () => s.refresh(force: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => s.refresh(force: true),
      child: ListView(
        key: PageStorageKey('$tab/$page'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, page.isEmpty ? 22 : 8, 20, 24),
        children: [
          if (s.loading) const LinearProgressIndicator(),
          if (s.error != null) ...[
            box(
              Column(
                children: [
                  Text(s.error!),
                  TextButton(
                    onPressed: () => s.refresh(force: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            gap(),
          ],
          if (formError != null && page != 'record') ...[
            box(
              Text(formError!, style: TextStyle(color: tokens.pink)),
              prism: true,
            ),
            gap(),
          ],
          content(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: page.isEmpty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && page.isNotEmpty) {
        _handleBack();
      }
    },
    child: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PjskStageBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        child: page.isEmpty
                            ? const SizedBox.shrink(key: ValueKey('topbar-none'))
                            : Padding(
                                key: ValueKey('topbar-$page'),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  2,
                                ),
                                child: SizedBox(
                                  height: 44,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: page == 'account'
                                              ? const SizedBox.shrink()
                                              : TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    minimumSize: const Size(
                                                      0,
                                                      36,
                                                    ),
                                                    backgroundColor: scheme
                                                        .surfaceContainer
                                                        .withValues(
                                                          alpha: 0.72,
                                                        ),
                                                    shape:
                                                        const StadiumBorder(),
                                                    side: BorderSide(
                                                      color: scheme
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.55,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: busy
                                                      ? null
                                                      : _handleBack,
                                                  icon: const Icon(
                                                    Icons.arrow_back_rounded,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Back',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (page == 'account')
                                        IconButton(
                                          tooltip: 'Settings',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 40,
                                                height: 40,
                                              ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: busy
                                              ? null
                                              : () => go('settings'),
                                          icon: const Icon(
                                            Icons.settings_outlined,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: PjskStageTransition(
                        transitionKey: ValueKey('$tab/$page'),
                        direction: navDirection,
                        child: _buildActiveBody(),
                      ),
                    ),
                    PjskBottomNav(currentIndex: tab, onSelect: navigate),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

