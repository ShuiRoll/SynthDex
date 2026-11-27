part of '../app.dart';

extension _LibraryScreens on _HubState {
  Widget home() {
    final total = s.chartCount();
    final cleared = s.count(1);
    final pct = total == 0 ? 0.0 : (cleared / total) * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: tokens.rainbow),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.isDark ? const Color(0xFF131E3E) : Colors.white,
                  borderRadius: BorderRadius.circular(12.5),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SynthDex',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'YOUR RHYTHM COMPANION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: tokens.isDark ? tokens.aqua : scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open settings',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => go('settings'),
              icon: Icon(Icons.settings_outlined, color: muted),
            ),
          ],
        ),
        gap(18),
        PjskPrismCard(
          gradient: tokens.heroGradient,
          showArtOverlay: true,
          radius: 22,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ONE CHART AT A TIME',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                ),
              ),
              gap(8),
              Text(
                'Next to play',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.9,
                  color: scheme.onSurface,
                ),
              ),
              gap(6),
              Text(
                'Pick a chart, make a little progress.',
                style: TextStyle(fontSize: 13, height: 1.45, color: muted),
              ),
              gap(14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  PjskDifficultyBadge(
                    difficulty: s.defaultDifficulty,
                    label:
                        '${difficulties[s.defaultDifficulty].toUpperCase()} CHARTS',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.aqua.withValues(
                        alpha: tokens.isDark ? 0.16 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: tokens.aqua.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}% CLEARED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: tokens.isDark ? tokens.aqua : scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        gap(18),
        label('QUICK ACTIONS'),
        gap(10),
        Row(
          children: [
            Expanded(
              child: PjskQuickActionTile(
                label: 'Browse library',
                highlighted: true,
                onTap: () => navigate(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PjskQuickActionTile(
                label: 'Favorites ♡',
                onTap: () => navigate(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PjskQuickActionTile(
                label: 'History ↗',
                onTap: () => go('allHistory'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PjskQuickActionTile(
                label: 'Card collection',
                onTap: () => navigate(4),
              ),
            ),
          ],
        ),
        gap(20),
        Text(
          'Work on ${difficulties[s.defaultDifficulty]}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        gap(4),
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
        ...List.generate(
          s.nextSongs.length,
          (i) => songRow(
            s.nextSongs[i],
            chartDifficulty: s.defaultDifficulty,
            staggerIndex: i,
          ),
        ),
        gap(18),
        const Text(
          'Latest activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
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
            overrideStatus: attempt.status,
            subtitle:
                '${attempt.active ? 'Recorded' : 'Archived'} · ${attempt.date.toLocal().toString().substring(0, 10)}',
          ),
        ),
      ],
    );
  }

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
    final sortDiff = difficulty ?? s.defaultDifficulty;
    list.sort((a, b) {
      if (sort == 'Title Z–A') return b.title.compareTo(a.title);
      if (sort == 'Level high–low') {
        final cmp = b.levels[sortDiff].compareTo(a.levels[sortDiff]);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      }
      if (sort == 'Level low–high') {
        final la = a.levels[sortDiff] == 0 ? 999 : a.levels[sortDiff];
        final lb = b.levels[sortDiff] == 0 ? 999 : b.levels[sortDiff];
        final cmp = la.compareTo(lb);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      }
      return a.title.compareTo(b.title);
    });
    return list;
  }

  Widget _activeFilterPill(String text, VoidCallback onClear) => InputChip(
    label: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: tokens.isDark ? tokens.aqua : scheme.primary,
      ),
    ),
    deleteIcon: Icon(
      Icons.close_rounded,
      size: 14,
      color: tokens.isDark ? tokens.aqua : scheme.primary,
    ),
    onDeleted: onClear,
    backgroundColor: tokens.aqua.withValues(alpha: tokens.isDark ? 0.16 : 0.12),
    side: BorderSide(color: tokens.aqua.withValues(alpha: 0.6)),
    shape: const StadiumBorder(),
    visualDensity: VisualDensity.compact,
  );

  Widget libraryScrollView() {
    final items = filtered;
    final visibleCount = items.length < visibleSongs
        ? items.length
        : visibleSongs;
    final hasAdvanced =
        unit != 'All units' ||
        difficulty != null ||
        filterStatus != null ||
        sort != 'Title A–Z';

    return RefreshIndicator(
      onRefresh: () => s.refresh(force: true),
      child: CustomScrollView(
        key: PageStorageKey('library-$tab'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  heading(
                    tab == 2 ? 'YOUR COLLECTION' : 'PRELOADED SONG CATALOG',
                    tab == 2 ? 'Favorite songs' : 'Song library',
                    tab == 2
                        ? 'Your bookmarked charts, one tap away.'
                        : 'Find a chart and track your best.',
                  ),
                  if (tab == 2) ...[
                    PjskPrismCard(
                      gradient: tokens.heroGradient,
                      showArtOverlay: true,
                      artAccent: tokens.pink,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: tokens.pink.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tokens.pink.withValues(alpha: 0.65),
                              ),
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: tokens.pink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.favorites.length} SAVED SONGS',
                                  style: TextStyle(
                                    color: tokens.pink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Prioritized at the top of Next to play',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    gap(16),
                  ],
                  TextField(
                    controller: search,
                    onChanged: (v) => _update(() {
                      query = v;
                      visibleSongs = 50;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Title, artist or unit…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => _update(() {
                                search.clear();
                                query = '';
                                visibleSongs = 50;
                              }),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  ),
                  gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      chip(
                        tab == 2 ? 'All favorites' : 'All songs',
                        !onlyFavorites && !missingFc,
                        () => _update(() {
                          onlyFavorites = false;
                          missingFc = false;
                          visibleSongs = 50;
                        }),
                      ),
                      if (tab != 2)
                        chip(
                          'Favorites ♥',
                          onlyFavorites,
                          () => _update(() {
                            onlyFavorites = !onlyFavorites;
                            visibleSongs = 50;
                          }),
                          accent: tokens.pink,
                        ),
                      chip(
                        'Not FC',
                        missingFc,
                        () => _update(() {
                          missingFc = !missingFc;
                          visibleSongs = 50;
                        }),
                        accent: tokens.gold,
                      ),
                      ActionChip(
                        tooltip: 'Filter and sort',
                        label: const Icon(Icons.tune_rounded, size: 16),
                        backgroundColor: hasAdvanced
                            ? tokens.aqua.withValues(
                                alpha: tokens.isDark ? 0.24 : 0.16,
                              )
                            : (tokens.isDark
                                  ? scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.7,
                                    )
                                  : scheme.surfaceContainer),
                        side: BorderSide(
                          color: hasAdvanced
                              ? tokens.aqua
                              : scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                        shape: const StadiumBorder(),
                        padding: EdgeInsets.zero,
                        onPressed: () => go('filter'),
                      ),
                    ],
                  ),
                  if (hasAdvanced) ...[
                    gap(8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (unit != 'All units')
                          _activeFilterPill(
                            unit,
                            () => _update(() {
                              unit = 'All units';
                              visibleSongs = 50;
                            }),
                          ),
                        if (difficulty != null)
                          _activeFilterPill(
                            difficulties[difficulty!],
                            () => _update(() {
                              difficulty = null;
                              visibleSongs = 50;
                            }),
                          ),
                        if (filterStatus != null)
                          _activeFilterPill(
                            statusName(filterStatus!),
                            () => _update(() {
                              filterStatus = null;
                              visibleSongs = 50;
                            }),
                          ),
                        if (sort != 'Title A–Z')
                          _activeFilterPill(
                            sort,
                            () => _update(() {
                              sort = 'Title A–Z';
                              visibleSongs = 50;
                            }),
                          ),
                      ],
                    ),
                  ],
                  gap(12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: label(
                          '${items.length} songs · $catalogRegion catalog',
                        ),
                      ),
                      Text(
                        catalogAsOf,
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                  gap(12),
                  if (items.isEmpty)
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No songs found',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          gap(6),
                          Text(
                            'Try another filter or add favorites from the library.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: visibleCount,
              itemBuilder: (context, index) =>
                  songRow(items[index], staggerIndex: index),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (items.length > visibleSongs)
                    action(
                      'Show more songs (${items.length - visibleSongs} remaining)',
                      () => _update(() => visibleSongs += 50),
                      secondary: true,
                    ),
                  if (tab == 2) ...[
                    gap(),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage your favorites',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          gap(6),
                          Text(
                            'Tap ♥ on any song to add or remove it.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    gap(14),
                    action(
                      'Explore song library',
                      () => navigate(1),
                      secondary: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        runSpacing: 6,
        children: ['All units', ...s.songs.expand((x) => x.unitNames).toSet()]
            .map(
              (x) => chip(
                x,
                unit == x,
                () => _update(() => unit = x),
                accent: x == 'All units' ? null : PjskTokens.unitColor(x),
              ),
            )
            .toList(),
      ),
      gap(22),
      label('DIFFICULTY'),
      gap(10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          chip(
            'All',
            difficulty == null,
            () => _update(() => difficulty = null),
          ),
          ...List.generate(
            difficulties.length,
            (d) => chip(
              difficulties[d],
              difficulty == d,
              () => _update(() => difficulty = d),
              accent: tokens.difficultyColor(d),
            ),
          ),
        ],
      ),
      gap(22),
      label('PROGRESS STATUS'),
      gap(10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          chip(
            'All',
            filterStatus == null,
            () => _update(() => filterStatus = null),
          ),
          ...List.generate(5, (i) {
            final n = i - 1;
            return chip(
              statusName(n),
              filterStatus == n,
              () => _update(() => filterStatus = n),
              accent: n >= 1 ? tokens.lampColor(n, muted) : null,
            );
          }),
        ],
      ),
      gap(22),
      label('SORT BY'),
      gap(10),
      DropdownButtonFormField<String>(
        initialValue: sort,
        items: [
          'Title A–Z',
          'Title Z–A',
          'Level high–low',
          'Level low–high',
        ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => _update(() {
          sort = v!;
          visibleSongs = 50;
        }),
      ),
      gap(28),
      action('Apply filters', () {
        visibleSongs = 50;
        go('');
      }),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => _update(() {
            difficulty = null;
            filterStatus = null;
            unit = 'All units';
            sort = 'Title A–Z';
            missingFc = false;
            onlyFavorites = false;
            query = '';
            visibleSongs = 50;
            search.clear();
          }),
          child: const Text('Reset all filters'),
        ),
      ),
    ],
  );

}
