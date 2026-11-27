import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'themes.dart';

/// Full-screen Project SEKAI: COLORFUL STAGE! backdrop featuring diagonal
/// volumetric stage light shafts, floating translucent crystal prism triangles,
/// and 4-point sparkle stars. Automatically adapts between Night SEKAI (dark)
/// and Bright SEKAI Lobby (light).
class PjskStageBackdrop extends StatelessWidget {
  const PjskStageBackdrop({super.key, this.dense = false});
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PjskStagePainter(tokens: tokens, dense: dense),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PjskStagePainter extends CustomPainter {
  _PjskStagePainter({required this.tokens, required this.dense});
  final PjskTokens tokens;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final dark = tokens.isDark;

    // 1. Base gradient sky
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: tokens.stageGradient,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Diagonal volumetric stage light shafts
    final beam1 = Path()
      ..moveTo(-w * 0.1, 0)
      ..lineTo(w * 0.44, 0)
      ..lineTo(w * 0.82, h * 0.52)
      ..lineTo(w * 0.24, h * 0.52)
      ..close();
    canvas.drawPath(
      beam1,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.aqua.withValues(alpha: dark ? 0.15 : 0.20),
            const Color(0xFF33BBEE).withValues(alpha: dark ? 0.05 : 0.07),
            tokens.aqua.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    final beam2 = Path()
      ..moveTo(w * 0.58, 0)
      ..lineTo(w * 1.06, 0)
      ..lineTo(w * 0.46, h * 0.65)
      ..lineTo(w * 0.04, h * 0.65)
      ..close();
    canvas.drawPath(
      beam2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            tokens.pink.withValues(alpha: dark ? 0.13 : 0.14),
            tokens.violet.withValues(alpha: dark ? 0.05 : 0.06),
            tokens.pink.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // 3. Subtle geometric prism rays
    final rayPaint1 = Paint()
      ..color = tokens.aqua.withValues(alpha: dark ? 0.09 : 0.14)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h * 0.22), Offset(w, h * 0.09), rayPaint1);

    final rayPaint2 = Paint()
      ..color = tokens.pink.withValues(alpha: dark ? 0.08 : 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h * 0.74), Offset(w, h * 0.58), rayPaint2);

