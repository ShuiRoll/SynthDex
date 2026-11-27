import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'artwork.dart';
import 'characters.dart';
import 'pjsk_ui.dart';
import 'store.dart';
import 'themes.dart';

class CharacterCollection extends StatefulWidget {
  const CharacterCollection({
    super.key,
    required this.store,
    this.scrollController,
    this.onRefresh,
  });
  final AppStore store;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  @override
  State<CharacterCollection> createState() => _CharacterCollectionState();
}

class _CharacterCollectionState extends State<CharacterCollection> {
  bool cardsView = false, busy = false;
  String query = '',
      unit = 'All units',
      rarity = 'All rarities',
      attribute = 'All attributes',
      collection = 'All cards';
  GameCharacter? selected;
  String? error;
  int limit = 30;
  final TextEditingController _search = TextEditingController();
  AppStore get s => widget.store;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    query = '';
    limit = 30;
  }
  Future<void> changeCard(
    CharacterCard card, {
    bool? owned,
    bool? wishlist,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    final current = s.collectionEntry(card.id);
    try {
      await s.setCard(
        card.id,
        owned: owned ?? current.owned,
        wishlist: wishlist ?? current.wishlist,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not save this card. Your collection has not changed.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget dropdown(
    String value,
    List<String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
    items: options
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(v, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() {
      change(v!);
      limit = 30;
    }),
  );

  Widget panel(Widget child, {Color? railColor}) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(
          alpha: tokens.isDark ? 0.90 : 0.96,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (railColor ?? scheme.outlineVariant).withValues(
            alpha: railColor != null ? 0.42 : 0.5,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: railColor == null
            ? Padding(padding: const EdgeInsets.all(16), child: child)
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: railColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = PjskTokens.of(context);
    final characters = gameCharacters
        .where(
          (c) =>
              (unit == 'All units' || c.unit == unit) &&
              '${c.name} ${c.unit}'.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final matching = s.cardCatalog.where((c) {
      final entry = s.collectionEntry(c.id);
      return (selected == null || c.characterId == selected!.id) &&
          (unit == 'All units' || c.character.unit == unit) &&
          (rarity == 'All rarities' || c.rarityLabel == rarity) &&
          (attribute == 'All attributes' || c.attribute == attribute) &&
          (collection == 'All cards' ||
              (collection == 'Owned' && entry.owned) ||
              (collection == 'Wishlist' && entry.wishlist) ||
              (collection == 'Not owned' && !entry.owned)) &&
          '${c.title} ${c.character.name}'.toLowerCase().contains(
            query.toLowerCase(),
          );
    }).toList()..sort((a, b) => b.id.compareTo(a.id));

    final ownedCount = s.cardCollection.values.where((c) => c.owned).length;
    final wishlistCount = s.cardCollection.values
        .where((c) => c.wishlist)
        .length;
    final visibleCards = matching.length < limit ? matching.length : limit;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PjskPageHeader(
          eyebrow: 'YOUR CHARACTERS',
          title: 'Roster & collection',
          subtitle:
              '${gameCharacters.length} characters · ${s.cardCatalog.length} Global cards · $ownedCount owned · $wishlistCount on wishlist',
        ),
        PjskSegmentedToggle(
          leftLabel: 'Characters',
          rightLabel: 'Cards',
          rightSelected: cardsView,
          onSelectLeft: () => setState(() {
            cardsView = false;
            selected = null;
            _clearSearch();
          }),
          onSelectRight: () => setState(() {
            cardsView = true;
            selected = null;
            _clearSearch();
          }),
        ),
        const SizedBox(height: 14),
        if (selected != null) ...[
          PjskPrismCard(
            gradient: tokens.isDark
                ? [
                    Color.lerp(
                      const Color(0xFF0E1D46),
                      PjskTokens.unitColor(selected!.unit),
                      0.24,
                    )!,
                    const Color(0xFF1D1748),
                    const Color(0xFF0D1633),
                  ]
                : tokens.heroGradient,
            showArtOverlay: true,
            artAccent: PjskTokens.unitColor(selected!.unit),
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CharacterAvatar(
                      characterId: selected!.id,
                      name: selected!.name,
                      unitColor: PjskTokens.unitColor(selected!.unit),
                      size: 56,
                      circular: false,
                      onTap: () => showCharacterPortrait(
                        context,
                        selected!.id,
                        selected!.name,
                        selected!.unit,
                        PjskTokens.unitColor(selected!.unit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Birthday: ${selected!.birthday} · Height: ${selected!.height}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Voice: ${selected!.voice}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Hobbies: ${selected!.hobby}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PjskTokens.unitColor(
                          selected!.unit,
                        ).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PjskTokens.unitColor(
                            selected!.unit,
                          ).withValues(alpha: 0.72),
                        ),
                      ),
                      child: Text(
                        selected!.unit,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.isDark ? Colors.white : scheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: tokens.aqua.withValues(alpha: 0.14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => setState(() => selected = null),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: 13,
                        color: tokens.isDark ? tokens.aqua : scheme.primary,
                      ),
                      label: Text(
                        'Show all characters’ cards',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.isDark ? tokens.aqua : scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        TextField(
          key: ValueKey('character-search-$cardsView-${selected?.id}'),
          controller: _search,
          onChanged: (v) => setState(() {
            query = v;
            limit = 30;
          }),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: cardsView
                ? 'Search card title or character'
                : 'Search characters',
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(_clearSearch),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (!cardsView)
          dropdown(unit, [
            'All units',
            ...gameCharacters.map((c) => c.unit).toSet(),
          ], (v) => unit = v)
        else ...[
          Row(
            children: [
              Expanded(
                child: dropdown(unit, [
                  'All units',
                  ...gameCharacters.map((c) => c.unit).toSet(),
                ], (v) => unit = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: dropdown(collection, [
                  'All cards',
                  'Owned',
                  'Wishlist',
                  'Not owned',
                ], (v) => collection = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: dropdown(rarity, [
                  'All rarities',
                  '1★',
                  '2★',
                  '3★',
                  '4★',
                  'Birthday',
                ], (v) => rarity = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: dropdown(attribute, [
                  'All attributes',
                  'cool',
                  'cute',
                  'happy',
                  'mysterious',
                  'pure',
                ], (v) => attribute = v),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (error != null) Text(error!, style: TextStyle(color: scheme.error)),
        Text(
          cardsView
              ? '${matching.length} matching cards'
              : '${characters.length} characters',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    final scrollView = CustomScrollView(
      key: const PageStorageKey('roster-scroll'),
      controller: widget.scrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(650),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverToBoxAdapter(child: header),
        ),
        if (!cardsView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: characters.length,
              itemBuilder: (context, index) {
                final c = characters[index];
                final uColor = PjskTokens.unitColor(c.unit);
                return PjskStaggerItem(
                  key: ValueKey('char-row-${c.id}'),
                  index: index,
                  child: PjskPressScale(
                    child: panel(
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CharacterAvatar(
                          characterId: c.id,
                          name: c.name,
                          unitColor: uColor,
                          size: 44,
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${c.unit} · ${c.birthday}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: uColor,
                        ),
                        onTap: () => setState(() {
                          selected = c;
                          cardsView = true;
                          _clearSearch();
                          rarity = 'All rarities';
                          attribute = 'All attributes';
                          collection = 'All cards';
                        }),
                      ),
                      railColor: uColor,
                    ),
                  ),
                );
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: visibleCards,
              itemBuilder: (context, index) {
                final c = matching[index];
                return PjskStaggerItem(
                  key: ValueKey('card-tile-${c.id}-${selected?.id}'),
                  index: index,
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CardArtwork(
                          key: ValueKey('art-${c.id}'),
                          bundle: c.assetBundle,
                          label: '${c.character.name}: ${c.title}',
                          trainable: c.hasTrainedArtwork,
                          rarityLabel: c.rarityLabel,
                          attribute: c.attribute,
                        ),
                        Text(
                          c.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => setState(() {
                            selected = c.character;
                            _clearSearch();
                            unit = 'All units';
                          }),
                          child: Text(c.character.name),
                        ),
                        Text(
                          '${c.rarityLabel} · ${c.attribute} · #${c.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilterChip(
                              key: ValueKey('owned-${c.id}'),
                              label: const Text('Owned'),
                              selected: s.collectionEntry(c.id).owned,
                              onSelected: busy
                                  ? null
                                  : (v) => changeCard(c, owned: v),
                            ),
                            FilterChip(
                              key: ValueKey('wishlist-${c.id}'),
                              label: const Text('Wishlist'),
                              selected: s.collectionEntry(c.id).wishlist,
                              onSelected: busy
                                  ? null
                                  : (v) => changeCard(c, wishlist: v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!cardsView && characters.isEmpty)
                  const Text('No characters match your search.'),
                if (cardsView && matching.isEmpty)
                  const Text('No cards match these filters.'),
                if (cardsView && matching.length > limit)
                  PjskGlossyButton(
                    label: 'Show more (${matching.length - limit} remaining)',
                    onPressed: () => setState(() => limit += 30),
                    secondary: true,
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: scrollView);
    }
    return scrollView;
  }
}
