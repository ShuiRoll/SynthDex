-- Catalog structure; data is generated separately by tools/import_catalog.py.
alter table public.songs add column game_id integer unique,
 add column available boolean not null default true,
 add column published_at timestamptz,
 add column search_alias text not null default '';
create table public.song_units (
 song_id text not null references public.songs(id),
 unit_id bigint not null references public.units(id),
 primary key(song_id,unit_id)
);
insert into public.song_units select id,unit_id from public.songs;
create index song_units_unit on public.song_units(unit_id);
alter table public.song_units enable row level security;
grant select on public.song_units to anon,authenticated;
create policy catalog_read on public.song_units for select to anon,authenticated using(true);
alter table public.songs drop column unit_id;
insert into public.difficulties values(5,'Append') on conflict(id) do nothing;
alter table public.attempts drop constraint attempts_difficulty_check;
alter table public.attempts add constraint attempts_difficulty_check check(difficulty between 0 and 5);
alter table public.preferences drop constraint preferences_default_difficulty_check;
alter table public.preferences add constraint preferences_default_difficulty_check check(default_difficulty between 0 and 5);