    // 4. Floating translucent SEKAI crystal prism triangles
    void drawTriangle(
      Offset a,
      Offset b,
      Offset c,
      Color color, {
      double fillOpacity = 0.14,
      double strokeOpacity = 0.42,
    }) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: fillOpacity),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: strokeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    final f = dark ? 0.13 : 0.18;
    final s = dark ? 0.40 : 0.48;

    drawTriangle(
      Offset(w * 0.82, h * 0.06),
      Offset(w * 0.94, h * 0.085),
      Offset(w * 0.87, h * 0.135),
      tokens.aqua,
      fillOpacity: f,
      strokeOpacity: s,
    );
    drawTriangle(
      Offset(w * 0.74, h * 0.18),
      Offset(w * 0.83, h * 0.15),
      Offset(w * 0.86, h * 0.205),
      tokens.gold,
      fillOpacity: f * 0.9,
      strokeOpacity: s * 0.9,
    );
    drawTriangle(
      Offset(w * 0.04, h * 0.35),
      Offset(w * 0.14, h * 0.32),
      Offset(w * 0.12, h * 0.38),
      tokens.violet,
      fillOpacity: f,
      strokeOpacity: s * 0.9,
    );
    drawTriangle(
      Offset(w * 0.84, h * 0.50),
      Offset(w * 0.95, h * 0.48),
      Offset(w * 0.91, h * 0.54),
      tokens.pink,
      fillOpacity: f,
      strokeOpacity: s * 0.9,
    );
    drawTriangle(
      Offset(w * 0.06, h * 0.76),
      Offset(w * 0.18, h * 0.79),
      Offset(w * 0.09, h * 0.83),
      tokens.aqua,
      fillOpacity: f,
      strokeOpacity: s * 0.85,
    );
    drawTriangle(
      Offset(w * 0.79, h * 0.82),
      Offset(w * 0.92, h * 0.795),
      Offset(w * 0.89, h * 0.855),
      tokens.gold,
      fillOpacity: f * 0.9,
      strokeOpacity: s * 0.85,
    );

    if (dense) {
      drawTriangle(
        Offset(w * 0.08, h * 0.09),
        Offset(w * 0.20, h * 0.115),
        Offset(w * 0.11, h * 0.16),
        tokens.pink,
        fillOpacity: f * 1.1,
        strokeOpacity: s,
      );
      drawTriangle(
        Offset(w * 0.40, h * 0.13),
        Offset(w * 0.58, h * 0.13),
        Offset(w * 0.49, h * 0.05),
        tokens.aqua,
        fillOpacity: f * 1.2,
        strokeOpacity: s,
      );
    }

    // 5. 4-point PJSK sparkle stars (placed in open sky areas away from left header text)
    void drawSparkle(Offset center, double r, Color color) {
      final inner = r * 0.28;
      final path = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + inner, center.dy - inner)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx + inner, center.dy + inner)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - inner, center.dy + inner)
        ..lineTo(center.dx - r, center.dy)
        ..lineTo(center.dx - inner, center.dy - inner)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    drawSparkle(
      Offset(w * 0.88, h * 0.095),
      9,
      (dark ? Colors.white : tokens.aqua).withValues(alpha: 0.82),
    );
    drawSparkle(
      Offset(w * 0.92, h * 0.165),
      6,
      tokens.pink.withValues(alpha: 0.78),
    );
    drawSparkle(
      Offset(w * 0.14, h * 0.56),
      6.5,
      tokens.gold.withValues(alpha: 0.72),
    );
    drawSparkle(
      Offset(w * 0.86, h * 0.70),
      7,
      tokens.aqua.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _PjskStagePainter oldDelegate) =>
      oldDelegate.tokens != tokens || oldDelegate.dense != dense;
}

/// Authentic Project SEKAI: COLORFUL STAGE! screen/tab transition:
/// directional smooth slide + crisp scale-in (`0.985 -> 1.0`) + fade,
/// accompanied by a swift, non-blocking diagonal tri-color prism ribbon sweep
/// (`///` Aqua / Pink / Gold) across the stage whenever [transitionKey] changes.
class PjskStageTransition extends StatefulWidget {
  const PjskStageTransition({
    super.key,
    required this.transitionKey,
    required this.direction,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.enableSweep = true,
  });

  final Key transitionKey;

  /// Positive (+1) slides incoming screen from right -> left (forward / next tab).
  /// Negative (-1) slides incoming screen from left -> right (back / prev tab).
  /// Zero (0) performs a crisp center scale-fade.
  final int direction;
  final Widget child;
  final Duration duration;
  final bool enableSweep;

  @override
  State<PjskStageTransition> createState() => _PjskStageTransitionState();
}

