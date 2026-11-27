part of '../app.dart';

extension _AccountScreens on _HubState {
  Future<bool> confirm(String title, String message, String button) async =>
      await showPjskDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(button),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> importProgressAction() async {
    if (busy || importingProgress) return;
    _update(() => importingProgress = true);
    String counted(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    try {
      final contents = await pickProgressFileContents();
      if (contents == null || !mounted) return;
      final file = await s.readProgressFile(contents);
      if (!mounted) return;
      final localAttempts = s.attempts.length;
      final localFavorites = s.favorites.length;
      final localCards = s.cardCollection.length;
      final merge = await showPjskDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import progress'),
          content: Text(
            'This file holds ${counted(file.attemptCount, 'attempt')}, '
            '${counted(file.favoriteCount, 'favorite')} and '
            '${counted(file.cardCount, 'card')}.\n\n'
            'Replace deletes everything already on this device (currently '
            '${counted(localAttempts, 'attempt')}, '
            '${counted(localFavorites, 'favorite')} and '
            '${counted(localCards, 'card')}) and keeps only the file. '
            'Merge keeps both and adds anything missing.',
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
      if (mounted) _update(() => importingProgress = false);
    }
  }

  Future<void> undoReplacementAction() async {
    final kind = s.undoableReplacement;
    if (busy || kind == null) return;
    final what = kind == ReplacementKind.import ? 'import' : 'cloud restore';
    final yes = await confirm(
      'Undo $what?',
      'This puts back the progress this device had before the last $what and '
          'discards what it added.',
      'Undo',
    );
    if (!yes || !mounted) return;
    try {
      await s.undoReplacement();
      if (mounted) {
        toast('Restored the progress from before the last $what.');
      }
    } on StateError catch (e) {
      if (mounted) toast(e.message);
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
      _update(() {
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
      if (!s.signedIn) ...[
        PjskPrismCard(
          gradient: tokens.heroGradient,
          showArtOverlay: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: tokens.rainbow),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: scheme.surfaceContainer,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 36,
                    color: tokens.isDark ? tokens.aqua : scheme.primary,
                  ),
                ),
              ),
              gap(14),
              Text(
                'Your tracking stays on this device. Sign in or create an account to view and edit your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
        gap(18),
        action(
          'Sign in / Create account',
          () => go('login'),
          icon: Icons.login_rounded,
        ),
      ] else ...[
        // Authentic PJSK Custom Profile Card
        PjskPrismCard(
          gradient: tokens.heroGradient,
          showArtOverlay: true,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: tokens.rainbow),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.surfaceContainer,
                  child: Text(
                    (s.accounts.username ?? 'P').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: tokens.isDark ? tokens.aqua : scheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.accounts.username != null)
                      Text(
                        '@${s.accounts.username}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      s.client?.auth.currentUser?.email ?? 'Signed in',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cloud backup ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.isDark ? tokens.aqua : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (s.accounts.username == null) ...[
          gap(12),
          action('Finish account setup', () => go('login'), secondary: true),
        ],
        gap(20),
        label('YOUR PROGRESS'),
        gap(10),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.completedSongCount} / ${s.songs.length}',
                          key: const Key('profile-completed-songs'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: tokens.isDark ? tokens.aqua : scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Completed songs',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.collectedCardCount} / ${s.cardCatalog.length}',
                          key: const Key('profile-collected-cards'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: tokens.pink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Collected cards',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              gap(12),
              Text(
                'A clear or better on at least one chart counts once. Only Owned cards are counted.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              gap(4),
              Text(
                'Based on the progress and collection saved on this device.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          prism: true,
        ),
        gap(20),
        TextField(
          key: const Key('profile-display-name'),
          controller: displayName,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        gap(14),
        action(
          busy ? 'Saving…' : 'Save profile',
          busy
              ? null
              : () => run(
                  () => s.updateDisplayName(displayName.text),
                  success: 'Profile saved on this device.',
                ),
          icon: Icons.check_rounded,
        ),
        gap(12),
        action(
          'Sign out',
          busy
              ? null
              : () => run(() async {
                  await s.client!.auth.signOut();
                  displayName.clear();
                }, success: 'Signed out. Local tracking data is unchanged.'),
          secondary: true,
          icon: Icons.logout_rounded,
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
      box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('difficulty-${s.defaultDifficulty}'),
              initialValue: chart,
              decoration: const InputDecoration(
                labelText: 'Default chart difficulty',
              ),
              items: List.generate(
                difficulties.length,
                (d) => DropdownMenuItem(value: d, child: Text(difficulties[d])),
              ),
              onChanged: (d) => _update(() => chart = d!),
            ),
            gap(14),
            DropdownButtonFormField<String>(
              key: ValueKey('theme-${s.theme}'),
              initialValue: settingsTheme,
              decoration: const InputDecoration(labelText: 'App theme'),
              items: appPalettes
                  .map(
                    (palette) => DropdownMenuItem(
                      value: palette.id,
                      child: Row(
                        children: [
                          for (final color in palette.colors)
                            Container(
                              width: 11,
                              height: 18,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Text(palette.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _update(() => settingsTheme = v!),
            ),
            gap(10),
            PjskPalettePreview(
              paletteId: settingsTheme,
              appearance: settingsAppearance,
            ),
            gap(14),
            DropdownButtonFormField<String>(
              key: ValueKey('appearance-${s.appearance}'),
              initialValue: settingsAppearance,
              decoration: const InputDecoration(labelText: 'Appearance'),
              items: const [
                DropdownMenuItem(
                  value: 'system',
                  child: Text('System (default)'),
                ),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: (value) => _update(() => settingsAppearance = value!),
            ),
            gap(8),
            Text(
              'System follows your device’s light or dark appearance.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            gap(16),
            if (chart != s.defaultDifficulty ||
                settingsTheme != s.theme ||
                settingsAppearance != s.appearance) ...[
              Text(
                'You have unsaved preference changes.',
                style: TextStyle(
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(8),
            ],
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
              icon: Icons.check_rounded,
            ),
          ],
        ),
        padding: 16,
      ),
      gap(22),
      PjskPrismCard(
        backgroundColor: panel,
        rainbowOpacity: 0.55,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data backup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
            gap(8),
            Text(
              'Progress is saved on this device automatically. Sign in only to save or restore a cloud backup. Signing in never replaces local data.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            gap(14),
            if (!s.signedIn) ...[
              action(
                'Sign in for optional backup',
                () => go('login'),
                secondary: true,
                icon: Icons.cloud_outlined,
              ),
            ] else ...[
              if (s.accounts.username == null)
                action(
                  'Finish account setup',
                  () => go('login'),
                  secondary: true,
                ),
              gap(10),
              Text(
                s.backupAt == null
                    ? 'No cloud backup yet.'
                    : 'Last backup: ${s.backupAt!.toLocal().toString().substring(0, 16)} · '
                          '${s.pendingChanges} ${s.pendingChanges == 1 ? 'change' : 'changes'} since.',
                style: TextStyle(
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(10),
              action(
                'Save cloud backup',
                busy ? null : () => backupAction(false),
                icon: Icons.cloud_upload_outlined,
              ),
              gap(10),
              action(
                'Load cloud backup',
                busy ? null : () => backupAction(true),
                secondary: true,
                icon: Icons.cloud_download_outlined,
              ),
            ],
            gap(16),
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
              icon: Icons.file_download_outlined,
            ),
            gap(6),
            Text(
              'Saves a versioned JSON file with every attempt, favorite and card, plus the catalog snapshot it was recorded against. No account needed.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            gap(12),
            action(
              'Import progress from JSON',
              busy ? null : importProgressAction,
              secondary: true,
              icon: Icons.file_upload_outlined,
            ),
            gap(6),
            Text(
              'Restores one of your SynthDex exports on this device. You choose whether to replace or merge the attempts, favorites and cards already here. No account needed.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            if (s.undoableReplacement case final kind?) ...[
              gap(12),
              action(
                kind == ReplacementKind.import ? 'Undo import' : 'Undo restore',
                busy ? null : undoReplacementAction,
                secondary: true,
                icon: Icons.undo_rounded,
              ),
              gap(6),
              Text(
                kind == ReplacementKind.import
                    ? 'Puts back the attempts, favorites and cards this device had before the last replacing import.'
                    : 'Puts back the attempts, favorites and cards this device had before the last cloud restore.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      gap(18),
      Center(
        child: TextButton.icon(
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
                      _update(() {
                        chart = 3;
                        settingsTheme = 'dark';
                        settingsAppearance = 'system';
                      });
                    }, success: 'Local personal data reset.');
                  }
                },
          icon: Icon(Icons.restart_alt_rounded, size: 17, color: tokens.pink),
          label: Text(
            'Reset personal data',
            style: TextStyle(color: tokens.pink, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      gap(12),
      Text(
        'Artwork via Sekai Viewer. Game artwork © SEGA, Colorful Palette and Crypton Future Media. SynthDex is an unofficial fan tracker.',
        style: TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );

  Widget login() =>
      AccountPanel(accounts: s.accounts, onDone: () => go('account'));

}
