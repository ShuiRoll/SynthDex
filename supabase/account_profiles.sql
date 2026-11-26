create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null check(username ~ '^[A-Za-z0-9_]{3,24}$')
);
create unique index profiles_username_unique on public.profiles(lower(username));
alter table public.profiles enable row level security;
grant select,insert,update on public.profiles to authenticated;
revoke all on public.profiles from anon;
create policy own_profile on public.profiles for all to authenticated
 using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