class _PjskStageTransitionState extends State<PjskStageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didUpdateWidget(PjskStageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey != widget.transitionKey && widget.enableSweep) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _sweep.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tokens = PjskTokens.of(context);
    final dir = widget.direction.clamp(-1, 1);

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : widget.duration,
          reverseDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 170),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [
              for (final prev in previousChildren)
                IgnorePointer(child: prev),
              ?currentChild,
            ],
          ),
          transitionBuilder: (child, animation) {
            final isIncoming = child.key == widget.transitionKey;
            if (reduceMotion) return child;
            final dx = dir == 0
                ? 0.0
                : (isIncoming ? 0.065 * dir : -0.045 * dir);
            final slide = Tween<Offset>(
              begin: Offset(dx, isIncoming && dir == 0 ? 0.025 : 0),
              end: Offset.zero,
            ).animate(animation);
            final scale = Tween<double>(
              begin: isIncoming ? 0.985 : 0.992,
              end: 1.0,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(scale: scale, child: child),
              ),
            );
          },
          child: KeyedSubtree(key: widget.transitionKey, child: widget.child),
        ),
        // Swift diagonal PJSK prism ribbon light sweep on screen change
        if (widget.enableSweep && !reduceMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) {
                  if (_sweep.isDismissed || _sweep.isCompleted) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: _PjskSweepPainter(
                      progress: Curves.easeOutCubic.transform(_sweep.value),
                      direction: dir == 0 ? 1 : dir,
                      tokens: tokens,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PjskSweepPainter extends CustomPainter {
  _PjskSweepPainter({
    required this.progress,
    required this.direction,
    required this.tokens,
  });

  final double progress;
  final int direction;
  final PjskTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Fade in fast then dissolve out smoothly
    final alpha = math.sin(progress * math.pi).clamp(0.0, 1.0);
    if (alpha <= 0.005) return;

    final startX = direction >= 0 ? w * 1.25 : -w * 0.45;
    final endX = direction >= 0 ? -w * 0.45 : w * 1.25;
    final baseX = startX + (endX - startX) * progress;
    final skew = h * 0.24;
    final colors = [tokens.aqua, tokens.pink, tokens.gold];
    final baseOpacity = tokens.isDark ? 0.20 : 0.24;

    for (var i = 0; i < 3; i++) {
      final offset = i * 26.0 * (direction >= 0 ? 1 : -1);
      final x = baseX + offset;
      final stripW = i == 0 ? 22.0 : 14.0;
      final path = Path()
        ..moveTo(x + skew, 0)
        ..lineTo(x + skew + stripW, 0)
        ..lineTo(x + stripW, h)
        ..lineTo(x, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = colors[i].withValues(alpha: alpha * baseOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PjskSweepPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.tokens != tokens;
}

/// Staggered PJSK entrance cascade for the first few visible items on a screen.
/// Automatically skips animation when Reduce Motion is enabled.
class PjskStaggerItem extends StatelessWidget {
  const PjskStaggerItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= 6 || MediaQuery.disableAnimationsOf(context)) return child;
    final delayMs = index * 26;
    final totalMs = 210 + delayMs;
    final startFrac = delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      builder: (context, raw, child) {
        final t = raw <= startFrac
            ? 0.0
            : Curves.easeOutCubic.transform(
                ((raw - startFrac) / (1.0 - startFrac)).clamp(0.0, 1.0),
              );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1.0 - t) * 10),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Tactile PJSK press-scale wrapper (`1.0 -> 0.982`) for SongRows, DifficultyRows,
/// and Character tiles.
class PjskPressScale extends StatefulWidget {
  const PjskPressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.982,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<PjskPressScale> createState() => _PjskPressScaleState();
}

class _PjskPressScaleState extends State<PjskPressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.pressedScale : 1.0,
      duration: const Duration(milliseconds: 105),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

/// Animated official-color PJSK difficulty progress bar (solid for Easy–Master,
/// iridescent rainbow gradient for Append).
class PjskDifficultyBar extends StatelessWidget {
  const PjskDifficultyBar({
    super.key,
    required this.difficulty,
    required this.label,
    required this.ratio,
    this.cleared,
    this.total,
    this.fullCombos,
    this.allPerfects,
  });

  final int difficulty;
  final String label;
  final double ratio;
  final int? cleared;
  final int? total;
  final int? fullCombos;
  final int? allPerfects;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final dColor = tokens.difficultyColor(difficulty);
    final isAppend = difficulty == 5;
    final target = ratio.clamp(0.0, 1.0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final countSummary = (cleared != null && total != null)
        ? '$cleared / $total'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? target : 0.0, end: target),
        duration: reduce
            ? Duration.zero
            : Duration(milliseconds: 340 + difficulty * 35),
        curve: Curves.easeOutCubic,
        builder: (context, animatedRatio, _) => Column(
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (countSummary != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        countSummary,
                        if ((fullCombos ?? 0) > 0) '${fullCombos!} FC',
                        if ((allPerfects ?? 0) > 0) '${allPerfects!} AP',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  '${(target * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: dColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animatedRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: isAppend ? null : dColor,
                    gradient: isAppend
                        ? LinearGradient(
                            colors: [dColor, tokens.pink, tokens.aqua],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact live palette preview card shown in Settings beneath the App theme
/// selector without duplicating dropdown palette names.
class PjskPalettePreview extends StatelessWidget {
  const PjskPalettePreview({
    super.key,
    required this.paletteId,
    required this.appearance,
  });

  final String paletteId;
  final String appearance;

  @override
  Widget build(BuildContext context) {
    final brightness = switch (appearance) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => MediaQuery.platformBrightnessOf(context),
    };
    final previewTheme = buildAppTheme(paletteId, brightness);
    final pScheme = previewTheme.colorScheme;
    final pTokens =
        previewTheme.extension<PjskTokens>() ??
        (brightness == Brightness.dark
            ? PjskTokens.darkDefault
            : PjskTokens.lightDefault);
    final palette = appPalettes.firstWhere(
      (p) => p.id == paletteId,
      orElse: () => appPalettes.first,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: pTokens.rainbow.map((c) => c.withValues(alpha: 0.75)).toList(),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.7),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pTokens.heroGradient,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE THEME PREVIEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: pTokens.isDark ? pTokens.aqua : pScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final c in palette.colors)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [pTokens.aquaBright, pTokens.aqua],
                ),
              ),
              child: Text(
                brightness == Brightness.dark ? 'NIGHT' : 'LOBBY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: pTokens.aquaInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a dialog with a crisp PJSK pop-in scale + fade transition.
Future<T?> showPjskDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  if (reduceMotion) {
    return showDialog<T>(context: context, builder: builder);
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.56),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Iconic PJSK tri-color diagonal ribbon slashes (`///` Aqua / Pink / Gold).
class PjskSlashes extends StatelessWidget {
  const PjskSlashes({super.key, this.height = 11});
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    return CustomPaint(
      size: Size(height * 1.65, height),
      painter: _PjskSlashesPainter(tokens),
    );
  }
}

class _PjskSlashesPainter extends CustomPainter {
  _PjskSlashesPainter(this.tokens);
  final PjskTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [tokens.aqua, tokens.pink, tokens.gold];
    final w = size.width;
    final h = size.height;
    final barW = w * 0.19;
    final skew = w * 0.22;
    for (var i = 0; i < 3; i++) {
      final startX = i * (w * 0.28);
      final path = Path()
        ..moveTo(startX + skew, 0)
        ..lineTo(startX + skew + barW, 0)
        ..lineTo(startX + barW, h)
        ..lineTo(startX, h)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _PjskSlashesPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

/// Rainbow prism-bordered container for hero cards, selected rows, and modals.
class PjskPrismCard extends StatelessWidget {
  const PjskPrismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.borderWidth = 1.5,
    this.gradient,
    this.backgroundColor,
    this.rainbowOpacity = 0.72,
    this.showArtOverlay = false,
    this.artAccent,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderWidth;
  final List<Color>? gradient;
  final Color? backgroundColor;
  final double rainbowOpacity;
  final bool showArtOverlay;
  final Color? artAccent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    final colors = tokens.rainbow
        .map((c) => c.withValues(alpha: rainbowOpacity))
        .toList();
    final innerRadius = math.max(0.0, radius - borderWidth);
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: tokens.isDark
            ? [
                BoxShadow(
                  color: tokens.aqua.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF1A3A7A).withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Container(
          decoration: BoxDecoration(
            color: gradient == null
                ? (backgroundColor ?? tokens.cardSurface)
                : null,
            gradient: gradient != null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient!,
                  )
                : null,
          ),
          child: showArtOverlay
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PjskHeroArtPainter(
                            tokens: tokens,
                            accent: artAccent ?? tokens.aqua,
                          ),
                        ),
                      ),
                    ),
                    Padding(padding: padding, child: child),
                  ],
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
    return SizedBox(width: double.infinity, child: box);
  }
}

class _PjskHeroArtPainter extends CustomPainter {
  _PjskHeroArtPainter({required this.tokens, required this.accent});
  final PjskTokens tokens;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dark = tokens.isDark;

    // Diagonal light beam
    final beam = Path()
      ..moveTo(w * 0.56, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.72, h)
      ..lineTo(w * 0.34, h)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            (dark ? accent : Colors.white).withValues(alpha: dark ? 0.18 : 0.45),
            tokens.pink.withValues(alpha: dark ? 0.06 : 0.08),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    // Top-right PJSK tri-color diagonal corner ribbon slashes ///
    final ribbonColors = [accent, tokens.pink, tokens.gold];
    for (var i = 0; i < 3; i++) {
      final rightX = w - 18 - (2 - i) * 20;
      final path = Path()
        ..moveTo(rightX - 14, 0)
        ..lineTo(rightX, 0)
        ..lineTo(rightX - 24, 26)
        ..lineTo(rightX - 38, 26)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = ribbonColors[i].withValues(alpha: 0.88),
      );
    }

    // Floating crystal triangles at bottom-right
    final tri1 = Path()
      ..moveTo(w - 44, h - 46)
      ..lineTo(w - 14, h - 30)
      ..lineTo(w - 30, h - 6)
      ..close();
    canvas.drawPath(
      tri1,
      Paint()..color = accent.withValues(alpha: dark ? 0.2 : 0.26),
    );
    canvas.drawPath(
      tri1,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final tri2 = Path()
      ..moveTo(w - 88, h - 22)
      ..lineTo(w - 64, h - 38)
      ..lineTo(w - 68, h - 8)
      ..close();
    canvas.drawPath(
      tri2,
      Paint()..color = tokens.pink.withValues(alpha: dark ? 0.16 : 0.22),
    );
    canvas.drawPath(
      tri2,
      Paint()
        ..color = tokens.pink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Small crisp sparkle star near top-right
    final cx = w - 20;
    const cy = 40.0;
    const r = 6.5;
    const ir = 1.8;
    final star = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + ir, cy - ir)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + ir, cy + ir)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - ir, cy + ir)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - ir, cy - ir)
      ..close();
    canvas.drawPath(
      star,
      Paint()..color = (dark ? Colors.white : accent).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _PjskHeroArtPainter oldDelegate) =>
      oldDelegate.tokens != tokens || oldDelegate.accent != accent;
}

/// PJSK Page Header with iconic `///` tri-color slashes + bold italic title.
class PjskPageHeader extends StatelessWidget {
  const PjskPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PjskSlashes(height: 11),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                eyebrow,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: tokens.isDark ? tokens.aqua : scheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.7,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Glossy PJSK capsule button with tactile arcade press-scale animation,
/// uniform 50px height, optical centering, and specular sheen highlight.
class PjskGlossyButton extends StatefulWidget {
  const PjskGlossyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final IconData? icon;

  @override
  State<PjskGlossyButton> createState() => _PjskGlossyButtonState();
}

class _PjskGlossyButtonState extends State<PjskGlossyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final enabled = widget.onPressed != null;
    final scale = enabled && _pressed ? 0.97 : 1.0;

    Widget content(Color fg) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: widget.secondary
                      ? FontWeight.w700
                      : FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: widget.secondary ? 0.0 : 0.15,
                  height: 1.15,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.secondary) {
      final fg = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
      return Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: tokens.isDark
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.72)
                      : scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: enabled
                        ? tokens.aqua.withValues(
                            alpha: _pressed
                                ? 0.8
                                : (tokens.isDark ? 0.38 : 0.48),
                          )
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1.25,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onHighlightChanged: _setPressed,
                  onTap: widget.onPressed,
                  child: content(fg),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final gradColors = widget.danger
        ? [const Color(0xFFFF5E84), const Color(0xFFD92652)]
        : [tokens.aquaBright, tokens.aqua];
    final textColor = widget.danger ? Colors.white : tokens.aquaInk;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradColors,
                  ),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: gradColors.last.withValues(
                              alpha: _pressed ? 0.18 : 0.34,
                            ),
                            blurRadius: _pressed ? 8 : 14,
                            offset: Offset(0, _pressed ? 2 : 4),
                          ),
                        ]
                      : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onHighlightChanged: _setPressed,
                  onTap: widget.onPressed,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glossy top specular sheen strip
                      Positioned(
                        top: 2,
                        left: 16,
                        right: 16,
                        height: 13,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: _pressed ? 0.52 : 0.42,
                                  ),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      content(textColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek full-width 2-option PJSK segmented pill toggle with smooth sliding
/// rainbow-rimmed highlight capsule (used for Characters/Cards & Original/Trained).
class PjskSegmentedToggle extends StatelessWidget {
  const PjskSegmentedToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onSelectLeft,
    required this.onSelectRight,
    this.compact = false,
  });

  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final height = compact ? 36.0 : 42.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? scheme.surfaceContainer.withValues(alpha: 0.88)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
            alignment: rightSelected
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                padding: const EdgeInsets.all(1.2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: tokens.rainbow),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.isDark
                        ? const Color(0xFF192852)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  selected: !rightSelected,
                  label: leftLabel,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onSelectLeft,
                    child: Center(
                      child: Text(
                        leftLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: !rightSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: !rightSelected
                              ? (tokens.isDark ? Colors.white : scheme.onSurface)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: rightSelected,
                  label: rightLabel,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onSelectRight,
                    child: Center(
                      child: Text(
                        rightLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: rightSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: rightSelected
                              ? (tokens.isDark ? Colors.white : scheme.onSurface)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tactile PJSK Quick Action pill button for balanced 2×2 action grids.
class PjskQuickActionTile extends StatefulWidget {
  const PjskQuickActionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final IconData? icon;

  @override
  State<PjskQuickActionTile> createState() => _PjskQuickActionTileState();
}

class _PjskQuickActionTileState extends State<PjskQuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final activeColor = tokens.isDark ? tokens.aqua : scheme.primary;

    return Semantics(
      button: true,
      selected: widget.highlighted,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: widget.highlighted
                ? activeColor.withValues(alpha: tokens.isDark ? 0.22 : 0.14)
                : (tokens.isDark
                      ? scheme.surfaceContainer.withValues(alpha: 0.88)
                      : scheme.surfaceContainer),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.highlighted
                  ? activeColor.withValues(alpha: 0.85)
                  : scheme.outlineVariant.withValues(alpha: 0.58),
              width: widget.highlighted ? 1.3 : 1.0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onHighlightChanged: (v) {
              if (_pressed != v && mounted) setState(() => _pressed = v);
            },
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 15,
                      color: widget.highlighted
                          ? activeColor
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: widget.highlighted
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: widget.highlighted
                            ? (tokens.isDark ? Colors.white : scheme.onSurface)
                            : scheme.onSurface,
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
  }
}

/// Official PJSK 6-difficulty capsule badge with diamond prism gem (`◆`).
class PjskDifficultyBadge extends StatelessWidget {
  const PjskDifficultyBadge({
    super.key,
    required this.difficulty,
    required this.label,
  });

  final int difficulty;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    final color = tokens.difficultyColor(difficulty);
    final isAppend = difficulty == 5;

    final inner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tokens.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: isAppend
            ? null
            : Border.all(color: color.withValues(alpha: 0.65), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (!isAppend) return inner;
    return Container(
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: tokens.rainbow),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: inner,
      ),
    );
  }
}

/// Official PJSK Clear Lamp badge:
/// -1 Untracked, 0 Uncleared, 1 Clear (Gold), 2 Full Combo (Pink), 3 All Perfect (Rainbow Prism).
class PjskStatusLamp extends StatelessWidget {
  const PjskStatusLamp({
    super.key,
    required this.status,
    required this.label,
  });

  final int status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final color = tokens.lampColor(status, scheme.onSurfaceVariant);
    final glyph = switch (status) {
      1 => '✓',
      2 => '★',
      3 => '✦',
      _ => '○',
    };
    final isAp = status == 3;
    final isFc = status == 2;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status >= 1
            ? color.withValues(alpha: tokens.isDark ? 0.18 : 0.13)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: isAp
            ? null
            : Border.all(
                color: status >= 1
                    ? color.withValues(alpha: 0.72)
                    : scheme.outlineVariant.withValues(alpha: 0.55),
                width: 1,
              ),
        boxShadow: (isFc || isAp) && tokens.isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.26),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: isAp
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 11, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: color,
                  ),
                ),
              ],
            )
          : Text(
              '$glyph $label',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: color,
              ),
            ),
    );

    if (!isAp) return pill;
    return Container(
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: tokens.rainbow),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: pill,
      ),
    );
  }
}

