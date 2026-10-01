-- =============================================
-- CIVICSENSE — Safe / re-runnable schema
-- =============================================

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

alter table public.profiles
  add column if not exists bio text,
  add column if not exists country text,
  add column if not exists city text,
  add column if not exists website text,
  add column if not exists twitter text,
  add column if not exists instagram text,
  add column if not exists linkedin text,
  add column if not exists github text,
  add column if not exists discord text,
  add column if not exists avatar_url text,
  add column if not exists is_business boolean default false;

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles for select using ( true );

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  with check ( auth.uid() = id );

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using ( auth.uid() = id );

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
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create table if not exists public.businesses (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid references auth.users on delete cascade not null,
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

alter table public.businesses
  add column if not exists holding_company text,
  add column if not exists industry text,
  add column if not exists established_date text,
  add column if not exists services text,
  add column if not exists skills text,
  add column if not exists achievements text,
  add column if not exists accent_color text default 'yellow',
  add column if not exists theme text default 'dark',
  add column if not exists profile_layout text default 'bento',
  add column if not exists languages text,
  add column if not exists bluesky text,
  add column if not exists codepen text,
  add column if not exists website text,
  add column if not exists logo_url text;

create unique index if not exists businesses_owner_id_key on public.businesses (owner_id);

alter table public.businesses enable row level security;

drop policy if exists "Businesses are viewable by everyone" on public.businesses;
create policy "Businesses are viewable by everyone"
  on public.businesses for select using ( true );

drop policy if exists "Owner can insert their business" on public.businesses;
create policy "Owner can insert their business"
  on public.businesses for insert
  with check ( auth.uid() = owner_id );

drop policy if exists "Owner can update their business" on public.businesses;
create policy "Owner can update their business"
  on public.businesses for update
  using ( auth.uid() = owner_id );

drop policy if exists "Owner can delete their business" on public.businesses;
create policy "Owner can delete their business"
  on public.businesses for delete
  using ( auth.uid() = owner_id );

create table if not exists public.business_members (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid references public.businesses on delete cascade not null,
  user_id       uuid references auth.users on delete cascade not null,
  role          text default 'member',
  created_at    timestamptz default now(),
  unique (business_id, user_id)
);

alter table public.business_members enable row level security;

drop policy if exists "Members can view their team" on public.business_members;
create policy "Members can view their team"
  on public.business_members for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.businesses b
      where b.id = business_id and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owner can manage members" on public.business_members;
create policy "Owner can manage members"
  on public.business_members for all
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and b.owner_id = auth.uid()
    )
  );

create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users on delete cascade not null,
  body       text not null,
  media_url  text,
  created_at timestamptz default now()
);

alter table public.posts enable row level security;

drop policy if exists "Posts are viewable by everyone" on public.posts;
create policy "Posts are viewable by everyone"
  on public.posts for select using ( true );

drop policy if exists "Users can create their own posts" on public.posts;
create policy "Users can create their own posts"
  on public.posts for insert
  with check ( auth.uid() = user_id );

drop policy if exists "Users can delete their own posts" on public.posts;
create policy "Users can delete their own posts"
  on public.posts for delete
  using ( auth.uid() = user_id );

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Avatar images are publicly accessible" on storage.objects;
create policy "Avatar images are publicly accessible"
  on storage.objects for select
  using ( bucket_id = 'avatars' );
