import 'artwork_data.g.dart';
part 'characters.g.dart';

class GameCharacter {
  const GameCharacter(
    this.id,
    this.name,
    this.unit,
    this.birthday,
    this.voice,
    this.height,
    this.hobby,
  );
  final int id;
  final String name, unit, birthday, voice, height, hobby;
}

class CharacterCard {
  const CharacterCard(
    this.id,
    this.characterId,
    this.title,
    this.rarity,
    this.attribute, {
    this.remoteAssetBundle,
  });
  final int id, characterId;
  final String title, rarity, attribute;
  final String? remoteAssetBundle;
  String get assetBundle => remoteAssetBundle ?? cardAssetBundles[id] ?? '';
  bool get hasTrainedArtwork => rarity == '3' || rarity == '4';
  String get rarityLabel => rarity == 'birthday' ? 'Birthday' : '$rarity★';
  GameCharacter get character =>
      gameCharacters.firstWhere((c) => c.id == characterId);
  factory CharacterCard.fromCatalog(Map<String, dynamic> j) => CharacterCard(
    j['id'],
    j['character_id'],
    j['title'],
    j['rarity_id'],
    j['attribute_id'],
    remoteAssetBundle: j['asset_bundle'],
  );
  factory CharacterCard.fromJson(Map<String, dynamic> j) => CharacterCard(
    j['id'],
    j['character_id'],
    j['title'],
    j['rarity'],
    j['attribute'],
    remoteAssetBundle: j['asset_bundle'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'character_id': characterId,
    'title': title,
    'rarity': rarity,
    'attribute': attribute,
    'asset_bundle': remoteAssetBundle,
  };
}

class CollectedCard {
  const CollectedCard(this.cardId, {this.owned = false, this.wishlist = false});
  final int cardId;
  final bool owned, wishlist;
  Map<String, dynamic> toJson() => {
    'card_id': cardId,
    'owned': owned,
    'wishlist': wishlist,
  };
  factory CollectedCard.fromJson(Map<String, dynamic> data) => CollectedCard(
    data['card_id'],
    owned: data['owned'],
    wishlist: data['wishlist'],
  );
}