/// Iconic PJSK 6-Diamond Clear Lamp Strip (`◆ ◆ ◆ ◆ ◇ ◇`) across all available
/// difficulties for a song.
class PjskSixLampStrip extends StatelessWidget {
  const PjskSixLampStrip({
    super.key,
    required this.statusesByDifficulty,
    this.size = 7.5,
  });

  /// Ordered list of (difficultyIndex, status) for the song's charts.
  final List<(int, int)> statusesByDifficulty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final clearedCount = statusesByDifficulty.where((e) => e.$2 >= 1).length;
    return Semantics(
      label:
          '$clearedCount of ${statusesByDifficulty.length} difficulty charts cleared',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < statusesByDifficulty.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _LampDiamond(
                status: statusesByDifficulty[i].$2,
                difficultyColor: tokens.difficultyColor(
                  statusesByDifficulty[i].$1,
                ),
                tokens: tokens,
                outline: scheme.outlineVariant,
                size: size,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LampDiamond extends StatelessWidget {
  const _LampDiamond({
    required this.status,
    required this.difficultyColor,
    required this.tokens,
    required this.outline,
    required this.size,
  });

  final int status;
  final Color difficultyColor;
  final PjskTokens tokens;
  final Color outline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = switch (status) {
      1 => tokens.gold,
      2 => tokens.pink,
      3 => tokens.aqua,
      _ => Colors.transparent,
    };
    final border = switch (status) {
      1 => tokens.gold,
      2 => tokens.pink,
      3 => tokens.aqua,
      0 => difficultyColor.withValues(alpha: 0.8),
      _ => tokens.isDark
          ? outline.withValues(alpha: 0.85)
          : const Color(0xFF93A8CE),
    };
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(1.5),
          border: Border.all(color: border, width: 1.2),
          boxShadow: status >= 2 && tokens.isDark
              ? [BoxShadow(color: border.withValues(alpha: 0.55), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }
}

/// PJSK Rainbow Circular Completion Ring with smooth fill animation,
/// inner prism track, 4-point center sparkle star (`✦`), and 12-o'clock diamond.
class PjskCompletionRing extends StatelessWidget {
  const PjskCompletionRing({
    super.key,
    required this.ratio,
    this.size = 76,
  });

  final double ratio;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    final target = ratio.clamp(0.0, 1.0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '${(target * 100).toStringAsFixed(1)}% chart completion',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? target : 0.0, end: target),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, animatedRatio, _) => CustomPaint(
          size: Size.square(size),
          painter: _PjskRingPainter(ratio: animatedRatio, tokens: tokens),
        ),
      ),
    );
  }
}

