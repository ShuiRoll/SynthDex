import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pjsk_ui.dart';
import 'themes.dart';

const artworkBase = String.fromEnvironment(
  'ARTWORK_BASE_URL',
  defaultValue: 'https://storage.sekai.best/sekai-en-assets',
);
String? jacketUrl(String bundle) =>
    bundle.isEmpty ? null : '$artworkBase/music/jacket/$bundle/$bundle.webp';
String? cardArtUrl(String bundle, {bool trained = false}) => bundle.isEmpty
    ? null
    : '$artworkBase/character/member/$bundle/card_${trained ? 'after_training' : 'normal'}.webp';
String? characterPortraitUrl(int characterId) => characterId <= 0
    ? null
    : '$artworkBase/character/character_select/chr_tl_$characterId.webp';

/// Stable bounds, accessible labels, retry, and safe offline/missing-image fallback.
class ArtworkImage extends StatefulWidget {
  /// Optional test-only override for providing decoded images without network
  /// access (null in production and standard offline tests).
  @visibleForTesting
  static ImageProvider? Function(String url)? debugImageProviderOverride;

  const ArtworkImage({
    super.key,
    required this.url,
    required this.label,
    this.icon = Icons.image_outlined,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = 12,
    this.fallbackBuilder,
  });
  final String? url;
  final String label;
  final IconData icon;
  final BoxFit fit;
  final Alignment alignment;
  final double borderRadius;
  final WidgetBuilder? fallbackBuilder;
  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  int retry = 0;
  Widget placeholder({bool failed = false}) {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!(context);
    }
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.heroGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: _PlaceholderGlossPainter(tokens: tokens),
            ),
          ),
          Center(
            child: failed
                ? IconButton(
                    tooltip: 'Artwork unavailable. Retry',
                    onPressed: () async {
                      final url = widget.url;
                      try {
                        if (url != null) {
                          if (!kIsWeb) {
                            await CachedNetworkImage.evictFromCache(url);
                          } else {
                            await NetworkImage(url).evict();
                          }
                        }
                      } catch (_) {
                        /* Cache eviction must not block a new attempt. */
                      }
                      if (mounted) setState(() => retry++);
                    },
                    icon: const Icon(Icons.refresh),
                  )
                : Icon(
                    widget.icon,
                    color: tokens.isDark ? tokens.aqua : scheme.primary,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overrideProvider = widget.url == null
        ? null
        : ArtworkImage.debugImageProviderOverride?.call(widget.url!);
    return Semantics(
      label: widget.label,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: widget.url == null
            ? placeholder()
            : overrideProvider != null
            ? Image(
                key: ValueKey('${widget.url}-$retry'),
                image: overrideProvider,
                fit: widget.fit,
                alignment: widget.alignment,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) =>
                    placeholder(failed: true),
              )
            : kIsWeb
            ? Image.network(
                widget.url!,
                key: ValueKey('${widget.url}-$retry'),
                // Third-party CDN CORS responses can prevent canvas decoding.
                // Keep canvas rendering when available, otherwise use an <img>.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: widget.fit,
                alignment: widget.alignment,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder(),
                errorBuilder: (context, error, stack) =>
                    placeholder(failed: true),
              )
            : CachedNetworkImage(
                key: ValueKey('${widget.url}-$retry'),
                imageUrl: widget.url!,
                fit: widget.fit,
                alignment: widget.alignment,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => placeholder(),
                errorWidget: (context, url, error) => placeholder(failed: true),
              ),
      ),
    );
  }
}

/// Official Project SEKAI character portrait avatar with unit-colored ring and
/// automatic offline initial fallback.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.characterId,
    required this.name,
    required this.unitColor,
    this.size = 44,
    this.circular = true,
    this.onTap,
  });

  final int characterId;
  final String name;
  final Color unitColor;
  final double size;
  final bool circular;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final radius = circular ? size / 2 : 14.0;
    final innerRadius = circular ? (size - 4) / 2 : 12.0;

    final image = ArtworkImage(
      url: characterPortraitUrl(characterId),
      label: '$name portrait',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.88),
      borderRadius: innerRadius,
      fallbackBuilder: (context) => Container(
        color: unitColor.withValues(alpha: tokens.isDark ? 0.24 : 0.18),
        child: Center(
          child: Text(
            name.isEmpty ? '?' : name.substring(0, 1),
            style: TextStyle(
              fontSize: circular ? 16 : 24,
              fontWeight: FontWeight.w800,
              color: tokens.isDark ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );

    final box = Container(
      width: size,
      height: circular ? size : size * 1.24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: unitColor, width: 1.8),
        color: unitColor.withValues(alpha: tokens.isDark ? 0.22 : 0.14),
      ),
      child: image,
    );

    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: 'Enlarge $name portrait',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: box,
        ),
      ),
    );
  }
}

