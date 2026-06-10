-- ============================================
-- IJWI DATABASE SCHEMA
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================
-- PROFILES TABLE
-- ============================================
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  voice_name text not null unique,
  is_revealed boolean default false,
  real_name text,
  avatar_url text,
  flame_pattern text,
  level text default 'seeker' check (level in ('seeker','believer','voice','flame','prophet','pillar')),
  xp integer default 0,
  streak integer default 0,
  last_active_date date,
  bio text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- POSTS TABLE
-- ============================================
create table public.posts (
  id uuid default uuid_generate_v4() primary key,
  author_id uuid references public.profiles(id) on delete cascade not null,
  content_type text not null check (content_type in (
    'story','devotional','spoken_word','short',
    'prayer_request','question','encouragement','letter'
  )),
  title text,
  body text not null,
  is_anonymous boolean default false,
  verse_reference text,
  verse_text text,
  tags text[] default '{}',
  audio_url text,
  video_url text,
  -- reaction counts (denormalized for performance)
  reaction_fire integer default 0,
  reaction_amen integer default 0,
  reaction_healed integer default 0,
  reaction_needed integer default 0,
  reaction_sharing integer default 0,
  comment_count integer default 0,
  prayer_count integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- REACTIONS TABLE
-- ============================================
create table public.reactions (
  id uuid default uuid_generate_v4() primary key,
  post_id uuid references public.posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  reaction_type text not null check (reaction_type in ('fire','amen','healed','needed','sharing')),
  created_at timestamptz default now(),
  unique(post_id, user_id, reaction_type)
);

-- ============================================
-- COMMENTS TABLE
-- ============================================
create table public.comments (
  id uuid default uuid_generate_v4() primary key,
  post_id uuid references public.posts(id) on delete cascade not null,
  author_id uuid references public.profiles(id) on delete cascade not null,
  body text not null,
  is_anonymous boolean default false,
  parent_id uuid references public.comments(id) on delete cascade,
  reaction_amen integer default 0,
  reaction_fire integer default 0,
  created_at timestamptz default now()
);

-- ============================================
-- FOLLOWS TABLE
-- ============================================
create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade,
  following_id uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, following_id)
);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.reactions enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;

-- Profiles: anyone can read, only owner can update
create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Posts: anyone can read, authenticated users can insert/update their own
create policy "posts_select" on public.posts for select using (true);
create policy "posts_insert" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_update" on public.posts for update using (auth.uid() = author_id);
create policy "posts_delete" on public.posts for delete using (auth.uid() = author_id);

-- Reactions: anyone can read, auth users manage their own
create policy "reactions_select" on public.reactions for select using (true);
create policy "reactions_insert" on public.reactions for insert with check (auth.uid() = user_id);
create policy "reactions_delete" on public.reactions for delete using (auth.uid() = user_id);

-- Comments: anyone can read, auth users manage their own
create policy "comments_select" on public.comments for select using (true);
create policy "comments_insert" on public.comments for insert with check (auth.uid() = author_id);
create policy "comments_delete" on public.comments for delete using (auth.uid() = author_id);

-- Follows: anyone can read, auth users manage their own
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, voice_name, flame_pattern)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'voice_name', 'Voice ' || substr(new.id::text, 1, 6)),
    new.raw_user_meta_data->>'flame_pattern'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Update reaction counts when reactions are added/removed
create or replace function public.update_reaction_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    execute format('update public.posts set reaction_%s = reaction_%s + 1 where id = $1', new.reaction_type, new.reaction_type) using new.post_id;
  elsif TG_OP = 'DELETE' then
    execute format('update public.posts set reaction_%s = reaction_%s - 1 where id = $1', old.reaction_type, old.reaction_type) using old.post_id;
  end if;
  return coalesce(new, old);
end;
$$ language plpgsql security definer;

create trigger on_reaction_change
  after insert or delete on public.reactions
  for each row execute procedure public.update_reaction_count();

-- Update comment count
create or replace function public.update_comment_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set comment_count = comment_count - 1 where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$$ language plpgsql security definer;

create trigger on_comment_change
  after insert or delete on public.comments
  for each row execute procedure public.update_comment_count();

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
create index posts_author_id_idx on public.posts(author_id);
create index posts_content_type_idx on public.posts(content_type);
create index posts_created_at_idx on public.posts(created_at desc);
create index reactions_post_id_idx on public.reactions(post_id);
create index reactions_user_id_idx on public.reactions(user_id);
create index comments_post_id_idx on public.comments(post_id);