class _PjskRingPainter extends CustomPainter {
  _PjskRingPainter({required this.ratio, required this.tokens});
  final double ratio;
  final PjskTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    final strokeW = size.width * 0.095;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = tokens.isDark
            ? const Color(0xFF1E2D55)
            : const Color(0xFFD5E4FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Subtle outer glow track in dark mode
    if (tokens.isDark) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = tokens.aqua.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 3,
      );
    }

    // Active rainbow completion arc
    final sweep = math.max(0.06, ratio * math.pi * 2);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [...tokens.rainbow, tokens.rainbow.first],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);

    // Inner subtle ring
    canvas.drawCircle(
      center,
      radius * 0.77,
      Paint()
        ..color = (tokens.isDark ? Colors.white : tokens.aqua).withValues(
          alpha: 0.18,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Center 4-point sparkle star
    final sr = size.width * 0.13;
    final sir = sr * 0.28;
    final star = Path()
      ..moveTo(center.dx, center.dy - sr)
      ..lineTo(center.dx + sir, center.dy - sir)
      ..lineTo(center.dx + sr, center.dy)
      ..lineTo(center.dx + sir, center.dy + sir)
      ..lineTo(center.dx, center.dy + sr)
      ..lineTo(center.dx - sir, center.dy + sir)
      ..lineTo(center.dx - sr, center.dy)
      ..lineTo(center.dx - sir, center.dy - sir)
      ..close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.rainbow,
        ).createShader(Rect.fromCircle(center: center, radius: sr)),
    );
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);

    // Top 12-o'clock diamond marker
    final top = Offset(center.dx, center.dy - radius);
    const d = 3.8;
    final diamond = Path()
      ..moveTo(top.dx, top.dy - d)
      ..lineTo(top.dx + d, top.dy)
      ..lineTo(top.dx, top.dy + d)
      ..lineTo(top.dx - d, top.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = tokens.aqua);
    canvas.drawPath(
      diamond,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _PjskRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.tokens != tokens;
}

