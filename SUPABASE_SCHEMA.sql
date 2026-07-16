-- Circula Supabase schema
-- Run this in Supabase Dashboard > SQL Editor.
-- Initial setup script: this resets these app tables, then recreates them.

create extension if not exists pgcrypto;

drop table if exists public.messages cascade;
drop table if exists public.conversations cascade;
drop table if exists public.saved_listings cascade;
drop table if exists public.listing_reports cascade;
drop table if exists public.listings cascade;
drop table if exists public.profiles cascade;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key,
  title text not null,
  category text not null,
  condition text not null,
  type text not null,
  description text not null,
  exchange_preference text not null,
  image_data text,
  owner_name text not null,
  owner_email text not null,
  created_at timestamptz not null default now(),
  status text not null default 'Available'
);

create table if not exists public.saved_listings (
  user_email text not null,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_email, listing_id)
);

create table if not exists public.listing_reports (
  id uuid primary key,
  listing_id uuid not null,
  listing_title text not null,
  reported_by_email text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  status text not null default 'Open'
);

create table if not exists public.conversations (
  id uuid primary key,
  listing_id uuid not null references public.listings(id) on delete cascade,
  listing_title text not null,
  buyer_email text not null,
  buyer_name text not null,
  seller_email text not null,
  seller_name text not null,
  participant_emails text[] not null,
  last_message text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  text text not null,
  sender_email text not null,
  sender_name text not null,
  created_at timestamptz not null default now()
);

create index if not exists listings_created_at_idx on public.listings(created_at desc);
create index if not exists saved_listings_user_email_idx on public.saved_listings(user_email);
create index if not exists conversations_updated_at_idx on public.conversations(updated_at desc);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at asc);

alter table public.listings enable row level security;
alter table public.saved_listings enable row level security;
alter table public.listing_reports enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.profiles enable row level security;

create policy "users can read own profile" on public.profiles for select using (auth.uid() = id);

create policy "users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

create policy "users can update own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is null or lower(new.email) not like '%@headroyce.org' then
    raise exception 'Only Head-Royce email addresses can sign up';
  end if;

  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    lower(new.email),
    coalesce(new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_user_email text;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select lower(email)
  into current_user_email
  from auth.users
  where id = current_user_id;

  delete from public.messages
  where sender_email = current_user_email
     or conversation_id in (
       select id
       from public.conversations
       where current_user_email = any(participant_emails)
     );

  delete from public.conversations
  where current_user_email = any(participant_emails);

  delete from public.saved_listings
  where user_email = current_user_email;

  delete from public.listing_reports
  where reported_by_email = current_user_email;

  delete from public.listings
  where owner_email = current_user_email;

  delete from auth.users
  where id = current_user_id;
end;
$$;

grant execute on function public.delete_current_user() to authenticated;

-- Prototype policies. These allow the mobile app's public anon key to read/write
-- marketplace data. Replace with Supabase Auth policies before a real launch.
create policy "prototype read listings" on public.listings for select using (true);

create policy "prototype write listings" on public.listings for insert with check (true);

create policy "prototype update listings" on public.listings for update using (true) with check (true);

create policy "prototype delete listings" on public.listings for delete using (true);

create policy "prototype read saved listings" on public.saved_listings for select using (true);

create policy "prototype write saved listings" on public.saved_listings for insert with check (true);

create policy "prototype delete saved listings" on public.saved_listings for delete using (true);

create policy "prototype read reports" on public.listing_reports for select using (true);

create policy "prototype write reports" on public.listing_reports for insert with check (true);

create policy "prototype update reports" on public.listing_reports for update using (true) with check (true);

create policy "prototype read conversations" on public.conversations for select using (true);

create policy "prototype write conversations" on public.conversations for insert with check (true);

create policy "prototype update conversations" on public.conversations for update using (true) with check (true);

create policy "prototype read messages" on public.messages for select using (true);

create policy "prototype write messages" on public.messages for insert with check (true);
