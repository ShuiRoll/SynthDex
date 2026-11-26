alter table public.preferences drop constraint preferences_theme_check;
alter table public.preferences add constraint preferences_theme_check check(theme in ('dark','amoled','crimson','mint','peach','forest','azure','solar'));
alter table public.preferences add column appearance text not null default 'system' check(appearance in ('system','light','dark'));

create function public.save_backup_v3(p_attempts jsonb,p_favorites jsonb,p_name text,p_difficulty integer,p_theme text,p_cards jsonb,p_appearance text)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare stamp timestamptz;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_appearance is null or p_appearance not in ('system','light','dark') then raise exception 'Invalid appearance'; end if;
 stamp := public.save_backup_v2(p_attempts,p_favorites,p_name,p_difficulty,p_theme,p_cards);
 update public.preferences set appearance=p_appearance where user_id=auth.uid();
 return stamp;
end $$;
revoke all on function public.save_backup_v3(jsonb,jsonb,text,integer,text,jsonb,text) from public,anon;
grant execute on function public.save_backup_v3(jsonb,jsonb,text,integer,text,jsonb,text) to authenticated;

create function public.load_backup_v3() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.load_backup_v2() || jsonb_build_object('appearance',(select appearance from public.preferences where user_id=auth.uid()))
$$;
revoke all on function public.load_backup_v3() from public,anon;
grant execute on function public.load_backup_v3() to authenticated;
