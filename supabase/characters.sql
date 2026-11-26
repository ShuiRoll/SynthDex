create table public.characters (
 id integer primary key, name text not null, unit_id bigint not null references public.units(id),
 birthday text not null, voice text not null, height text not null, hobby text not null
);
create index characters_unit on public.characters(unit_id);
create table public.card_rarities(id text primary key);
insert into public.card_rarities values('1'),('2'),('3'),('4'),('birthday');
create table public.card_attributes(id text primary key);
insert into public.card_attributes values('cool'),('cute'),('happy'),('mysterious'),('pure');
create table public.character_cards (
 id integer primary key, character_id integer not null references public.characters(id),
 title text not null, rarity_id text not null references public.card_rarities(id),
 attribute_id text not null references public.card_attributes(id), released_at timestamptz not null
);
create index character_cards_character on public.character_cards(character_id);
create index character_cards_rarity on public.character_cards(rarity_id);
create index character_cards_attribute on public.character_cards(attribute_id);
create table public.card_collection (
 user_id uuid not null references auth.users(id) on delete cascade,
 card_id integer not null references public.character_cards(id), owned boolean not null,
 wishlist boolean not null, primary key(user_id,card_id), check(owned or wishlist)
);
create index card_collection_card on public.card_collection(card_id);
alter table public.characters enable row level security;
alter table public.card_rarities enable row level security;
alter table public.card_attributes enable row level security;
alter table public.character_cards enable row level security;
alter table public.card_collection enable row level security;
revoke all on public.characters,public.card_rarities,public.card_attributes,public.character_cards from anon,authenticated;
grant select on public.characters,public.card_rarities,public.card_attributes,public.character_cards to anon,authenticated;
create policy catalog_read on public.characters for select to anon,authenticated using(true);
create policy catalog_read on public.card_rarities for select to anon,authenticated using(true);
create policy catalog_read on public.card_attributes for select to anon,authenticated using(true);
create policy catalog_read on public.character_cards for select to anon,authenticated using(true);
revoke all on public.card_collection from anon,authenticated;
grant select,insert,update,delete on public.card_collection to authenticated;
create policy own_collection on public.card_collection for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

-- Preserve the v1 RPC for older clients; their saves do not erase card collections.
create function public.save_backup_v2(p_attempts jsonb,p_favorites jsonb,p_name text,p_difficulty integer,p_theme text,p_cards jsonb)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare stamp timestamptz; uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_cards) is distinct from 'array' then raise exception 'Invalid card collection'; end if;
 stamp := public.save_backup(p_attempts,p_favorites,p_name,p_difficulty,p_theme);
 delete from public.card_collection where user_id=uid;
 insert into public.card_collection(user_id,card_id,owned,wishlist)
 select uid,x.card_id,x.owned,x.wishlist from jsonb_to_recordset(p_cards) x(card_id integer,owned boolean,wishlist boolean);
 return stamp;
end $$;
revoke all on function public.save_backup_v2(jsonb,jsonb,text,integer,text,jsonb) from public,anon;
grant execute on function public.save_backup_v2(jsonb,jsonb,text,integer,text,jsonb) to authenticated;
create function public.load_backup_v2() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.load_backup() || jsonb_build_object('cards',coalesce((select jsonb_agg(jsonb_build_object('card_id',card_id,'owned',owned,'wishlist',wishlist) order by card_id) from public.card_collection where user_id=auth.uid()),'[]'::jsonb))
$$;
revoke all on function public.load_backup_v2() from public,anon;
grant execute on function public.load_backup_v2() to authenticated;
