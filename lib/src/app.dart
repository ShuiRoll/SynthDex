import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store.dart';
import 'account_panel.dart';
import 'character_collection.dart';
import 'artwork.dart';
import 'export_file.dart';
import 'import_file.dart';
import 'themes.dart';

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
  Color get bg => Theme.of(context).scaffoldBackgroundColor;
  Color get panel => scheme.surfaceContainer;
  Color get muted => scheme.onSurfaceVariant;
  Color get purple => scheme.primary;
  Color get teal => scheme.secondary;
  Color get pink => scheme.tertiary;
  Color statusColor(int s) => s == 3
      ? teal
      : s == 2
      ? pink
      : s == 1
      ? purple
      : muted;

  Widget label(String s, {Color? color}) => Text(
    s,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: color ?? muted,
    ),
  );

  Widget box(Widget child, {Color? color, double padding = 18}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color ?? panel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
  Widget heading(String eyebrow, String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      label(eyebrow, color: teal),
      gap(18),
      Text(title, style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
      gap(10),
      Text(sub, style: TextStyle(color: muted, fontSize: 12)),
      gap(26),
    ],
  );
  Widget action(
    String text,
    VoidCallback? tap, {
    bool secondary = false,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? scheme.surfaceContainerHighest : purple,
        foregroundColor: secondary ? scheme.onSurface : scheme.onPrimary,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: tap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ),
  );

  AppStore get s => widget.store;
  int tab = 0;
  int visibleSongs = 50;
  String page = '', query = '', unit = 'All units', sort = 'Title A–Z';
  int? difficulty, filterStatus;
  bool onlyFavorites = false, missingFc = false, busy = false, newest = true;
  Song? selected;
  int chart = 3, chosenStatus = 0;
  Attempt? editing;
  final score = TextEditingController();
  final search = TextEditingController();
  final email = TextEditingController(),
      password = TextEditingController(),
      displayName = TextEditingController();
  String? formError;
  @override
  void initState() {
    super.initState();
    s.addListener(changed);
    s.accounts.addListener(changed);
    s.refresh();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(changed);
    s.accounts.removeListener(changed);
    for (final c in [score, search, email, password, displayName]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(String next) => setState(() {
    page = next;
    if (next == 'account' || next == 'settings' || next == 'login') tab = 5;
    formError = null;
    if (next == 'account' || next == 'settings') {
      chart = s.defaultDifficulty;
      displayName.text = s.name;
      settingsTheme = s.theme;
      settingsAppearance = s.appearance;
    }
  });
  void navigate(int i) {
    if (i == 5) {
      go('account');
      return;
    }
    setState(() {
      tab = i;
      page = '';
      formError = null;
    });
  }

  void toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  Widget chip(String text, bool active, VoidCallback tap) => ChoiceChip(
    label: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: active ? scheme.onPrimaryContainer : muted,
      ),
    ),
    selected: active,
    onSelected: (_) => tap(),
    showCheckmark: false,
    selectedColor: scheme.primaryContainer,
    backgroundColor: scheme.surfaceContainerHighest,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  );
  Widget songRow(Song song, {String? subtitle, int? chartDifficulty}) {
    final preferred = chartDifficulty ?? difficulty ?? s.defaultDifficulty;
    final d = song.hasChart(preferred)
        ? preferred
        : song.chartDifficulties.first;
    return Padding(
      padding: EdgeInsets.only(bottom: 11),
      child: Material(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            openSong(song);
            setState(() => chart = d);
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 11, 4, 11),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Color(song.color),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: ArtworkImage(
                    url: jacketUrl(song.assetBundle),
                    label: '${song.title} jacket',
                    icon: Icons.music_note,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      gap(6),
                      Text(
                        song.unit,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      gap(6),
                      Text(
                        subtitle ??
                            '${difficulties[d].toUpperCase()} · ${statusName(s.status(song.id, d)).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: s.favorites.contains(song.id)
                      ? 'Remove favorite'
                      : 'Add favorite',
                  onPressed: busy
                      ? null
                      : () {
                          run(() => s.favorite(song));
                        },
                  icon: Icon(
                    s.favorites.contains(song.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: s.favorites.contains(song.id) ? pink : muted,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget totals({bool stats = false}) {
    final total = s.chartCount(),
        cleared = s.count(1),
        ratio = total == 0 ? 0.0 : cleared / total;
    return Column(
      children: [
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(
                stats ? 'TOTAL CHART COMPLETION' : 'OVERALL CHART COMPLETION',
                color: purple,
              ),
              gap(10),
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 44,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              gap(10),
              Text(
                '$cleared / $total tracked charts cleared',
                style: TextStyle(fontSize: 12),
              ),
              gap(10),
              LinearProgressIndicator(
                value: ratio,
                color: teal,
                backgroundColor: scheme.primaryContainer,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          color: scheme.primaryContainer,
          padding: 20,
        ),
        gap(18),
        Row(
          children: [
            Expanded(
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.count(2)}',
                      style: TextStyle(
                        fontSize: 27,
                        color: pink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    gap(10),
                    label('FULL COMBOS'),
                  ],
                ),
                padding: 15,
              ),
            ),
            SizedBox(width: 24),
            Expanded(
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.count(3)}',
                      style: TextStyle(
                        fontSize: 27,
                        color: teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    gap(10),
                    label('ALL PERFECTS'),
                  ],
                ),
                padding: 15,
              ),
            ),
          ],
        ),
        gap(24),
      ],
    );
  }

  Widget home() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'SYNTHDEX / PROJECT SEKAI',
        'Next to play',
        'Pick a chart, make a little progress.',
      ),
      label('QUICK ACTIONS'),
      gap(10),
      Wrap(
        spacing: 8,
        children: [
          chip('Browse library', true, () => navigate(1)),
          chip('Favorites ♡', false, () => navigate(2)),
          chip('History ↗', false, () => go('allHistory')),
          chip('Card collection', false, () => navigate(4)),
        ],
      ),
      gap(24),
      Text(
        'Work on ${difficulties[s.defaultDifficulty]}',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      gap(8),
      Text(
        'Charts without a recorded clear. Favorites come first, then lower levels.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      gap(12),
      if (s.nextSongs.isEmpty)
        box(
          Text(
            'Every available chart at this difficulty has a recorded clear. Try another difficulty in Settings.',
            style: TextStyle(color: muted),
          ),
        ),
      ...s.nextSongs.map(
        (song) => songRow(
          song,
          chartDifficulty: s.defaultDifficulty,
          subtitle:
              '${difficulties[s.defaultDifficulty].toUpperCase()} · LV. ${song.levels[s.defaultDifficulty]} · ${statusName(s.status(song.id, s.defaultDifficulty)).toUpperCase()}',
        ),
      ),
      gap(24),
      Text(
        'Latest activity',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      gap(12),
      if (s.attempts.isEmpty)
        box(
          Text(
            'Your next milestone starts here. Open a song and save your first attempt.',
            style: TextStyle(color: muted),
          ),
        ),
      ...s.recentAttempts.map(
        (attempt) => songRow(
          s.songById(attempt.songId),
          chartDifficulty: attempt.difficulty,
          subtitle:
              '${difficulties[attempt.difficulty]} · ${statusName(attempt.status)}${attempt.active ? '' : ' · Archived'} · ${attempt.date.toLocal().toString().substring(0, 10)}',
        ),
      ),
    ],
  );
  List<Song> get filtered {
    final list = s.songs.where((song) {
      if ((tab == 2 || onlyFavorites) && !s.favorites.contains(song.id)) {
        return false;
      }
      if (!'${song.title} ${song.artist} ${song.unit} ${song.searchAlias}'
          .toLowerCase()
          .contains(query.toLowerCase())) {
        return false;
      }
      if (unit != 'All units' && !song.unitNames.contains(unit)) return false;
      final ds = difficulty == null ? song.chartDifficulties : [difficulty!];
      return ds.any(
        (d) =>
            song.hasChart(d) &&
            (filterStatus == null || s.status(song.id, d) == filterStatus) &&
            (!missingFc || s.status(song.id, d) < 2),
      );
    }).toList();
    list.sort(
      (a, b) => sort == 'Title Z–A'
          ? b.title.compareTo(a.title)
          : sort == 'Level high–low'
          ? b.levels[difficulty ?? 3].compareTo(a.levels[difficulty ?? 3])
          : a.title.compareTo(b.title),
    );
    return list;
  }

  Widget library() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        tab == 2 ? 'YOUR COLLECTION' : 'PRELOADED SONG CATALOG',
        tab == 2 ? 'Favorite songs' : 'Song library',
        tab == 2
            ? 'Your bookmarked charts, one tap away.'
            : 'Find a chart and track your best.',
      ),
      if (tab == 2) ...[
        box(
          Text(
            '♥  ${s.favorites.length} SAVED SONGS',
            style: TextStyle(
              color: pink,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          color: scheme.primaryContainer,
        ),
        gap(),
      ],
      label('SEARCH SONGS'),
      gap(8),
      TextField(
        controller: search,
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Title, artist or unit…',
          prefixIcon: Icon(Icons.search, size: 18),
        ),
      ),
      gap(12),
      Wrap(
        spacing: 8,
        children: [
          chip(
            tab == 2 ? 'All favorites' : 'All songs',
            !onlyFavorites && !missingFc,
            () => setState(() {
              onlyFavorites = false;
              missingFc = false;
            }),
          ),
          if (tab != 2)
            chip(
              'Favorites ♥',
              onlyFavorites,
              () => setState(() => onlyFavorites = !onlyFavorites),
            ),
          chip(
            'Not FC',
            missingFc,
            () => setState(() => missingFc = !missingFc),
          ),
          ActionChip(
            tooltip: 'Filter and sort',
            label: Icon(Icons.tune, size: 16),
            backgroundColor: scheme.surfaceContainerHighest,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            onPressed: () => go('filter'),
          ),
        ],
      ),
      gap(12),
      label('${filtered.length} songs · $catalogRegion catalog'),
      Text(
        'Sekai Viewer · snapshot $catalogAsOf',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      gap(14),
      if (filtered.isEmpty)
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No songs found'),
              gap(8),
              Text(
                'Try another filter or add favorites from the library.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ...filtered.take(visibleSongs).map((song) => songRow(song)),
      if (filtered.length > visibleSongs)
        action(
          'Show more songs (${filtered.length - visibleSongs} remaining)',
          () => setState(() => visibleSongs += 50),
          secondary: true,
        ),
      if (tab == 2) ...[
        gap(),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage your favorites'),
              gap(8),
              Text(
                'Tap ♥ on any song to add or remove it.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        gap(),
        action('Explore song library', () => navigate(1), secondary: true),
      ],
    ],
  );
  Widget filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'LIBRARY CONTROLS',
        'Filter & sort',
        'Narrow down the charts you need.',
      ),
      label('FILTER BY UNIT'),
      gap(10),
      Wrap(
        spacing: 8,
        children: ['All units', ...s.songs.expand((x) => x.unitNames).toSet()]
            .map((x) => chip(x, unit == x, () => setState(() => unit = x)))
            .toList(),
      ),
      gap(24),
      label('DIFFICULTY'),
      gap(10),
      Wrap(
        spacing: 8,
        children: [
          chip(
            'All',
            difficulty == null,
            () => setState(() => difficulty = null),
          ),
          ...List.generate(
            difficulties.length,
            (d) => chip(
              difficulties[d],
              difficulty == d,
              () => setState(() => difficulty = d),
            ),
          ),
        ],
      ),
      gap(24),
      label('PROGRESS STATUS'),
      gap(10),
      Wrap(
        spacing: 8,
        children: [
          chip(
            'All',
            filterStatus == null,
            () => setState(() => filterStatus = null),
          ),
          ...List.generate(5, (i) {
            final n = i - 1;
            return chip(
              statusName(n),
              filterStatus == n,
              () => setState(() => filterStatus = n),
            );
          }),
        ],
      ),
      gap(24),
      label('SORT BY'),
      gap(10),
      DropdownButtonFormField<String>(
        initialValue: sort,
        items: [
          'Title A–Z',
          'Title Z–A',
          'Level high–low',
        ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => sort = v!),
      ),
      gap(32),
      action('Apply filters', () => go('')),
      TextButton(
        onPressed: () => setState(() {
          difficulty = null;
          filterStatus = null;
          unit = 'All units';
          sort = 'Title A–Z';
          missingFc = false;
          onlyFavorites = false;
          query = '';
          search.clear();
        }),
        child: Text('Reset all filters'),
      ),
    ],
  );
  Widget detail() {
    final song = selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('SONG DETAILS', song.title, '${song.unit} · Project SEKAI'),
        box(
          Row(
            children: [
              Container(
                width: 89,
                height: 89,
                decoration: BoxDecoration(
                  color: Color(song.color),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: InkWell(
                  onTap: () =>
                      showJacket(context, song.assetBundle, song.title),
                  child: ArtworkImage(
                    url: jacketUrl(song.assetBundle),
                    label: '${song.title} jacket',
                    icon: Icons.music_note,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              run(() => s.favorite(song));
                            },
                      child: Text(
                        s.favorites.contains(song.id)
                            ? '♥ Favorite'
                            : '♡ Add favorite',
                        style: TextStyle(color: pink),
                      ),
                    ),
                    Text(
                      '${song.chartDifficulties.length} difficulty charts',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          color: scheme.primaryContainer,
        ),
        gap(28),
        Text(
          'Select difficulty',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        gap(14),
        ...song.chartDifficulties.map(
          (d) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Material(
              color: chart == d ? scheme.primaryContainer : panel,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                onTap: () => setState(() => chart = d),
                title: Text(
                  '${difficulties[d].toUpperCase()}  Lv. ${song.levels[d]}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  statusName(s.status(song.id, d)).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor(s.status(song.id, d)),
                  ),
                ),
              ),
            ),
          ),
        ),
        gap(24),
        action('Record or update selected chart', () => openRecord()),
        gap(10),
        action('View progress history', () => go('history'), secondary: true),
      ],
    );
  }

  Widget record() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'CHART RECORD',
        editing == null ? 'Edit progress' : 'Edit attempt',
        '${selected!.title} · ${difficulties[chart]} · Lv. ${selected!.levels[chart]}',
      ),
      label('CURRENT BEST SCORE'),
      gap(8),
      box(Text(number(s.best(selected!.id, chart))), padding: 14),
      gap(26),
      label('SELECT COMPLETION STATUS'),
      gap(14),
      ...List.generate(
        4,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Material(
            color: chosenStatus == i ? scheme.primaryContainer : panel,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              onTap: () => setState(() => chosenStatus = i),
              leading: Text(
                ['○', '✓', '★', '✦'][i],
                style: TextStyle(fontSize: 22, color: statusColor(i)),
              ),
              title: Text(statuses[i], style: TextStyle(fontSize: 14)),
              trailing: Icon(
                chosenStatus == i
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: chosenStatus == i ? statusColor(i) : muted,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      gap(20),
      label('NEW SCORE (OPTIONAL)'),
      gap(8),
      TextField(
        controller: score,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter score',
          helperText: 'Whole number, zero or greater',
          errorText: formError,
        ),
      ),
      gap(22),
      Text(
        'ⓘ  Saving a new attempt preserves score history.',
        style: TextStyle(fontSize: 11, color: muted),
      ),
      gap(24),
      action(
        busy
            ? 'Saving…'
            : editing == null
            ? 'Save new record'
            : 'Save changes',
        busy
            ? null
            : () {
                final raw = score.text.trim().replaceAll(',', '');
                final value = raw.isEmpty ? null : int.tryParse(raw);
                if (raw.isNotEmpty &&
                    (value == null || value < 0 || value > 2147483647)) {
                  setState(
                    () => formError = 'Enter a valid, non-negative score.',
                  );
                  return;
                }
                run(() async {
                  await s.save(
                    selected!,
                    chart,
                    chosenStatus,
                    value,
                    attemptId: editing?.id,
                  );
                  go('history');
                }, success: 'Progress saved');
              },
      ),
      gap(8),
      if (editing == null)
        TextButton(
          onPressed: busy ? null : deleteCurrent,
          child: Text('Delete current record', style: TextStyle(color: pink)),
        ),
      if (editing != null)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  final yes = await confirm(
                    'Delete this attempt?',
                    'This permanently removes this attempt from local history. Statistics will be recalculated.',
                    'Delete attempt',
                  );
                  if (yes && mounted) {
                    await run(() async {
                      await s.deleteAttempt(editing!.id);
                      go('history');
                    }, success: 'Attempt deleted.');
                  }
                },
          child: Text('Delete this attempt', style: TextStyle(color: pink)),
        ),
      TextButton(
        onPressed: busy ? null : () => go('history'),
        child: Text('View history & comparison'),
      ),
    ],
  );
  Future<void> deleteCurrent() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this progress record?'),
        content: Text(
          'This clears the selected current record. Past attempts remain in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete record', style: TextStyle(color: pink)),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      run(() async {
        await s.clear(selected!, chart);
        go('detail');
      }, success: 'Current record cleared. History preserved.');
    }
  }

  Widget history({bool all = false}) {
    final records = all ? s.attempts.toList() : s.history(selected!.id, chart);
    records.sort(
      (a, b) => newest ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'SCORE RECORDS',
          'Progress history',
          all
              ? 'All your recorded attempts'
              : '${selected!.title} · ${difficulties[chart]}',
        ),
        if (!all) ...[
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('PERSONAL BEST', color: purple),
                gap(10),
                Text(
                  number(s.best(selected!.id, chart)),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                gap(8),
                label('${records.length} recorded attempts', color: teal),
              ],
            ),
            color: scheme.primaryContainer,
          ),
          gap(22),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Attempt timeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => newest = !newest),
              child: Text(newest ? 'Newest first' : 'Oldest first'),
            ),
          ],
        ),
        gap(12),
        if (records.isEmpty)
          box(
            Text(
              'No history yet. Save your first attempt to start comparing.',
              style: TextStyle(color: muted),
            ),
          ),
        ...records.map(
          (a) => Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Material(
              color: panel,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                onTap: () {
                  selected = s.songById(a.songId);
                  chart = a.difficulty;
                  openRecord(attempt: a);
                },
                title: Text(
                  all
                      ? s.songById(a.songId).title
                      : a.date.toLocal().toString().substring(0, 16),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                subtitle: Text(
                  number(a.score),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                trailing: Text(
                  statuses[a.status].toUpperCase(),
                  style: TextStyle(fontSize: 10, color: statusColor(a.status)),
                ),
              ),
            ),
          ),
        ),
        gap(20),
        if (!all)
          action(
            'Compare latest vs previous',
            records.length < 2 ? null : () => go('compare'),
            secondary: true,
          ),
      ],
    );
  }

  Widget comparison() {
    final records = s.history(selected!.id, chart);
    if (records.length < 2) return history();
    final current = records[0], previous = records[1];
    final delta = current.score == null || previous.score == null
        ? null
        : current.score! - previous.score!;
    Widget metric(String title, Attempt a) => box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(title),
          gap(25),
          FittedBox(
            child: Text(
              number(a.score),
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
          ),
          gap(25),
          Text(
            statuses[a.status],
            style: TextStyle(color: statusColor(a.status), fontSize: 12),
          ),
        ],
      ),
      color: title == 'CURRENT' ? scheme.primaryContainer : panel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'PROGRESS INSIGHTS',
          'Record comparison',
          '${selected!.title} · ${difficulties[chart]}',
        ),
        Row(
          children: [
            Expanded(child: metric('PREVIOUS', previous)),
            SizedBox(width: 19),
            Expanded(child: metric('CURRENT', current)),
          ],
        ),
        gap(24),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('SCORE CHANGE'),
              gap(12),
              Text(
                delta == null
                    ? 'No score recorded'
                    : '${delta >= 0 ? '+' : ''}${number(delta)}',
                style: TextStyle(
                  fontSize: 31,
                  color: delta != null && delta < 0 ? pink : teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              gap(8),
              Text(
                'Latest attempt compared with the previous one',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        gap(28),
        Text(
          'Progress over time',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        gap(16),
        box(
          SizedBox(
            height: 144,
            child: CustomPaint(
              painter: ScorePlot(
                records.reversed
                    .where((a) => a.score != null)
                    .map((a) => a.score!)
                    .toList(),
                teal,
                muted,
              ),
            ),
          ),
        ),
        gap(30),
        action('View full history', () => go('history'), secondary: true),
      ],
    );
  }

  Widget stats() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'YOUR PERFORMANCE',
        'Statistics',
        'Overall, by difficulty and history.',
      ),
      totals(stats: true),
      Text(
        'By difficulty',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      gap(18),
      ...List.generate(difficulties.length, (d) {
        final total = s.chartCount(d);
        final ratio = total == 0 ? 0.0 : s.count(1, d) / total;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(difficulties[d], style: TextStyle(fontSize: 12)),
                label('${(ratio * 100).round()}%'),
              ],
            ),
            gap(8),
            LinearProgressIndicator(
              value: ratio,
              color: d == 4 ? pink : purple,
              backgroundColor: scheme.surfaceContainerHighest,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
            ),
            gap(22),
          ],
        );
      }),
      action(
        'Compare historical performance',
        () => go('allHistory'),
        secondary: true,
      ),
    ],
  );
  String settingsTheme = 'dark', settingsAppearance = 'system';
  Future<bool> confirm(String title, String message, String button) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(button),
            ),
          ],
        ),
      ) ??
      false;
  bool importingProgress = false;
  Future<void> importProgressAction() async {
    if (busy || importingProgress) return;
    setState(() => importingProgress = true);
    String counted(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    try {
      final contents = await pickProgressFileContents();
      if (contents == null || !mounted) return;
      final file = await s.readProgressFile(contents);
      if (!mounted) return;
      final merge = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import progress'),
          content: Text(
            'This file holds ${counted(file.attemptCount, 'attempt')}, '
            '${counted(file.favoriteCount, 'favorite')} and '
            '${counted(file.cardCount, 'card')}.\n\n'
            'Merge keeps the progress already on this device. Replace deletes '
            'local attempts, favorites and cards first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (merge == null || !mounted) return;
      await file.apply(merge: merge);
      if (mounted) {
        toast(
          'Imported ${counted(file.attemptCount, 'attempt')}, '
          '${counted(file.favoriteCount, 'favorite')} and '
          '${counted(file.cardCount, 'card')} '
          '(${merge ? 'merged' : 'replaced'}).',
        );
      }
    } on FormatException catch (e) {
      if (mounted) toast(e.message);
    } on StateError catch (e) {
      if (mounted) toast(e.message);
    } catch (_) {
      if (mounted) toast('Could not import that progress file.');
    } finally {
      if (mounted) setState(() => importingProgress = false);
    }
  }

  Future<void> backupAction(bool restore) async {
    if (s.accounts.username == null) {
      s.accounts.reopen();
      go('login');
      return;
    }
    DateTime? savedAt;
    if (restore) {
      try {
        savedAt = await s.cloudBackupAt();
      } catch (_) {
        savedAt = null;
      }
      if (!mounted) return;
    }
    final when = savedAt == null
        ? ''
        : ' from ${savedAt.toLocal().toString().substring(0, 16)}';
    final yes = await confirm(
      restore ? 'Restore cloud backup?' : 'Save cloud backup?',
      restore
          ? 'This replaces this device’s progress, favorites, card collection and settings with your cloud backup$when. A recovery copy is kept on this device.'
          : 'This replaces the backup for your signed-in account with this device’s current progress, favorites, card collection and settings.',
      restore ? 'Restore backup' : 'Save backup',
    );
    if (!yes || !mounted) return;
    await run(
      restore ? s.restoreBackup : s.saveBackup,
      success: restore
          ? 'Backup restored to this device.'
          : 'Cloud backup saved.',
    );
    if (mounted) {
      displayName.text = s.name;
      setState(() {
        chart = s.defaultDifficulty;
        settingsTheme = s.theme;
        settingsAppearance = s.appearance;
      });
    }
  }

  Widget profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'YOUR ACCOUNT',
        'Profile',
        s.signedIn
            ? 'Your personal identity in SynthDex.'
            : 'Sign in to set up your profile.',
      ),
      Center(
        child: CircleAvatar(
          radius: 42,
          child: Icon(Icons.person_outline, size: 42),
        ),
      ),
      gap(24),
      if (!s.signedIn) ...[
        box(
          Text(
            'Your tracking stays on this device. Sign in or create an account to view and edit your profile.',
            style: TextStyle(color: muted),
          ),
        ),
        gap(20),
        action('Sign in / Create account', () => go('login')),
      ] else ...[
        if (s.accounts.username != null)
          Text(
            '@${s.accounts.username}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        if (s.accounts.username == null)
          action('Finish account setup', () => go('login'), secondary: true),
        gap(8),
        Text(
          s.client?.auth.currentUser?.email ?? 'Signed in',
          style: TextStyle(color: muted),
        ),
        gap(24),
        label('YOUR PROGRESS'),
        gap(12),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.completedSongCount} / ${s.songs.length}',
                key: Key('profile-completed-songs'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: teal,
                ),
              ),
              Text(
                'Completed songs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              gap(6),
              Text(
                'A clear or better on at least one chart. Each song counts once.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              gap(20),
              Text(
                '${s.collectedCardCount} / ${s.cardCatalog.length}',
                key: Key('profile-collected-cards'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: pink,
                ),
              ),
              Text(
                'Collected cards',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              gap(6),
              Text(
                'Cards marked Owned. Wishlist-only cards are not counted.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              gap(12),
              Text(
                'Based on the progress and collection saved on this device.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        gap(24),
        TextField(
          key: Key('profile-display-name'),
          controller: displayName,
          maxLength: 80,
          decoration: InputDecoration(labelText: 'Display name'),
        ),
        gap(16),
        action(
          busy ? 'Saving…' : 'Save profile',
          busy
              ? null
              : () => run(
                  () => s.updateDisplayName(displayName.text),
                  success: 'Profile saved on this device.',
                ),
        ),
        gap(16),
        action(
          'Sign out',
          busy
              ? null
              : () => run(() async {
                  await s.client!.auth.signOut();
                  displayName.clear();
                }, success: 'Signed out. Local tracking data is unchanged.'),
          secondary: true,
        ),
      ],
    ],
  );

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'YOUR PREFERENCES',
        'Settings',
        'Customize this device. Cloud backup is optional.',
      ),
      DropdownButtonFormField<int>(
        key: ValueKey('difficulty-${s.defaultDifficulty}'),
        initialValue: chart,
        decoration: InputDecoration(labelText: 'Default chart difficulty'),
        items: List.generate(
          difficulties.length,
          (d) => DropdownMenuItem(value: d, child: Text(difficulties[d])),
        ),
        onChanged: (d) => setState(() => chart = d!),
      ),
      gap(),
      DropdownButtonFormField<String>(
        key: ValueKey('theme-${s.theme}'),
        initialValue: settingsTheme,
        decoration: InputDecoration(labelText: 'App theme'),
        items: appPalettes
            .map(
              (palette) => DropdownMenuItem(
                value: palette.id,
                child: Row(
                  children: [
                    for (final color in palette.colors)
                      Container(width: 12, height: 20, color: color),
                    SizedBox(width: 12),
                    Text(palette.name),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => settingsTheme = v!),
      ),
      gap(),
      DropdownButtonFormField<String>(
        key: ValueKey('appearance-${s.appearance}'),
        initialValue: settingsAppearance,
        decoration: InputDecoration(labelText: 'Appearance'),
        items: [
          DropdownMenuItem(value: 'system', child: Text('System (default)')),
          DropdownMenuItem(value: 'light', child: Text('Light')),
          DropdownMenuItem(value: 'dark', child: Text('Dark')),
        ],
        onChanged: (value) => setState(() => settingsAppearance = value!),
      ),
      gap(8),
      Text(
        'System follows your device’s light or dark appearance.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      gap(20),
      action(
        busy ? 'Saving…' : 'Save settings',
        busy
            ? null
            : () => run(
                () => s.updateAppSettings(
                  chart,
                  settingsTheme,
                  appearance: settingsAppearance,
                ),
                success: 'Settings saved on this device.',
              ),
      ),
      gap(30),
      Text(
        'Data backup',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      gap(10),
      Text(
        'Progress is saved on this device automatically. Sign in only to save or restore a cloud backup. Signing in never replaces local data.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      gap(16),
      if (!s.signedIn) ...[
        action(
          'Sign in for optional backup',
          () => go('login'),
          secondary: true,
        ),
      ] else ...[
        if (s.accounts.username == null)
          action('Finish account setup', () => go('login'), secondary: true),
        gap(12),
        Text(
          s.backupAt == null
              ? 'No cloud backup yet.'
              : 'Last backup: ${s.backupAt!.toLocal().toString().substring(0, 16)} · '
                    '${s.pendingChanges} ${s.pendingChanges == 1 ? 'change' : 'changes'} since.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        gap(12),
        action('Save cloud backup', busy ? null : () => backupAction(false)),
        gap(10),
        action(
          'Load cloud backup',
          busy ? null : () => backupAction(true),
          secondary: true,
        ),
      ],
      gap(20),
      action(
        'Export progress as JSON',
        busy
            ? null
            : () => run(() async {
                try {
                  final name =
                      'synthdex-progress-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}.json';
                  final saved = await saveTextFile(
                    name,
                    await s.progressExportJson(),
                  );
                  if (mounted) toast('Progress exported to $saved');
                } on StateError catch (e) {
                  if (mounted) toast(e.message);
                } catch (_) {
                  if (mounted) {
                    toast('Could not save the export file. Try again.');
                  }
                }
              }),
        secondary: true,
      ),
      gap(8),
      Text(
        'Saves a versioned JSON file with every attempt, favorite and card, plus the catalog snapshot it was recorded against. No account needed.',
        style: TextStyle(color: muted, fontSize: 12),
      ),

      gap(12),
      action(
        'Import progress from JSON',
        busy ? null : importProgressAction,
        secondary: true,
      ),
      gap(8),
      Text(
        'Restores one of your SynthDex exports on this device. You choose whether to replace or merge the attempts, favorites and cards already here. No account needed.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      gap(28),

      TextButton(
        onPressed: busy
            ? null
            : () async {
                final yes = await confirm(
                  'Reset personal data?',
                  'This deletes progress, favorites, card collection and preferences from this device. The song catalog and your cloud backup are kept.',
                  'Reset local data',
                );
                if (yes && mounted) {
                  await run(() async {
                    await s.reset();
                    displayName.clear();
                    setState(() {
                      chart = 3;
                      settingsTheme = 'dark';
                      settingsAppearance = 'system';
                    });
                  }, success: 'Local personal data reset.');
                }
              },
        child: Text('Reset personal data', style: TextStyle(color: pink)),
      ),
      gap(16),
      Text(
        'Artwork via Sekai Viewer. Game artwork © SEGA, Colorful Palette and Crypton Future Media. SynthDex is an unofficial fan tracker.',
        style: TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
  Widget login() =>
      AccountPanel(accounts: s.accounts, onDone: () => go('account'));
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
    _ =>
      tab == 0
          ? home()
          : tab == 4
          ? CharacterCollection(store: s)
          : tab == 3
          ? stats()
          : library(),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              if (page.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: page == 'account'
                            ? SizedBox(height: 48)
                            : TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => go(
                                        page == 'record' || page == 'history'
                                            ? 'detail'
                                            : page == 'compare'
                                            ? 'history'
                                            : page == 'settings' ||
                                                  page == 'login'
                                            ? 'account'
                                            : '',
                                      ),
                                icon: Icon(Icons.arrow_back, size: 16),
                                label: Text('Back'),
                              ),
                      ),
                    ),
                    if (page == 'account')
                      Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: IconButton(
                          tooltip: 'Settings',
                          onPressed: busy ? null : () => go('settings'),
                          icon: Icon(Icons.settings_outlined),
                        ),
                      ),
                  ],
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => s.refresh(force: true),
                  child: ListView(
                    key: ValueKey('$tab/$page'),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      page.isEmpty ? 32 : 8,
                      22,
                      24,
                    ),
                    children: [
                      if (s.loading) LinearProgressIndicator(),
                      if (s.error != null) ...[
                        box(
                          Column(
                            children: [
                              Text(s.error!),
                              TextButton(
                                onPressed: () => s.refresh(force: true),
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                        gap(),
                      ],
                      if (formError != null && page != 'record') ...[
                        box(
                          Text(formError!, style: TextStyle(color: pink)),
                          color: scheme.primaryContainer,
                        ),
                        gap(),
                      ],
                      content(),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: List.generate(6, (i) {
                    final selected = tab == i;
                    final labels = [
                      'Home',
                      'Songs',
                      'Favorites',
                      'Stats',
                      'Roster',
                      'Profile',
                    ];
                    final icons = [
                      Icons.home_outlined,
                      Icons.music_note_outlined,
                      Icons.favorite_border,
                      Icons.bar_chart_outlined,
                      Icons.people_outline,
                      Icons.person_outline,
                    ];
                    final activeIcons = [
                      Icons.home_rounded,
                      Icons.music_note_rounded,
                      Icons.favorite_rounded,
                      Icons.bar_chart_rounded,
                      Icons.people_rounded,
                      Icons.person_rounded,
                    ];
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        button: true,
                        child: InkWell(
                          key: ValueKey('nav-${labels[i].toLowerCase()}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => navigate(i),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 180),
                                  width: 44,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? scheme.primaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    selected ? activeIcons[i] : icons[i],
                                    size: 22,
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : muted,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected ? scheme.onSurface : muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ScorePlot extends CustomPainter {
  ScorePlot(this.scores, this.teal, this.muted);
  final Color teal, muted;
  final List<int> scores;
  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final max = scores.reduce((a, b) => a > b ? a : b),
        min = scores.reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < scores.length; i++) {
      final x =
          12 +
          (size.width - 24) *
              (scores.length == 1 ? 0.5 : i / (scores.length - 1));
      final y =
          15 +
          (size.height - 45) *
              (max == min ? 0.5 : 1 - (scores[i] - min) / (max - min));
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = teal);
      if (scores.length <= 6) {
        final text = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(color: muted, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(x - 3, size.height - 14));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScorePlot oldDelegate) => true;
}
