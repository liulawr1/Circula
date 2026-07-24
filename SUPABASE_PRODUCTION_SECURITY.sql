-- Circula production security migration
-- Run this ONCE in Supabase Dashboard > SQL Editor before App Store release.
-- This migration preserves existing users, listings, messages, and other app data.
-- Do not replace it with SUPABASE_SCHEMA.sql on an existing project; that file resets tables.

begin;

-- Give each listing a non-public owner identifier. Existing listings are backfilled
-- from the verified account table while new listings use the signed-in user ID.
alter table public.listings
add column if not exists owner_id uuid references auth.users(id) on delete cascade;

update public.listings as listing
set owner_id = profile.id
from public.profiles as profile
where listing.owner_id is null
  and lower(listing.owner_email) = lower(profile.email);

update public.listings as listing
set owner_id = account.id
from auth.users as account
where listing.owner_id is null
  and lower(listing.owner_email) = lower(account.email);

alter table public.listings
alter column owner_id set default auth.uid();

create index if not exists listings_owner_id_idx
on public.listings(owner_id);

-- Centralize the verified email claim used by row-level security.
create or replace function public.current_user_email()
returns text
language sql
stable
set search_path = ''
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

revoke all on function public.current_user_email() from public;
grant execute on function public.current_user_email() to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.saved_listings enable row level security;
alter table public.listing_reports enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Remove the original prototype policies.
drop policy if exists "prototype read listings" on public.listings;
drop policy if exists "prototype write listings" on public.listings;
drop policy if exists "prototype update listings" on public.listings;
drop policy if exists "prototype delete listings" on public.listings;
drop policy if exists "prototype read saved listings" on public.saved_listings;
drop policy if exists "prototype write saved listings" on public.saved_listings;
drop policy if exists "prototype delete saved listings" on public.saved_listings;
drop policy if exists "prototype read reports" on public.listing_reports;
drop policy if exists "prototype write reports" on public.listing_reports;
drop policy if exists "prototype update reports" on public.listing_reports;
drop policy if exists "prototype read conversations" on public.conversations;
drop policy if exists "prototype write conversations" on public.conversations;
drop policy if exists "prototype update conversations" on public.conversations;
drop policy if exists "prototype read messages" on public.messages;
drop policy if exists "prototype write messages" on public.messages;

-- Drop production policy names as well so this migration is safe to rerun.
drop policy if exists "public can browse listings" on public.listings;
drop policy if exists "users can create own listings" on public.listings;
drop policy if exists "users can update own listings" on public.listings;
drop policy if exists "users can delete own listings" on public.listings;
drop policy if exists "users can read own saves" on public.saved_listings;
drop policy if exists "users can create own saves" on public.saved_listings;
drop policy if exists "users can delete own saves" on public.saved_listings;
drop policy if exists "guests can submit reports" on public.listing_reports;
drop policy if exists "users can submit own reports" on public.listing_reports;
drop policy if exists "moderator can read reports" on public.listing_reports;
drop policy if exists "moderator can update reports" on public.listing_reports;
drop policy if exists "participants can read conversations" on public.conversations;
drop policy if exists "buyers can create conversations" on public.conversations;
drop policy if exists "participants can update conversation previews" on public.conversations;
drop policy if exists "participants can read messages" on public.messages;
drop policy if exists "participants can send own messages" on public.messages;

-- Guests may browse listing content, but column grants below keep owner email private.
create policy "public can browse listings"
on public.listings
for select
to anon, authenticated
using (true);

create policy "users can create own listings"
on public.listings
for insert
to authenticated
with check (
  auth.uid() is not null
  and owner_id = auth.uid()
  and lower(owner_email) = public.current_user_email()
);

create policy "users can update own listings"
on public.listings
for update
to authenticated
using (
  owner_id = auth.uid()
  and lower(owner_email) = public.current_user_email()
)
with check (
  owner_id = auth.uid()
  and lower(owner_email) = public.current_user_email()
);

create policy "users can delete own listings"
on public.listings
for delete
to authenticated
using (
  owner_id = auth.uid()
  and lower(owner_email) = public.current_user_email()
);

create policy "users can read own saves"
on public.saved_listings
for select
to authenticated
using (lower(user_email) = public.current_user_email());

create policy "users can create own saves"
on public.saved_listings
for insert
to authenticated
with check (lower(user_email) = public.current_user_email());

create policy "users can delete own saves"
on public.saved_listings
for delete
to authenticated
using (lower(user_email) = public.current_user_email());

create policy "guests can submit reports"
on public.listing_reports
for insert
to anon
with check (
  lower(reported_by_email) = 'anonymous@circula.app'
  and status = 'Open'
);

create policy "users can submit own reports"
on public.listing_reports
for insert
to authenticated
with check (
  lower(reported_by_email) = public.current_user_email()
  and status = 'Open'
);

create policy "moderator can read reports"
on public.listing_reports
for select
to authenticated
using (public.current_user_email() = 'lawrencel2026@headroyce.org');

create policy "moderator can update reports"
on public.listing_reports
for update
to authenticated
using (public.current_user_email() = 'lawrencel2026@headroyce.org')
with check (public.current_user_email() = 'lawrencel2026@headroyce.org');

create policy "participants can read conversations"
on public.conversations
for select
to authenticated
using (public.current_user_email() = any(participant_emails));

create policy "buyers can create conversations"
on public.conversations
for insert
to authenticated
with check (
  lower(buyer_email) = public.current_user_email()
  and lower(seller_email) <> public.current_user_email()
  and cardinality(participant_emails) = 2
  and lower(participant_emails[1]) = lower(buyer_email)
  and lower(participant_emails[2]) = lower(seller_email)
  and exists (
    select 1
    from public.listings
    where listings.id = conversations.listing_id
      and lower(listings.owner_email) = lower(conversations.seller_email)
  )
);

create policy "participants can update conversation previews"
on public.conversations
for update
to authenticated
using (public.current_user_email() = any(participant_emails))
with check (public.current_user_email() = any(participant_emails));

create policy "participants can read messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and public.current_user_email() = any(conversations.participant_emails)
  )
);

create policy "participants can send own messages"
on public.messages
for insert
to authenticated
with check (
  lower(sender_email) = public.current_user_email()
  and exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and public.current_user_email() = any(conversations.participant_emails)
  )
);

-- Privileges and RLS both apply. Anonymous users receive only the public listing
-- columns and report submission; private tables require a verified session.
revoke all privileges on table public.profiles from anon, authenticated;
revoke all privileges on table public.listings from anon, authenticated;
revoke all privileges on table public.saved_listings from anon, authenticated;
revoke all privileges on table public.listing_reports from anon, authenticated;
revoke all privileges on table public.conversations from anon, authenticated;
revoke all privileges on table public.messages from anon, authenticated;

grant select, insert, update on table public.profiles to authenticated;

grant select (
  id,
  title,
  category,
  condition,
  type,
  description,
  exchange_preference,
  image_data,
  owner_name,
  owner_id,
  created_at,
  status
) on table public.listings to anon;

grant select, insert, update, delete on table public.listings to authenticated;
grant select, insert, delete on table public.saved_listings to authenticated;
grant insert on table public.listing_reports to anon;
grant select, insert, update on table public.listing_reports to authenticated;
grant select, insert on table public.conversations to authenticated;
grant update (last_message, updated_at) on table public.conversations to authenticated;
grant select, insert on table public.messages to authenticated;

commit;
