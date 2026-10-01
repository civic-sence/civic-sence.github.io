-- =============================================
-- CIVICSENSE — Full Supabase Schema
-- Run this in Supabase Dashboard → SQL Editor
-- =============================================

-- 1. PROFILES (extends auth.users)
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  username      text unique,
  first_name    text,
  last_name     text,
  full_name     text,
  bio           text,
  country       text,
  city          text,
  website       text,
  twitter       text,
  instagram     text,
  linkedin      text,
  github        text,
  discord       text,
  avatar_url    text,
  is_business   boolean default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select using ( true );

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update their own profile"
  on public.profiles for update
  using ( auth.uid() = id );

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, first_name, last_name, full_name, is_business)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    new.raw_user_meta_data->>'first_name',
    new.raw_user_meta_data->>'last_name',
    coalesce(
      new.raw_user_meta_data->>'full_name',
      trim(coalesce(new.raw_user_meta_data->>'first_name','') || ' ' || coalesce(new.raw_user_meta_data->>'last_name',''))
    ),
    coalesce((new.raw_user_meta_data->>'is_business')::boolean, false)
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. BUSINESSES
create table if not exists public.businesses (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid references auth.users on delete cascade not null unique,
  name               text not null,
  username           text unique not null,
  email              text,
  logo_url           text,
  website            text,
  description        text,
  holding_company    text,
  industry           text,
  established_date   text,
  services           text,
  skills             text,
  achievements       text,
  accent_color       text default 'yellow',
  theme              text default 'dark',
  profile_layout     text default 'bento',
  languages          text,
  bluesky            text,
  codepen            text,
  is_verified        boolean default false,
  plan               text default 'free',
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);

alter table public.businesses enable row level security;

create policy "Businesses are viewable by everyone"
  on public.businesses for select using ( true );

create policy "Owner can insert their business"
  on public.businesses for insert
  with check ( auth.uid() = owner_id );

create policy "Owner can update their business"
  on public.businesses for update
  using ( auth.uid() = owner_id );

create policy "Owner can delete their business"
  on public.businesses for delete
  using ( auth.uid() = owner_id );

-- 3. BUSINESS MEMBERS (optional teams)
create table if not exists public.business_members (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid references public.businesses on delete cascade not null,
  user_id       uuid references auth.users on delete cascade not null,
  role          text default 'member',
  created_at    timestamptz default now(),
  unique (business_id, user_id)
);

alter table public.business_members enable row level security;

create policy "Members can view their team"
  on public.business_members for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.businesses b
      where b.id = business_id and b.owner_id = auth.uid()
    )
  );

create policy "Owner can manage members"
  on public.business_members for all
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and b.owner_id = auth.uid()
    )
  );

-- 4. POSTS (social feed)
create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users on delete cascade not null,
  body       text not null,
  media_url  text,
  created_at timestamptz default now()
);

alter table public.posts enable row level security;

create policy "Posts are viewable by everyone"
  on public.posts for select using ( true );

create policy "Users can create their own posts"
  on public.posts for insert
  with check ( auth.uid() = user_id );

create policy "Users can delete their own posts"
  on public.posts for delete
  using ( auth.uid() = user_id );

-- 5. STORAGE — avatars bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Avatar images are publicly accessible"
  on storage.objects for select
  using ( bucket_id = 'avatars' );
