-- Appa App: optional family sync on the Supabase free tier.
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Also turn on: Authentication -> Sign In / Providers -> "Allow anonymous sign-ins".
--
-- Model: one household (Appa's family). Each phone signs in anonymously and
-- joins the household with a six-character code. Every row and every voice
-- file is visible only to members of that household (row-level security).

create extension if not exists pgcrypto;

create table if not exists public.households (
  id         uuid primary key default gen_random_uuid(),
  join_code  text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  household_id uuid not null references public.households (id) on delete cascade,
  role         text not null check (role in ('appa', 'family')),
  display_name text not null default '',
  joined_at    timestamptz not null default now()
);

create table if not exists public.stories (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  prompt_id    text not null,
  prompt_text  text not null,
  audio_path   text not null,
  created_at   timestamptz not null default now()
);

create table if not exists public.replies (
  id           uuid primary key default gen_random_uuid(),
  story_id     uuid not null references public.stories (id) on delete cascade,
  household_id uuid not null references public.households (id) on delete cascade,
  author_name  text not null,
  audio_path   text not null,
  listened     boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists stories_household_idx on public.stories (household_id, created_at desc);
create index if not exists replies_household_idx on public.replies (household_id, created_at);

-- The household of the signed-in phone, or null.
create or replace function public.my_household()
returns uuid language sql stable security definer set search_path = public as $$
  select household_id from public.members where user_id = auth.uid();
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.members where user_id = auth.uid();
$$;

-- Appa's phone creates the household and gets the code to share.
create or replace function public.create_household(p_display_name text)
returns table (household_id uuid, join_code text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_code text;
  v_id   uuid;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O, 1/I
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.household_id, h.join_code into v_id, v_code
    from public.members m join public.households h on h.id = m.household_id
   where m.user_id = auth.uid();
  if v_id is not null then
    return query select v_id, v_code; return;
  end if;
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.households where households.join_code = v_code);
  end loop;
  insert into public.households (join_code) values (v_code) returning id into v_id;
  insert into public.members (user_id, household_id, role, display_name)
    values (auth.uid(), v_id, 'appa', coalesce(p_display_name, ''));
  return query select v_id, v_code;
end;
$$;

-- A family phone joins with the code shown on Appa's phone.
create or replace function public.join_household(p_code text, p_display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select id into v_id from public.households where join_code = upper(trim(p_code));
  if v_id is null then raise exception 'unknown household code'; end if;
  insert into public.members (user_id, household_id, role, display_name)
    values (auth.uid(), v_id, 'family', coalesce(p_display_name, ''))
  on conflict (user_id) do update
    set household_id = excluded.household_id, display_name = excluded.display_name;
  return v_id;
end;
$$;

grant execute on function public.my_household(), public.my_role(),
  public.create_household(text), public.join_household(text, text) to authenticated;

alter table public.households enable row level security;
alter table public.members    enable row level security;
alter table public.stories    enable row level security;
alter table public.replies    enable row level security;

drop policy if exists "members see own household" on public.households;
create policy "members see own household" on public.households
  for select to authenticated using (id = public.my_household());

drop policy if exists "members see household members" on public.members;
create policy "members see household members" on public.members
  for select to authenticated using (household_id = public.my_household());

-- Only Appa's phone records stories; everyone in the household hears them.
drop policy if exists "household reads stories" on public.stories;
create policy "household reads stories" on public.stories
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "appa writes stories" on public.stories;
create policy "appa writes stories" on public.stories
  for insert to authenticated
  with check (household_id = public.my_household() and public.my_role() = 'appa');
drop policy if exists "appa updates stories" on public.stories;
create policy "appa updates stories" on public.stories
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');
drop policy if exists "appa deletes stories" on public.stories;
create policy "appa deletes stories" on public.stories
  for delete to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');

-- Family records replies; Appa's phone marks them heard.
drop policy if exists "household reads replies" on public.replies;
create policy "household reads replies" on public.replies
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "family writes replies" on public.replies;
create policy "family writes replies" on public.replies
  for insert to authenticated
  with check (household_id = public.my_household()
              and exists (select 1 from public.stories s
                           where s.id = story_id and s.household_id = public.my_household()));
drop policy if exists "appa marks replies heard" on public.replies;
create policy "appa marks replies heard" on public.replies
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');

-- Private bucket for voice notes. Paths are "<household_id>/...".
insert into storage.buckets (id, name, public)
  values ('voice', 'voice', false)
  on conflict (id) do nothing;

drop policy if exists "household voice read" on storage.objects;
create policy "household voice read" on storage.objects
  for select to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text);

drop policy if exists "household voice write" on storage.objects;
create policy "household voice write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text);

drop policy if exists "household voice update" on storage.objects;
create policy "household voice update" on storage.objects
  for update to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text);
