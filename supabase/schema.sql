create table public.songs (
 id text primary key, title text not null, artist text not null, unit text not null,
 color bigint not null, levels integer[] not null check(array_length(levels,1)=5)
);
create table public.attempts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 song_id text not null references public.songs(id), difficulty integer not null check(difficulty between 0 and 4),
 status integer not null check(status between 0 and 3), score integer check(score>=0),
 active boolean not null default true, created_at timestamptz not null default now()
);
create index attempts_user_chart on public.attempts(user_id,song_id,difficulty,created_at desc);
create index attempts_song on public.attempts(song_id);
create table public.favorites (
 user_id uuid not null references auth.users(id) on delete cascade,
 song_id text not null references public.songs(id), primary key(user_id,song_id)
);
create index favorites_song on public.favorites(song_id);
create table public.preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '', default_difficulty integer not null default 3 check(default_difficulty between 0 and 4)
);
alter table public.songs enable row level security;
alter table public.attempts enable row level security;
alter table public.favorites enable row level security;
alter table public.preferences enable row level security;
create policy catalog_read on public.songs for select to anon,authenticated using(true);
grant select on public.songs to anon,authenticated;

grant select,insert,update,delete on public.attempts to authenticated;
create policy own_rows on public.attempts for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

grant select,insert,update,delete on public.favorites to authenticated;
create policy own_rows on public.favorites for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

grant select,insert,update,delete on public.preferences to authenticated;
create policy own_rows on public.preferences for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
insert into public.songs values
('tell-your-world','Tell Your World','Hatsune Miku','Virtual Singer',4285485241,array[5,10,16,22,26]),
('bug','Bug','Kairiki Bear','25-ji, Nightcord de.',4289814160,array[6,12,19,26,31]),
('cinema','Cinema','Ayase','Vivid BAD SQUAD',4282615964,array[6,12,18,24,29]),
('king','KING','Kanaria','Wonderlands × Showtime',4289493853,array[7,14,19,25,29]);
