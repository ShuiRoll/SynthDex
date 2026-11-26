import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const artworkBase = String.fromEnvironment(
  'ARTWORK_BASE_URL',
  defaultValue: 'https://storage.sekai.best/sekai-en-assets',
);
String? jacketUrl(String bundle) =>
    bundle.isEmpty ? null : '$artworkBase/music/jacket/$bundle/$bundle.webp';
String? cardArtUrl(String bundle, {bool trained = false}) => bundle.isEmpty
    ? null
    : '$artworkBase/character/member/$bundle/card_${trained ? 'after_training' : 'normal'}.webp';

/// Stable bounds, accessible labels, retry, and safe offline/missing-image fallback.
class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    required this.label,
    this.icon = Icons.image_outlined,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final String label;
  final IconData icon;
  final BoxFit fit;
  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  int retry = 0;
  Widget placeholder({bool failed = false}) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Center(
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
              icon: Icon(Icons.refresh),
            )
          : Icon(widget.icon, color: Theme.of(context).colorScheme.primary),
    ),
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.url == null
          ? placeholder()
          : kIsWeb
          ? Image.network(
              widget.url!,
              key: ValueKey('${widget.url}-$retry'),
              // Third-party CDN CORS responses can prevent canvas decoding.
              // Keep canvas rendering when available, otherwise use an <img>.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: widget.fit,
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

void showJacket(BuildContext context, String bundle, String title) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close artwork',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
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
            Text(title),
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
  });
  final String bundle, label;
  final bool trainable;
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

  void preview() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close artwork',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
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
            Text('${widget.label} · ${trained ? 'Trained' : 'Original'}'),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        button: true,
        label: 'Enlarge ${widget.label}',
        child: InkWell(
          onTap: preview,
          child: AspectRatio(
            aspectRatio: 2048 / 1261,
            child: ArtworkImage(
              url: cardArtUrl(widget.bundle, trained: trained),
              label: widget.label,
            ),
          ),
        ),
      ),
      if (widget.trainable)
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Original'),
              selected: !trained,
              onSelected: (_) => setState(() => trained = false),
            ),
            ChoiceChip(
              label: Text('Trained'),
              selected: trained,
              onSelected: (_) => setState(() => trained = true),
            ),
          ],
        ),
      SizedBox(height: 12),
    ],
  );
}
