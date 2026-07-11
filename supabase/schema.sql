-- ============================================================================
-- Peekaboo — Supabase schema, RLS policies, storage, and recipient RPC.
-- Paste this whole file into the Supabase dashboard → SQL Editor → Run.
-- Safe to run more than once (idempotent).
-- ============================================================================

-- --- Storage bucket (private) -----------------------------------------------
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

-- --- Tables -----------------------------------------------------------------
create table if not exists public.photos (
  id           text primary key,
  owner_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  caption      text default '',
  storage_path text not null,
  created_at   timestamptz not null default now()
);

-- Face/subject regions (normalized 0..1 [x,y,w,h]) to keep watermark-free.
alter table public.photos
  add column if not exists subject_rects jsonb not null default '[]'::jsonb;

create table if not exists public.shares (
  token          text primary key,
  photo_id       text not null references public.photos(id) on delete cascade,
  owner_id       uuid not null default auth.uid(),
  recipient_name text default 'a loved one',
  signed_url     text not null,
  view_once      boolean not null default false,
  viewed         boolean not null default false,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz
);

-- --- Row-Level Security -----------------------------------------------------
alter table public.photos enable row level security;
alter table public.shares enable row level security;

-- Owners can do everything with THEIR OWN rows; nobody else sees them.
drop policy if exists "owner manages photos" on public.photos;
create policy "owner manages photos" on public.photos
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "owner manages shares" on public.shares;
create policy "owner manages shares" on public.shares
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
-- NOTE: recipients have NO direct read policy on `shares`. They can only reach
-- a single row through the get_share() function below, which prevents anyone
-- from listing or guessing other people's shares.

-- --- Storage policies (owner-scoped by top folder = their user id) ----------
drop policy if exists "owner uploads own objects" on storage.objects;
create policy "owner uploads own objects" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "owner reads own objects" on storage.objects;
create policy "owner reads own objects" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "owner deletes own objects" on storage.objects;
create policy "owner deletes own objects" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- --- Recipient access: token -> single photo, no login ----------------------
-- SECURITY DEFINER so an anonymous visitor can resolve exactly one share by its
-- exact token. Returns image_url = null when expired / already viewed once.
-- (Dropped first because the return signature changed to add subject_rects.)
drop function if exists public.get_share(text);
create or replace function public.get_share(p_token text)
returns table (recipient_name text, image_url text, view_once boolean, expired boolean, subject_rects jsonb)
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.shares;
  rects jsonb;
begin
  select * into s from public.shares where token = p_token;
  if not found then
    return;                       -- no rows -> "link not found"
  end if;

  if (s.expires_at is not null and now() > s.expires_at)
     or (s.view_once and s.viewed) then
    return query select s.recipient_name, null::text, s.view_once, true, '[]'::jsonb;
    return;
  end if;

  if s.view_once and not s.viewed then
    update public.shares set viewed = true where token = p_token;
  end if;

  select p.subject_rects into rects from public.photos p where p.id = s.photo_id;

  return query select s.recipient_name, s.signed_url, s.view_once, false,
                      coalesce(rects, '[]'::jsonb);
end;
$$;

grant execute on function public.get_share(text) to anon, authenticated;
