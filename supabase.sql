-- ============ Suivi Muscu : base de données ============
-- Colle tout ce fichier dans Supabase > SQL Editor > New query, puis clique sur Run.

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  pseudo text not null check (char_length(pseudo) between 2 and 20),
  created_at timestamptz default now()
);
create table if not exists public.user_meta (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz default now()
);
create table if not exists public.sessions (
  id text primary key,
  user_id uuid not null references auth.users on delete cascade,
  data jsonb not null,
  date timestamptz not null default now()
);
create index if not exists sessions_user_idx on public.sessions(user_id);
create table if not exists public.nutrition_days (
  user_id uuid not null references auth.users on delete cascade,
  day text not null,
  items jsonb not null default '[]',
  primary key (user_id, day)
);
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 30),
  code text unique not null,
  owner uuid not null references auth.users on delete cascade,
  created_at timestamptz default now()
);
create table if not exists public.group_members (
  group_id uuid references public.groups on delete cascade,
  user_id uuid references auth.users on delete cascade,
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);
create table if not exists public.public_stats (
  user_id uuid primary key references auth.users on delete cascade,
  pseudo text,
  level int default 1,
  xp_total int default 0,
  xp_week int default 0,
  week_key text,
  gauge_pts int default 0,
  gauge_day text,
  global_step int default -1,
  ranks jsonb default '{}',
  sessions_30 int default 0,
  streak int default 0,
  rank_theme text,
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.user_meta enable row level security;
alter table public.sessions enable row level security;
alter table public.nutrition_days enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.public_stats enable row level security;

-- Est-ce que cet utilisateur est dans un de mes groupes ?
create or replace function public.shares_group(other uuid) returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from group_members a join group_members b on a.group_id = b.group_id
                 where a.user_id = auth.uid() and b.user_id = other);
$$;
create or replace function public.is_member(g uuid) returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from group_members where group_id = g and user_id = auth.uid());
$$;

-- Données privées : chacun ne voit et ne modifie que les siennes
create policy "own meta" on public.user_meta for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own sessions" on public.sessions for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own days" on public.nutrition_days for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Profils et stats : visibles par soi-même et par les membres de ses groupes
create policy "read profiles" on public.profiles for select using (id = auth.uid() or public.shares_group(id));
create policy "insert own profile" on public.profiles for insert with check (id = auth.uid());
create policy "update own profile" on public.profiles for update using (id = auth.uid());
create policy "read stats" on public.public_stats for select using (user_id = auth.uid() or public.shares_group(user_id));
create policy "insert own stats" on public.public_stats for insert with check (user_id = auth.uid());
create policy "update own stats" on public.public_stats for update using (user_id = auth.uid());

-- Groupes : visibles par leurs membres
create policy "read groups" on public.groups for select using (public.is_member(id) or owner = auth.uid());
create policy "delete own groups" on public.groups for delete using (owner = auth.uid());
create policy "read members" on public.group_members for select using (public.is_member(group_id));
create policy "leave group" on public.group_members for delete using (user_id = auth.uid());

-- Créer un groupe (avec un code d'invitation) et rejoindre un groupe par code
create or replace function public.create_group(gname text) returns json
language plpgsql security definer set search_path = public as $$
declare g public.groups; c text;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  loop
    c := upper(substr(md5(random()::text), 1, 6));
    exit when not exists (select 1 from public.groups where code = c);
  end loop;
  insert into public.groups(name, code, owner) values (gname, c, auth.uid()) returning * into g;
  insert into public.group_members(group_id, user_id) values (g.id, auth.uid());
  return json_build_object('id', g.id, 'name', g.name, 'code', g.code);
end $$;

create or replace function public.join_group(gcode text) returns json
language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  select * into g from public.groups where code = upper(trim(gcode));
  if not found then raise exception 'Code invalide'; end if;
  insert into public.group_members(group_id, user_id) values (g.id, auth.uid()) on conflict do nothing;
  return json_build_object('id', g.id, 'name', g.name, 'code', g.code);
end $$;

grant execute on function public.create_group(text) to authenticated;
grant execute on function public.join_group(text) to authenticated;
grant execute on function public.shares_group(uuid) to authenticated;
grant execute on function public.is_member(uuid) to authenticated;
