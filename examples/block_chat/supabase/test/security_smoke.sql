-- PostgreSQL 16 + pgcrypto fixture to verify migration parses and RLS is enforced.
-- Execute using: psql -v ON_ERROR_STOP=1 -f examples/block_chat/supabase/test/security_smoke.sql
create schema auth;
create table auth.users (
  id uuid primary key,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
create role anon nologin;
create role authenticated nologin;
grant usage on schema public,auth to authenticated;
grant execute on function auth.uid() to authenticated;
create publication supabase_realtime;

\i examples/block_chat/supabase/migrations/0001_private_blocks.sql

insert into auth.users (id,raw_user_meta_data) values
('11111111-1111-4111-8111-111111111111','{"display_name":"Alex"}'),
('22222222-2222-4222-8222-222222222222','{"display_name":"Jordan"}'),
('33333333-3333-4333-8333-333333333333','{"display_name":"Casey"}');

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.create_block('Willow Street') as block_uuid \gset
select set_config('test.block_uuid',:'block_uuid',false);
select public.make_block_invite(current_setting('test.block_uuid')::uuid) as invite_code \gset
select set_config('test.invite_code',:'invite_code',false);

-- A separate authenticated person cannot see or join a private Block by ID.
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$
begin
  if (select count(*) from public.blocks) != 0 then
    raise exception 'Cross-Block name disclosure';
  end if;
  if (select count(*) from public.block_messages) != 0 then
    raise exception 'Cross-Block message disclosure';
  end if;
end $$;

-- Redeeming is not membership: until approved, no message posting.
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.redeem_block_invite(current_setting('test.invite_code')) as requested_block;
do $$
declare denied boolean:=false;
begin
  begin
    insert into public.block_messages(block_id,sender_id,channel,body)
    values(current_setting('test.block_uuid')::uuid,auth.uid(),'general','Before approval');
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Pending user posted a message'; end if;
end $$;
do $$
begin
  if (select count(*) from public.block_messages) != 0 then
    raise exception 'Pending member read messages';
  end if;
end $$;

-- Invitation codes cannot be replayed.
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$
declare denied boolean:=false;
begin
  begin
    perform public.redeem_block_invite(current_setting('test.invite_code'));
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Invitation replayed'; end if;
end $$;

-- Admin approves one member; they can then post into General, not Notices.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.review_block_member(
  current_setting('test.block_uuid')::uuid,
  '22222222-2222-4222-8222-222222222222'::uuid,true);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
insert into public.block_messages(block_id,sender_id,channel,body) values (
  current_setting('test.block_uuid')::uuid,auth.uid(),'general','Hello from Jordan');
do $$
declare denied boolean:=false;
begin
  begin
    insert into public.block_messages(block_id,sender_id,channel,body) values (
      current_setting('test.block_uuid')::uuid,auth.uid(),'announcements','Not an admin');
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Non-admin posted an announcement'; end if;
end $$;

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$
begin
  if (select count(*) from public.block_messages) != 0 then
    raise exception 'Cross-Block message leakage after posting';
  end if;
end $$;

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
do $$
declare message_id bigint;
begin
  select id into message_id from public.block_messages limit 1;
  if message_id is null then raise exception 'Approved messages not visible'; end if;
  perform public.report_block_message(message_id,'Spam');
end $$;
do $$
declare report_id bigint;
begin
  select id into report_id from public.block_reports limit 1;
  if report_id is null then raise exception 'Message report missing'; end if;
  perform public.moderate_block_report(report_id,true);
  if not exists (select 1 from public.block_messages
      where redacted_at is not null and body='Message removed by moderator') then
    raise exception 'Moderation did not redact the message';
  end if;
end $$;

-- Removing membership denies subsequent query access.
select public.remove_block_member(
  current_setting('test.block_uuid')::uuid,
  '22222222-2222-4222-8222-222222222222'::uuid);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$
begin
  if (select count(*) from public.block_messages) != 0 then
    raise exception 'Removed user can still read messages';
  end if;
end $$;
reset role;
select 'Block Chat authentication, invites, approval, RLS, reports and removal passed' as result;
