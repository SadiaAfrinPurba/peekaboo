-- ============================================================================
-- Peekaboo — FULL RESET.  ⚠️  DESTRUCTIVE AND IRREVERSIBLE.
-- Deletes ALL photos, galleries, vault members/invites, shares, and every
-- user account. Run in the Supabase dashboard → SQL Editor → Run.
--
-- It does NOT drop tables or change the schema — after running this you can
-- start fresh (reload the app and create a new account).
--
-- FIRST empty the `photos` bucket from the Storage UI — Supabase blocks
-- deleting storage rows from SQL (storage.protect_delete), so files must go
-- through the Storage dashboard, not this script.
-- ============================================================================

-- 1) Wipe all app data.
truncate table
  public.shares,
  public.vault_invites,
  public.vault_members,
  public.galleries,
  public.photos
cascade;

-- 2) Delete every user account (anonymous + email). Cascades to any remaining
--    owned rows via foreign keys.
delete from auth.users;
