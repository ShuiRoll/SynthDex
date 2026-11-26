-- Asset identity is a fact of each song/card; URLs are derived by the client.
alter table public.songs add column asset_bundle text;
alter table public.character_cards add column asset_bundle text;
