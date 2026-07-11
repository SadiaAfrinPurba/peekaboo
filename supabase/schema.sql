-- ============================================================================
-- Peekaboo — Supabase schema, RLS policies, storage, and recipient RPCs.
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

-- When the photo was taken (drives the timeline + age). Defaults to upload time
-- so existing rows stay sensible; the owner can set a real date on upload.
alter table public.photos
  add column if not exists taken_at timestamptz not null default now();

-- A long-lived signed URL so the family gallery link keeps working without a
-- login. Refreshed by the owner's app well before it expires.
alter table public.photos
  add column if not exists signed_url text;
alter table public.photos
  add column if not exists signed_url_expires timestamptz;

-- The single, permanent "family gallery" link. One row per owner. Sharing the
-- token lets grandma/auntie/etc. browse every photo — no login, same link for
-- everyone. Flip `active` to false to revoke it; set it back to re-enable.
create table if not exists public.galleries (
  owner_id   uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  token      text unique not null,
  baby_name  text default '',
  birthdate  date,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- --- Legacy single-photo shares (still supported for one-off /v/<token>) -----
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
alter table public.galleries enable row level security;

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

drop policy if exists "owner manages gallery" on public.galleries;
create policy "owner manages gallery" on public.galleries
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
-- NOTE: recipients have NO direct read policy on these tables. They reach photos
-- only through get_gallery()/get_share() below, so nobody can list or guess
-- other people's content.

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

-- --- Family gallery: token -> every photo, no login -------------------------
-- SECURITY DEFINER so an anonymous visitor can resolve a gallery by its exact
-- token. Returns baby name/birthdate (for age labels) + all photos newest-first.
-- Returns {found:false} for a bad token and {active:false} when revoked.
drop function if exists public.get_gallery(text);
create or replace function public.get_gallery(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.galleries;
begin
  select * into g from public.galleries where token = p_token;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  if not g.active then
    return jsonb_build_object(
      'found', true, 'active', false, 'baby_name', g.baby_name);
  end if;

  return jsonb_build_object(
    'found', true,
    'active', true,
    'baby_name', g.baby_name,
    'birthdate', g.birthdate,
    'photos', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'caption', p.caption,
          'taken_at', p.taken_at,
          'image_url', p.signed_url,
          'subject_rects', p.subject_rects
        ) order by p.taken_at desc)
      from public.photos p
      where p.owner_id = g.owner_id and p.signed_url is not null
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.get_gallery(text) to anon, authenticated;

-- --- Legacy single-photo recipient access -----------------------------------
-- (Kept so old /v/<token> links still resolve. New sharing uses get_gallery.)
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
