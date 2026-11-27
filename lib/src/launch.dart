import 'package:flutter/material.dart';

import 'app.dart';
import 'pjsk_ui.dart';
import 'store.dart';
import 'themes.dart';

/// Paints immediately while startup loads local storage and optional services.
class SynthDexLaunch extends StatefulWidget {
  const SynthDexLaunch({super.key, required this.initialize});
  final Future<AppStore> Function() initialize;
  @override
  State<SynthDexLaunch> createState() => _SynthDexLaunchState();
}

class _SynthDexLaunchState extends State<SynthDexLaunch> {
  late Future<AppStore> startup = widget.initialize();
  AppStore? linkedStore;
  @override
  Widget build(BuildContext context) => FutureBuilder<AppStore>(
    future: startup,
    builder: (context, snapshot) {
      final Widget screen;
      if (snapshot.hasData) {
        final store = snapshot.requireData;
        if (linkedStore != store) {
          linkedStore = store;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) store.accounts.startLinks();
          });
        }
        screen = SynthDexApp(key: const ValueKey('app-ready'), store: store);
      } else {
        screen = MaterialApp(
          key: const ValueKey('app-launch'),
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme('dark', Brightness.light),
          darkTheme: buildAppTheme('dark', Brightness.dark),
          themeMode: ThemeMode.system,
          home: LaunchScreen(
            failed:
                snapshot.connectionState == ConnectionState.done &&
                snapshot.hasError,
            onRetry: () {
              final nextStartup = widget.initialize();
              setState(() {
                startup = nextStartup;
              });
            },
          ),
        );
      }
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: screen,
      );
    },
  );
}

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key, this.failed = false, this.onRetry});
  final bool failed;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PjskStageBackdrop(dense: true)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing PJSK rainbow-rimmed emblem
                      Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: tokens.rainbow,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.aqua.withValues(
                                alpha: tokens.isDark ? 0.32 : 0.22,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: tokens.heroGradient,
                            ),
                          ),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: 44,
                            color: tokens.isDark ? tokens.aqua : colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const PjskSlashes(height: 10),
                      const SizedBox(height: 10),
                      Text(
                        'SynthDex',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1.2,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your rhythm, tracked.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 44),
                      if (!failed) ...[
                        Container(
                          width: 196,
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: tokens.rainbow
                                  .map((c) => c.withValues(alpha: 0.55))
                                  .toList(),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              color: tokens.aqua,
                              backgroundColor: colors.surfaceContainer,
                              semanticsLabel: 'Loading SynthDex',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        failed
                            ? 'Could not open your local library.'
                            : 'Opening your library…',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (failed) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Your saved data has not been reset.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        PjskGlossyButton(
                          label: 'Try again',
                          onPressed: onRetry,
                        ),
                      ],
                      const SizedBox(height: 44),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          'LOCAL FIRST · CLOUD OPTIONAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
