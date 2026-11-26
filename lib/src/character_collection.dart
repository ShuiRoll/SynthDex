import 'package:flutter/material.dart';

import 'characters.dart';
import 'store.dart';
import 'artwork.dart';

class CharacterCollection extends StatefulWidget {
  const CharacterCollection({super.key, required this.store});
  final AppStore store;
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
  AppStore get s => widget.store;
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
    decoration: InputDecoration(contentPadding: EdgeInsets.all(12)),
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
  Widget panel(Widget child) => Container(
    margin: EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  @override
  Widget build(BuildContext context) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR CHARACTERS',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Roster & collection',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          '${gameCharacters.length} characters · ${s.cardCatalog.length} Global cards',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${s.cardCollection.values.where((c) => c.owned).length} owned · ${s.cardCollection.values.where((c) => c.wishlist).length} on wishlist',
        ),
        SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Characters'),
              selected: !cardsView,
              onSelected: (_) => setState(() {
                cardsView = false;
                selected = null;
                query = '';
              }),
            ),
            ChoiceChip(
              label: Text('Cards'),
              selected: cardsView,
              onSelected: (_) => setState(() {
                cardsView = true;
                selected = null;
                query = '';
              }),
            ),
          ],
        ),
        SizedBox(height: 14),
        if (selected != null)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected!.name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(selected!.unit),
                SizedBox(height: 12),
                Text('Birthday: ${selected!.birthday}'),
                Text('Voice: ${selected!.voice}'),
                Text('Height: ${selected!.height}'),
                Text('Hobbies: ${selected!.hobby}'),
                TextButton(
                  onPressed: () => setState(() => selected = null),
                  child: Text('Show all characters’ cards'),
                ),
              ],
            ),
          ),
        TextField(
          key: ValueKey('character-search-$cardsView-${selected?.id}'),
          onChanged: (v) => setState(() {
            query = v;
            limit = 30;
          }),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: cardsView
                ? 'Search card title or character'
                : 'Search characters',
          ),
        ),
        SizedBox(height: 12),
        dropdown(unit, [
          'All units',
          ...gameCharacters.map((c) => c.unit).toSet(),
        ], (v) => unit = v),
        if (cardsView) ...[
          SizedBox(height: 12),
          dropdown(collection, [
            'All cards',
            'Owned',
            'Wishlist',
            'Not owned',
          ], (v) => collection = v),
          SizedBox(height: 12),
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
              SizedBox(width: 10),
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
        SizedBox(height: 18),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!cardsView) ...[
          Text('${characters.length} characters'),
          SizedBox(height: 12),
          for (final c in characters)
            panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(c.name.substring(0, 1))),
                title: Text(c.name),
                subtitle: Text(c.unit),
                trailing: Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  selected = c;
                  cardsView = true;
                  query = '';
                  rarity = 'All rarities';
                  attribute = 'All attributes';
                  collection = 'All cards';
                  limit = 30;
                }),
              ),
            ),
          if (characters.isEmpty) Text('No characters match your search.'),
        ] else ...[
          Text('${matching.length} matching cards'),
          SizedBox(height: 12),
          for (final c in matching.take(limit))
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardArtwork(
                    key: ValueKey('art-${c.id}'),
                    bundle: c.assetBundle,
                    label: '${c.character.name}: ${c.title}',
                    trainable: c.hasTrainedArtwork,
                  ),
                  Text(
                    c.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      selected = c.character;
                      query = '';
                      unit = 'All units';
                      limit = 30;
                    }),
                    child: Text(c.character.name),
                  ),
                  Text(
                    '${c.rarityLabel} · ${c.attribute} · #${c.id}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        key: ValueKey('owned-${c.id}'),
                        label: Text('Owned'),
                        selected: s.collectionEntry(c.id).owned,
                        onSelected: busy
                            ? null
                            : (v) => changeCard(c, owned: v),
                      ),
                      FilterChip(
                        key: ValueKey('wishlist-${c.id}'),
                        label: Text('Wishlist'),
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
          if (matching.isEmpty) Text('No cards match these filters.'),
          if (matching.length > limit)
            OutlinedButton(
              onPressed: () => setState(() => limit += 30),
              child: Text('Show more (${matching.length - limit} remaining)'),
            ),
        ],
      ],
    );
  }
}
