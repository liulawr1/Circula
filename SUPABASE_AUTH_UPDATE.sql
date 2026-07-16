-- Circula Supabase Auth update
-- Run this once in Supabase Dashboard > SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

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