/// PJSK 6-destination Bottom Navigation Bar with 2px Rainbow Prism top hairline
/// and smoothly animated rainbow-rimmed active pill capsule + icon pop.
class PjskBottomNav extends StatelessWidget {
  const PjskBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _labels = [
    'Home',
    'Songs',
    'Favorites',
    'Stats',
    'Roster',
    'Profile',
  ];
  static const _icons = [
    Icons.home_outlined,
    Icons.music_note_outlined,
    Icons.favorite_border,
    Icons.bar_chart_outlined,
    Icons.people_outline,
    Icons.person_outline,
  ];
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.music_note_rounded,
    Icons.favorite_rounded,
    Icons.bar_chart_rounded,
    Icons.people_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 2px PJSK Rainbow Prism top hairline
        Container(
          height: 2,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: tokens.rainbow),
          ),
        ),
        Container(
          color: tokens.isDark
              ? scheme.surface.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.96),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Row(
            children: List.generate(6, (i) {
              final selected = currentIndex == i;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: ValueKey('nav-${_labels[i].toLowerCase()}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: selected ? 46 : 40,
                            height: 30,
                            padding: selected
                                ? const EdgeInsets.all(1.3)
                                : EdgeInsets.zero,
                            decoration: selected
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      colors: tokens.rainbow,
                                    ),
                                    boxShadow: tokens.isDark
                                        ? [
                                            BoxShadow(
                                              color: tokens.aqua.withValues(
                                                alpha: 0.28,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  )
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? (tokens.isDark
                                          ? const Color(0xFF19264C)
                                          : const Color(0xFFECF9F7))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: AnimatedScale(
                                scale: selected ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  selected ? _activeIcons[i] : _icons[i],
                                  size: 20,
                                  color: selected
                                      ? (tokens.isDark
                                            ? Colors.white
                                            : scheme.onSurface)
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? (tokens.isDark
                                        ? tokens.aqua
                                        : scheme.primary)
                                  : scheme.onSurfaceVariant,
                            ),
                            child: Text(
                              _labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
    );
  }
}
