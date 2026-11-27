-- Block Chat 0001: independent, invitation-only neighbourhood communities.
-- Apply only to a new, dedicated Supabase project, not Recipe Haven's database.
-- Source controlled migration; never put a service_role key in an Android APK.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.block_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  created_at timestamptz not null default now()
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 3 and 60),
  created_at timestamptz not null default now()
);

create table public.block_memberships (
  block_id uuid not null references public.blocks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'pending' check (status in ('pending','approved','rejected','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (block_id,user_id)
);
create index block_memberships_user_idx on public.block_memberships(user_id,status);

create table public.block_invites (
  id uuid primary key default gen_random_uuid(),
  block_id uuid not null references public.blocks(id) on delete cascade,
  code_hash bytea not null unique,
  invited_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users(id)
);
create index block_invites_limit_idx on public.block_invites(invited_by,expires_at);

create table public.block_messages (
  id bigint generated always as identity primary key,
  block_id uuid not null references public.blocks(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_label text not null default 'Neighbour',
  channel text not null check (channel in ('general','announcements','help','events')),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  redacted_at timestamptz
);
create index block_messages_recent_idx on public.block_messages(block_id,channel,created_at desc);

create table public.block_reports (
  id bigint generated always as identity primary key,
  block_id uuid not null references public.blocks(id) on delete cascade,
  message_id bigint not null references public.block_messages(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 250),
  message_excerpt text not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique(message_id, reporter_id)
);

-- Profiles are created from the supplied nickname, never expose email addresses.
create or replace function public.block_after_signup()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_name text;
begin
  v_name := left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'Neighbour'), 60);
  if char_length(v_name) < 2 then v_name := 'Neighbour'; end if;
  insert into public.block_profiles(user_id,display_name) values (new.id,v_name);
  return new;
end $$;
create trigger block_user_created after insert on auth.users
for each row execute function public.block_after_signup();

create or replace function public.is_block_member(p_block uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.block_memberships
    where block_id=p_block and user_id=(select auth.uid()) and status='approved');
$$;

create or replace function public.is_block_admin(p_block uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.block_memberships
    where block_id=p_block and user_id=(select auth.uid())
      and status='approved' and role in ('owner','admin'));
$$;

-- All tables have explicit deny-by-default RLS.
alter table public.block_profiles enable row level security;
alter table public.blocks enable row level security;
alter table public.block_memberships enable row level security;
alter table public.block_invites enable row level security;
alter table public.block_messages enable row level security;
alter table public.block_reports enable row level security;

create policy profile_self_read on public.block_profiles for select to authenticated
using (user_id = (select auth.uid()));
create policy profile_self_update on public.block_profiles for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy member_self_read on public.block_memberships for select to authenticated
using (user_id = (select auth.uid()));

create policy block_invited_or_approved_read on public.blocks for select to authenticated
using (exists(select 1 from public.block_memberships m
  where m.block_id=blocks.id and m.user_id=(select auth.uid())
    and m.status in ('pending','approved')));

create policy block_message_read on public.block_messages for select to authenticated
using (public.is_block_member(block_id));
create policy block_message_post on public.block_messages for insert to authenticated
with check (
  sender_id=(select auth.uid()) and public.is_block_member(block_id)
  and (channel <> 'announcements' or public.is_block_admin(block_id))
);

-- Supabase's default table grants should not allow direct mutation of protected state.
revoke all on public.block_profiles,public.blocks,public.block_memberships,
  public.block_invites,public.block_messages,public.block_reports from anon,authenticated;
grant select on public.block_profiles,public.blocks,public.block_memberships,
  public.block_messages to authenticated;
grant update(display_name) on public.block_profiles to authenticated;
grant insert on public.block_messages to authenticated;
grant usage, select on sequence public.block_messages_id_seq to authenticated;

create or replace function public.block_before_message()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  -- Do not let a client forge timestamps, sender name or retained moderation state.
  new.created_at := now();
  new.redacted_at := null;
  select display_name into new.sender_label from public.block_profiles
    where user_id = new.sender_id;
  if new.sender_label is null then new.sender_label := 'Neighbour'; end if;
  if exists(select 1 from public.block_messages
     where sender_id=new.sender_id and block_id=new.block_id
       and created_at > now() - interval '1 second') then
    raise exception 'Please wait briefly before sending another message';
  end if;
  return new;
end $$;
create trigger block_message_insert_guard before insert on public.block_messages
for each row execute function public.block_before_message();

create or replace function public.create_block(p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_name text := btrim(p_name);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_name is null or char_length(v_name) not between 3 and 60 then
    raise exception 'Enter a Block name between 3 and 60 characters';
  end if;
  if (select count(*) from public.block_memberships
      where user_id=v_user and role='owner' and status='approved') >= 5 then
    raise exception 'Maximum of five Blocks per founder';
  end if;
  insert into public.blocks(name) values(v_name) returning id into v_id;
  insert into public.block_memberships(block_id,user_id,role,status)
    values(v_id,v_user,'owner','approved');
  return v_id;
end $$;

-- A 160-bit single-use secret. Only the SHA-256 digest is stored.
create or replace function public.make_block_invite(p_block uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := (select auth.uid()); v_token text;
begin
  if v_user is null or not public.is_block_admin(p_block) then
    raise exception 'Only Block administrators may invite residents';
  end if;
  if (select count(*) from public.block_invites
      where invited_by=v_user and expires_at>now() and redeemed_at is null) >= 12 then
    raise exception 'Too many active invitations';
  end if;
  v_token := encode(extensions.gen_random_bytes(20),'hex');
  insert into public.block_invites(block_id,code_hash,invited_by,expires_at)
    values(p_block,extensions.digest(v_token,'sha256'),v_user,now()+interval '48 hours');
  return v_token;
end $$;

create or replace function public.redeem_block_invite(p_code text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := (select auth.uid());
  v_inv public.block_invites%rowtype;
  v_current text;
  v_code text := lower(btrim(coalesce(p_code,'')));
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_code !~ '^[a-f0-9]{40}$' then raise exception 'Invalid invitation'; end if;
  select * into v_inv from public.block_invites
     where code_hash=extensions.digest(v_code,'sha256') for update;
  if not found or v_inv.expires_at <= now() or v_inv.redeemed_at is not null then
    raise exception 'This invitation has expired or is unavailable';
  end if;
  select status into v_current from public.block_memberships
    where block_id=v_inv.block_id and user_id=v_user;
  if v_current in ('approved','pending') then
    raise exception 'You already belong to this Block or are awaiting approval';
  end if;
  insert into public.block_memberships(block_id,user_id,role,status)
    values(v_inv.block_id,v_user,'member','pending')
    on conflict (block_id,user_id) do update
      set role='member',status='pending',updated_at=now();
  update public.block_invites set redeemed_at=now(),redeemed_by=v_user
    where id=v_inv.id;
  return v_inv.block_id;
end $$;

create or replace function public.pending_block_members(p_block uuid)
returns table(user_id uuid,display_name text,requested_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_block_admin(p_block) then raise exception 'Access denied'; end if;
  return query select m.user_id,p.display_name,m.created_at
    from public.block_memberships m
    join public.block_profiles p on p.user_id=m.user_id
    where m.block_id=p_block and m.status='pending'
    order by m.created_at asc;
end $$;

create or replace function public.review_block_member(p_block uuid,p_user uuid,p_approve boolean)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_block_admin(p_block) then raise exception 'Access denied'; end if;
  update public.block_memberships
    set status=case when p_approve then 'approved' else 'rejected' end,
        updated_at=now()
    where block_id=p_block and user_id=p_user and status='pending' and role='member';
  if not found then raise exception 'Pending member not found'; end if;
end $$;

create or replace function public.approved_block_members(p_block uuid)
returns table(user_id uuid,display_name text,role text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_block_member(p_block) then raise exception 'Access denied'; end if;
  return query select m.user_id,p.display_name,m.role
    from public.block_memberships m
    join public.block_profiles p on p.user_id=m.user_id
    where m.block_id=p_block and m.status='approved'
    order by m.role desc,p.display_name;
end $$;

create or replace function public.remove_block_member(p_block uuid,p_user uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_block_admin(p_block) then raise exception 'Access denied'; end if;
  update public.block_memberships set status='removed',updated_at=now()
    where block_id=p_block and user_id=p_user and role='member'
      and status='approved';
  if not found then raise exception 'Cannot remove this member'; end if;
end $$;

create or replace function public.report_block_message(p_message bigint,p_reason text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_message public.block_messages%rowtype; v_reason text := btrim(coalesce(p_reason,''));
begin
  select * into v_message from public.block_messages where id=p_message;
  if not found or not public.is_block_member(v_message.block_id) then
    raise exception 'Access denied';
  end if;
  if char_length(v_reason) not between 3 and 250 then raise exception 'Enter a report reason'; end if;
  insert into public.block_reports(block_id,message_id,reporter_id,reason,message_excerpt)
    values(v_message.block_id,p_message,(select auth.uid()),v_reason,left(v_message.body,500))
    on conflict (message_id,reporter_id) do nothing;
end $$;

create or replace function public.pending_block_reports(p_block uuid)
returns table(report_id bigint,message_id bigint,reason text,message_excerpt text,reported_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_block_admin(p_block) then raise exception 'Access denied'; end if;
  return query select r.id,r.message_id,r.reason,r.message_excerpt,r.created_at
    from public.block_reports r where r.block_id=p_block and r.resolved_at is null
    order by r.created_at;
end $$;

create or replace function public.moderate_block_report(p_report bigint,p_remove_message boolean)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_report public.block_reports%rowtype;
begin
  select * into v_report from public.block_reports where id=p_report for update;
  if not found or not public.is_block_admin(v_report.block_id) then
    raise exception 'Access denied';
  end if;
  if p_remove_message then
    update public.block_messages set body='Message removed by moderator',
      redacted_at=now() where id=v_report.message_id;
  end if;
  update public.block_reports set resolved_at=now() where id=p_report;
end $$;

-- Restrict service operations to authenticated sessions, never anonymous users.
revoke all on function public.block_after_signup() from public,anon,authenticated;
revoke all on function public.block_before_message() from public,anon,authenticated;
revoke all on function public.is_block_member(uuid) from public,anon;
revoke all on function public.is_block_admin(uuid) from public,anon;
grant execute on function public.is_block_member(uuid),public.is_block_admin(uuid) to authenticated;
revoke all on function public.create_block(text),public.make_block_invite(uuid),
 public.redeem_block_invite(text),public.pending_block_members(uuid),
 public.review_block_member(uuid,uuid,boolean),public.approved_block_members(uuid),
 public.remove_block_member(uuid,uuid),public.report_block_message(bigint,text),
 public.pending_block_reports(uuid),public.moderate_block_report(bigint,boolean)
 from public,anon;
grant execute on function public.create_block(text),public.make_block_invite(uuid),
 public.redeem_block_invite(text),public.pending_block_members(uuid),
 public.review_block_member(uuid,uuid,boolean),public.approved_block_members(uuid),
 public.remove_block_member(uuid,uuid),public.report_block_message(bigint,text),
 public.pending_block_reports(uuid),public.moderate_block_report(bigint,boolean)
 to authenticated;

-- Realtime Postgres changes are filtered by block_message_read RLS.
do $$
begin
  alter publication supabase_realtime add table public.block_messages;
exception when duplicate_object then null;
end $$;

-- During deployment, validate RLS with two different test accounts and Blocks.
