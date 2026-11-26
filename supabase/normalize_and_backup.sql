create table public.artists (id bigint generated always as identity primary key, name text not null unique);
create table public.units (id bigint generated always as identity primary key, name text not null unique);
create table public.difficulties (id integer primary key, name text not null unique);
create table public.completion_statuses (id integer primary key, name text not null unique);
insert into public.artists(name) select distinct artist from public.songs;
insert into public.units(name) select distinct unit from public.songs;
insert into public.difficulties values (0,'Easy'),(1,'Normal'),(2,'Hard'),(3,'Expert'),(4,'Master');
insert into public.completion_statuses values(0,'Uncleared'),(1,'Clear'),(2,'Full Combo'),(3,'All Perfect');
alter table public.songs add column artist_id bigint references public.artists(id), add column unit_id bigint references public.units(id);
update public.songs s set artist_id=a.id from public.artists a where a.name=s.artist;
update public.songs s set unit_id=u.id from public.units u where u.name=s.unit;
alter table public.songs alter column artist_id set not null, alter column unit_id set not null;
create index songs_artist on public.songs(artist_id);
create index songs_unit on public.songs(unit_id);
create table public.charts (
 song_id text not null references public.songs(id),
 difficulty integer not null references public.difficulties(id),
 level integer not null check(level>0),
 primary key(song_id,difficulty)
);
insert into public.charts select s.id, d.id, s.levels[d.id+1] from public.songs s cross join public.difficulties d;
alter table public.songs drop column artist, drop column unit, drop column levels;
alter table public.attempts drop constraint attempts_song_id_fkey;
alter table public.attempts drop constraint attempts_pkey;
alter table public.attempts add primary key(user_id,id);
alter table public.attempts add constraint attempts_chart_fkey foreign key(song_id,difficulty) references public.charts(song_id,difficulty);
alter table public.attempts add constraint attempts_status_fkey foreign key(status) references public.completion_statuses(id);
create index attempts_chart on public.attempts(song_id,difficulty);
create index attempts_status on public.attempts(status);
create index charts_difficulty on public.charts(difficulty);
alter table public.preferences add column theme text not null default 'dark' check(theme in ('dark','amoled'));
alter table public.preferences add constraint preferences_difficulty_fkey foreign key(default_difficulty) references public.difficulties(id);
alter table public.preferences add constraint preferences_name_length check(length(display_name)<=80);
create index preferences_difficulty on public.preferences(default_difficulty);
create table public.backups (
 user_id uuid primary key references auth.users(id) on delete cascade,
 saved_at timestamptz not null default now()
);
alter table public.backups enable row level security;
grant select,insert,update,delete on public.backups to authenticated;
create policy own_backup on public.backups for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

alter table public.artists enable row level security;
grant select on public.artists to anon,authenticated;
create policy catalog_read on public.artists for select to anon,authenticated using(true);

alter table public.units enable row level security;
grant select on public.units to anon,authenticated;
create policy catalog_read on public.units for select to anon,authenticated using(true);

alter table public.difficulties enable row level security;
grant select on public.difficulties to anon,authenticated;
create policy catalog_read on public.difficulties for select to anon,authenticated using(true);

alter table public.completion_statuses enable row level security;
grant select on public.completion_statuses to anon,authenticated;
create policy catalog_read on public.completion_statuses for select to anon,authenticated using(true);

alter table public.charts enable row level security;
grant select on public.charts to anon,authenticated;
create policy catalog_read on public.charts for select to anon,authenticated using(true);

-- JSON is an RPC transport format only. All persisted backup data is relational.
create function public.save_backup(p_attempts jsonb,p_favorites jsonb,p_name text,p_difficulty integer,p_theme text)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare uid uuid := auth.uid(); stamp timestamptz := now();
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_attempts) is distinct from 'array' or jsonb_typeof(p_favorites) is distinct from 'array' then raise exception 'Invalid backup'; end if;
 -- Serialize concurrent snapshots for the same account.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 delete from public.attempts where user_id=uid;
 delete from public.favorites where user_id=uid;
 insert into public.attempts(id,user_id,song_id,difficulty,status,score,active,created_at)
 select x.id,uid,x.song_id,x.difficulty,x.status,x.score,x.active,x.created_at
 from jsonb_to_recordset(p_attempts) as x(id uuid,song_id text,difficulty integer,status integer,score integer,active boolean,created_at timestamptz);
 insert into public.favorites(user_id,song_id) select uid,value from jsonb_array_elements_text(p_favorites);
 insert into public.preferences(user_id,display_name,default_difficulty,theme) values(uid,p_name,p_difficulty,p_theme)
 on conflict(user_id) do update set display_name=excluded.display_name,default_difficulty=excluded.default_difficulty,theme=excluded.theme;
 insert into public.backups(user_id,saved_at) values(uid,stamp) on conflict(user_id) do update set saved_at=excluded.saved_at;
 return stamp;
end $$;
revoke all on function public.save_backup(jsonb,jsonb,text,integer,text) from public,anon;
grant execute on function public.save_backup(jsonb,jsonb,text,integer,text) to authenticated;
-- One statement produces a consistent snapshot when another device is saving.
create function public.load_backup() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'version',1,
 'saved_at',b.saved_at,
 'attempts',coalesce((select jsonb_agg(to_jsonb(a)-'user_id' order by a.created_at desc) from public.attempts a where a.user_id=auth.uid()),'[]'::jsonb),
 'favorites',coalesce((select jsonb_agg(f.song_id) from public.favorites f where f.user_id=auth.uid()),'[]'::jsonb),
 'name',p.display_name,'difficulty',p.default_difficulty,'theme',p.theme)
 from public.backups b join public.preferences p on p.user_id=b.user_id where b.user_id=auth.uid()
$$;
revoke all on function public.load_backup() from public,anon;
grant execute on function public.load_backup() to authenticated;