void showCharacterPortrait(
  BuildContext context,
  int characterId,
  String name,
  String unit,
  Color unitColor,
) {
  showPjskDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close artwork',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: AspectRatio(
                aspectRatio: 376 / 840,
                child: InteractiveViewer(
                  child: ArtworkImage(
                    url: characterPortraitUrl(characterId),
                    label: '$name official portrait',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unitColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlaceholderGlossPainter extends CustomPainter {
  const _PlaceholderGlossPainter({required this.tokens});
  final PjskTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Subtle diagonal glass highlight across corner
    final gloss = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(0, h * 0.65)
      ..close();
    canvas.drawPath(
      gloss,
      Paint()
        ..color = Colors.white.withValues(alpha: tokens.isDark ? 0.08 : 0.32),
    );
    // Tiny corner prism accent
    final tri = Path()
      ..moveTo(w, h)
      ..lineTo(w * 0.68, h)
      ..lineTo(w, h * 0.68)
      ..close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = tokens.aqua.withValues(alpha: tokens.isDark ? 0.16 : 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _PlaceholderGlossPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

void showJacket(BuildContext context, String bundle, String title) {
  showPjskDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close artwork',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: InteractiveViewer(
                child: ArtworkImage(
                  url: jacketUrl(bundle),
                  label: '$title jacket',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class CardArtwork extends StatefulWidget {
  const CardArtwork({
    super.key,
    required this.bundle,
    required this.label,
    required this.trainable,
    this.rarityLabel,
    this.attribute,
  });
  final String bundle, label;
  final bool trainable;
  final String? rarityLabel;
  final String? attribute;
  @override
  State<CardArtwork> createState() => _CardArtworkState();
}

class _CardArtworkState extends State<CardArtwork> {
  bool trained = false;
  @override
  void didUpdateWidget(CardArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle != widget.bundle) trained = false;
  }

  void preview() => showPjskDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close artwork',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            AspectRatio(
              aspectRatio: 2048 / 1261,
              child: InteractiveViewer(
                child: ArtworkImage(
                  url: cardArtUrl(widget.bundle, trained: trained),
                  label:
                      '${widget.label} — ${trained ? 'Trained' : 'Original'}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.label} · ${trained ? 'Trained' : 'Original'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );

  int get _starCount {
    final r = widget.rarityLabel ?? '';
    if (r.startsWith('4')) return 4;
    if (r.startsWith('3')) return 3;
    if (r.startsWith('2')) return 2;
    if (r.startsWith('1')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PjskTokens.of(context);
    final stars = _starCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Holographic PJSK rainbow card frame
        Container(
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tokens.rainbow,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13.2),
            child: Stack(
              children: [
                Semantics(
                  button: true,
                  label: 'Enlarge ${widget.label}',
                  child: InkWell(
                    onTap: preview,
                    child: AspectRatio(
                      aspectRatio: 2048 / 1261,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        child: ArtworkImage(
                          key: ValueKey('${widget.bundle}-$trained'),
                          url: cardArtUrl(widget.bundle, trained: trained),
                          label: widget.label,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.rarityLabel != null || widget.attribute != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0A1228),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: tokens.aqua.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          [
                            if (widget.rarityLabel != null) widget.rarityLabel!,
                            if (widget.attribute != null)
                              widget.attribute!.toUpperCase(),
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (stars > 0)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xBB0A1228),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            stars,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: Icon(
                                trained
                                    ? Icons.auto_awesome
                                    : Icons.star_rounded,
                                size: 12,
                                color: trained
                                    ? tokens.rainbow[i % tokens.rainbow.length]
                                    : tokens.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.trainable) ...[
          const SizedBox(height: 10),
          PjskSegmentedToggle(
            leftLabel: 'Original',
            rightLabel: 'Trained',
            rightSelected: trained,
            compact: true,
            onSelectLeft: () => setState(() => trained = false),
            onSelectRight: () => setState(() => trained = true),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
