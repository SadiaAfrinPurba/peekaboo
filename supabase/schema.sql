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
-- A photo's `owner_id` holds the VAULT id (which equals the founding owner's
-- user id). Everyone who shares the vault is listed in `vault_members`.
create table if not exists public.photos (
  id           text primary key,
  owner_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  caption      text default '',
  storage_path text not null,
  created_at   timestamptz not null default now()
);

alter table public.photos
  add column if not exists subject_rects jsonb not null default '[]'::jsonb;
alter table public.photos
  add column if not exists taken_at timestamptz not null default now();
alter table public.photos
  add column if not exists signed_url text;
alter table public.photos
  add column if not exists signed_url_expires timestamptz;

-- The permanent family gallery link (keyed by vault id = owner_id).
create table if not exists public.galleries (
  owner_id   uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  token      text unique not null,
  baby_name  text default '',
  birthdate  date,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Who can access a vault. vault_id = the founding owner's user id; each member
-- (the owner + any invited co-owners, e.g. a spouse) gets a row here.
create table if not exists public.vault_members (
  vault_id   uuid not null,
  member_id  uuid not null references auth.users(id) on delete cascade,
  role       text not null default 'coowner',
  created_at timestamptz not null default now(),
  primary key (vault_id, member_id)
);

-- Pending invites to join a vault as a co-owner.
create table if not exists public.vault_invites (
  token      text primary key,
  vault_id   uuid not null,
  created_by uuid not null default auth.uid(),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

-- Legacy single-photo shares (still supported for one-off /v/<token>).
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

-- --- Row-Level Security ------------------------------------------------------
alter table public.photos enable row level security;
alter table public.galleries enable row level security;
alter table public.vault_members enable row level security;
alter table public.vault_invites enable row level security;
alter table public.shares enable row level security;

-- vault_members: you can see your OWN membership rows (simple, no recursion),
-- and create your OWN self-vault. Joining someone else's vault happens only
-- through redeem_invite() (SECURITY DEFINER), never a direct insert.
drop policy if exists "see own memberships" on public.vault_members;
create policy "see own memberships" on public.vault_members
  for select to authenticated
  using (member_id = auth.uid());

drop policy if exists "create own self vault" on public.vault_members;
create policy "create own self vault" on public.vault_members
  for insert to authenticated
  with check (member_id = auth.uid() and vault_id = auth.uid());

-- Photos & galleries: any member of the vault can manage them.
drop policy if exists "owner manages photos" on public.photos;
drop policy if exists "members manage vault photos" on public.photos;
create policy "members manage vault photos" on public.photos
  for all to authenticated
  using (owner_id in (
    select vault_id from public.vault_members where member_id = auth.uid()))
  with check (owner_id in (
    select vault_id from public.vault_members where member_id = auth.uid()));

drop policy if exists "owner manages gallery" on public.galleries;
drop policy if exists "members manage gallery" on public.galleries;
create policy "members manage gallery" on public.galleries
  for all to authenticated
  using (owner_id in (
    select vault_id from public.vault_members where member_id = auth.uid()))
  with check (owner_id in (
    select vault_id from public.vault_members where member_id = auth.uid()));

-- Invites: any member of the vault can create/see/delete its invites.
drop policy if exists "members manage invites" on public.vault_invites;
create policy "members manage invites" on public.vault_invites
  for all to authenticated
  using (vault_id in (
    select vault_id from public.vault_members where member_id = auth.uid()))
  with check (vault_id in (
    select vault_id from public.vault_members where member_id = auth.uid()));

drop policy if exists "owner manages shares" on public.shares;
create policy "owner manages shares" on public.shares
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- --- Storage policies (folder = vault id; any member may read/write) ---------
drop policy if exists "owner uploads own objects" on storage.objects;
drop policy if exists "members upload vault objects" on storage.objects;
create policy "members upload vault objects" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] in (
    select vault_id::text from public.vault_members where member_id = auth.uid()));

drop policy if exists "owner reads own objects" on storage.objects;
drop policy if exists "members read vault objects" on storage.objects;
create policy "members read vault objects" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] in (
    select vault_id::text from public.vault_members where member_id = auth.uid()));

drop policy if exists "owner deletes own objects" on storage.objects;
drop policy if exists "members delete vault objects" on storage.objects;
create policy "members delete vault objects" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] in (
    select vault_id::text from public.vault_members where member_id = auth.uid()));

-- --- Join a vault via an invite token (SECURITY DEFINER) --------------------
-- The invited (signed-in) user redeems a token to become a co-owner. Runs as
-- definer so it can insert the membership row the caller couldn't insert itself.
drop function if exists public.redeem_invite(text);
create or replace function public.redeem_invite(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.vault_invites;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'signin_required');
  end if;

  select * into inv from public.vault_invites where token = p_token;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if inv.expires_at is not null and now() > inv.expires_at then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  insert into public.vault_members (vault_id, member_id, role)
  values (inv.vault_id, auth.uid(), 'coowner')
  on conflict (vault_id, member_id) do nothing;

  return jsonb_build_object('ok', true, 'vault_id', inv.vault_id);
end;
$$;

grant execute on function public.redeem_invite(text) to authenticated;

-- --- Family gallery: token -> every photo, no login -------------------------
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
    return;
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
