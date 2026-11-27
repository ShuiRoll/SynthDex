part of '../app.dart';

extension _ProgressScreens on _HubState {
  Widget detail() {
    final song = selected!;
    final fav = s.favorites.contains(song.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('SONG DETAILS', song.title, '${song.unit} · Project SEKAI'),
        PjskPrismCard(
          gradient: tokens.heroGradient,
          showArtOverlay: true,
          artAccent: PjskTokens.unitColor(song.unit),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Color(song.color),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () =>
                            showJacket(context, song.assetBundle, song.title),
                        child: ArtworkImage(
                          url: jacketUrl(song.assetBundle),
                          label: '${song.title} jacket',
                          icon: Icons.music_note_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${song.chartDifficulties.length} difficulty charts',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: tokens.pink.withValues(
                              alpha: 0.14,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: busy
                              ? null
                              : () {
                                  run(() => s.favorite(song));
                                },
                          child: Text(
                            fav ? '♥ Favorite' : '♡ Add favorite',
                            style: TextStyle(
                              color: tokens.pink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 6-Diamond Clear Lamp Strip inside Song Detail Hero
              Row(
                children: [
                  Text(
                    'CLEAR LAMPS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PjskSixLampStrip(
                    statusesByDifficulty: _songLamps(song),
                    size: 8.5,
                  ),
                ],
              ),
            ],
          ),
        ),
        gap(22),
        const Text(
          'Select difficulty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        gap(12),
        ...List.generate(song.chartDifficulties.length, (idx) {
          final d = song.chartDifficulties[idx];
          final isSelected = chart == d;
          final dColor = tokens.difficultyColor(d);
          final st = s.status(song.id, d);
          final bestScore = s.best(song.id, d);
          final tile = Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _update(() => chart = d),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4.5, color: dColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${difficulties[d].toUpperCase()}  Lv. ${song.levels[d]}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? (tokens.isDark
                                                ? Colors.white
                                                : scheme.onSurface)
                                          : dColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    bestScore == null
                                        ? 'No score recorded'
                                        : 'Best: ${number(bestScore)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PjskStatusLamp(
                              status: st,
                              label: statusName(st).toUpperCase(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          return PjskStaggerItem(
            index: idx,
            child: PjskPressScale(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(isSelected ? 1.5 : 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: tokens.rainbow
                                .map((c) => c.withValues(alpha: 0.78))
                                .toList(),
                          )
                        : null,
                    color: isSelected
                        ? null
                        : scheme.outlineVariant.withValues(alpha: 0.55),
                    boxShadow: isSelected && tokens.isDark
                        ? [
                            BoxShadow(
                              color: tokens.aqua.withValues(alpha: 0.16),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 13.5 : 14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      color: isSelected
                          ? (tokens.isDark
                                ? const Color(0xFF192852)
                                : const Color(0xFFEAF7F6))
                          : panel,
                      child: tile,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        gap(20),
        action(
          'Record or update selected chart',
          () => openRecord(),
          icon: Icons.edit_note_rounded,
        ),
        gap(10),
        action(
          'View progress history',
          () => go('history'),
          secondary: true,
          icon: Icons.history_rounded,
        ),
      ],
    );
  }

  Widget record() {
    final currentStatus = s.status(selected!.id, chart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'CHART RECORD',
          editing == null ? 'Edit progress' : 'Edit attempt',
          '${selected!.title} · ${difficulties[chart]} · Lv. ${selected!.levels[chart]}',
        ),
        PjskPrismCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: panel,
          rainbowOpacity: 0.48,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label('CURRENT BEST SCORE'),
                    const SizedBox(height: 4),
                    Text(
                      number(s.best(selected!.id, chart)),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              PjskStatusLamp(
                status: currentStatus,
                label: statusName(currentStatus).toUpperCase(),
              ),
            ],
          ),
        ),
        gap(22),
        label('SELECT COMPLETION STATUS'),
        gap(12),
        ...List.generate(4, (i) {
          final isSelected = chosenStatus == i;
          final sColor = statusColor(i);
          final tile = Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () => _update(() => chosenStatus = i),
              leading: i == 3
                  ? Icon(Icons.auto_awesome, size: 22, color: sColor)
                  : Text(
                      const ['○', '✓', '★'][i],
                      style: TextStyle(fontSize: 22, color: sColor),
                    ),
              title: Text(
                statuses[i],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? sColor : muted,
                size: 20,
              ),
            ),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(isSelected ? 1.5 : 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: tokens.rainbow
                            .map((c) => c.withValues(alpha: 0.78))
                            .toList(),
                      )
                    : null,
                color: isSelected
                    ? null
                    : scheme.outlineVariant.withValues(alpha: 0.55),
                boxShadow: isSelected && tokens.isDark
                    ? [
                        BoxShadow(
                          color: tokens.aqua.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isSelected ? 13.5 : 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  color: isSelected
                      ? (tokens.isDark
                            ? const Color(0xFF192852)
                            : const Color(0xFFEAF7F6))
                      : panel,
                  child: tile,
                ),
              ),
            ),
          );
        }),
        gap(18),
        label('NEW SCORE (OPTIONAL)'),
        gap(8),
        TextField(
          controller: score,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (formError != null) _update(() => formError = null);
          },
          decoration: InputDecoration(
            hintText: 'Enter score',
            helperText: 'Whole number, zero or greater',
            errorText: formError,
          ),
        ),
        gap(18),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Saving a new attempt preserves score history.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
        gap(20),
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
                    _update(
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
        gap(10),
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              if (editing == null)
                TextButton.icon(
                  onPressed: busy ? null : deleteCurrent,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: tokens.pink,
                  ),
                  label: Text(
                    'Delete current record',
                    style: TextStyle(
                      color: tokens.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (editing != null)
                TextButton.icon(
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
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: tokens.pink,
                  ),
                  label: Text(
                    'Delete this attempt',
                    style: TextStyle(
                      color: tokens.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: busy ? null : () => go('history'),
                child: const Text('View history & comparison'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> deleteCurrent() async {
    final yes = await showPjskDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this progress record?'),
        content: const Text(
          'This clears the selected current record. Past attempts remain in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete record', style: TextStyle(color: tokens.pink)),
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
    // Compute chronological per-chart score deltas matching Chapter 2 Figure 7
    final chrono = records.toList()..sort((a, b) => a.date.compareTo(b.date));
    final prevScoreByChart = <String, int>{};
    final deltaById = <String, (String, Color)>{};
    for (final a in chrono) {
      if (a.score == null) continue;
      final key = '${a.songId}:${a.difficulty}';
      final prev = prevScoreByChart[key];
      if (prev == null) {
        deltaById[a.id] = ('FIRST', muted);
      } else {
        final diff = a.score! - prev;
        final labelStr = '${diff >= 0 ? '+' : ''}${number(diff)}';
        deltaById[a.id] = (
          labelStr,
          diff < 0
              ? tokens.pink
              : (tokens.isDark ? tokens.aqua : scheme.primary),
        );
      }
      prevScoreByChart[key] = a.score!;
    }
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
          PjskPrismCard(
            gradient: tokens.heroGradient,
            showArtOverlay: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label(
                  'PERSONAL BEST',
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                ),
                gap(8),
                Text(
                  number(s.best(selected!.id, chart)),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    label(
                      '${records.length} recorded attempts',
                      color: tokens.isDark ? tokens.aqua : scheme.primary,
                    ),
                    PjskStatusLamp(
                      status: s.status(selected!.id, chart),
                      label: statusName(
                        s.status(selected!.id, chart),
                      ).toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap(20),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Attempt timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _update(() => newest = !newest),
              child: Text(
                newest ? 'Newest first' : 'Oldest first',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        gap(10),
        if (records.isEmpty)
          box(
            Text(
              'No history yet. Save your first attempt to start comparing.',
              style: TextStyle(color: muted),
            ),
          ),
        ...List.generate(records.length, (idx) {
          final a = records[idx];
          final delta = deltaById[a.id];
          return PjskStaggerItem(
            index: idx,
            child: PjskPressScale(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: () {
                        selected = s.songById(a.songId);
                        chart = a.difficulty;
                        openRecord(attempt: a);
                      },
                      title: Text(
                        all
                            ? '${s.songById(a.songId).title} · ${difficulties[a.difficulty]} · ${a.date.toLocal().toString().substring(0, 10)}${a.active ? '' : ' · Archived'}'
                            : '${a.date.toLocal().toString().substring(0, 16)}${a.active ? '' : ' · Archived'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      subtitle: Text(
                        number(a.score),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurface,
                        ),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PjskStatusLamp(
                            status: a.status,
                            label: statuses[a.status].toUpperCase(),
                          ),
                          if (delta != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              delta.$1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: delta.$2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        gap(18),
        if (!all)
          action(
            'Compare latest vs previous',
            records.length < 2 ? null : () => go('compare'),
            secondary: true,
            icon: Icons.compare_arrows_rounded,
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
    Widget metric(String title, Attempt a, {bool highlight = false}) {
      final inner = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(
            title,
            color: highlight
                ? (tokens.isDark ? tokens.aqua : scheme.primary)
                : muted,
          ),
          gap(14),
          FittedBox(
            child: Text(
              number(a.score),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          gap(14),
          PjskStatusLamp(
            status: a.status,
            label: statuses[a.status].toUpperCase(),
          ),
        ],
      );
      return highlight
          ? PjskPrismCard(
              gradient: tokens.heroGradient,
              padding: const EdgeInsets.all(16),
              child: inner,
            )
          : box(inner, padding: 16);
    }

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
            const SizedBox(width: 12),
            Expanded(child: metric('CURRENT', current, highlight: true)),
          ],
        ),
        gap(16),
        PjskPrismCard(
          backgroundColor: panel,
          rainbowOpacity: 0.55,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('SCORE CHANGE'),
              gap(8),
              Text(
                delta == null
                    ? 'No score recorded'
                    : '${delta >= 0 ? '+' : ''}${number(delta)}',
                style: TextStyle(
                  fontSize: 31,
                  color: delta != null && delta < 0
                      ? tokens.pink
                      : (tokens.isDark ? tokens.aqua : scheme.primary),
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
              gap(6),
              Text(
                'Latest attempt compared with the previous one',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        gap(22),
        const Text(
          'Progress over time',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        gap(12),
        Builder(
          builder: (_) {
            final scored = records.reversed
                .where((a) => a.score != null)
                .toList();
            if (scored.isEmpty) {
              return box(
                Text(
                  'No numeric scores recorded yet. Add scores to your attempts to visualize score trends over time.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.45),
                ),
              );
            }
            final scores = scored.map((a) => a.score!).toList();
            final firstDate = scored.first.date.toLocal().toString().substring(
              0,
              10,
            );
            final lastDate = scored.last.date.toLocal().toString().substring(
              0,
              10,
            );
            return box(
              Semantics(
                label: 'Score trend across ${scores.length} scored attempts',
                child: SizedBox(
                  height: 156,
                  child: CustomPaint(
                    painter: ScorePlot(
                      scores,
                      tokens.aqua,
                      tokens.pink,
                      muted,
                      firstLabel: firstDate,
                      lastLabel: scores.length > 1 ? lastDate : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        gap(24),
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
      const Text(
        'By difficulty',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
      ),
      gap(14),
      ...List.generate(difficulties.length, (d) {
        final total = s.chartCount(d);
        final cleared = s.count(1, d);
        final ratio = total == 0 ? 0.0 : cleared / total;
        return PjskStaggerItem(
          index: d,
          child: PjskDifficultyBar(
            difficulty: d,
            label: difficulties[d],
            ratio: ratio,
            cleared: cleared,
            total: total,
            fullCombos: s.count(2, d),
            allPerfects: s.count(3, d),
          ),
        );
      }),
      gap(6),
      action(
        'Compare historical performance',
        () => go('allHistory'),
        secondary: true,
      ),
    ],
  );

}
