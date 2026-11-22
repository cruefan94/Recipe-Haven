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
\i examples/block_chat/supabase/migrations/0002_member_control_and_invites.sql

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
  select r.report_id into report_id from public.pending_block_reports(current_setting('test.block_uuid')::uuid) r limit 1;
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

-- Version 0002: Block admins control invitations; non-admins cannot list or revoke.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.make_block_invite(current_setting('test.block_uuid')::uuid) as invite_two \gset
select set_config('test.invite_two',:'invite_two',false);
do $
begin
  if (select count(*) from public.active_block_invites(current_setting('test.block_uuid')::uuid)) <> 1 then
    raise exception 'Active invite must be visible to admin';
  end if;
end $;
select invite_id as invite_two_id from
  public.active_block_invites(current_setting('test.block_uuid')::uuid) limit 1 \gset
select set_config('test.invite_two_id',:'invite_two_id',false);
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $
declare denied boolean:=false;
begin
  begin
    perform public.active_block_invites(current_setting('test.block_uuid')::uuid);
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Non-admin listed active invites'; end if;
end $;
do $
declare denied boolean:=false;
begin
  begin
    perform public.revoke_block_invite(current_setting('test.invite_two_id')::uuid);
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Non-admin revoked an invite'; end if;
end $;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.revoke_block_invite(current_setting('test.invite_two_id')::uuid);
do $
begin
  if (select count(*) from public.active_block_invites(current_setting('test.block_uuid')::uuid)) <> 0 then
    raise exception 'Revoked invitation still active';
  end if;
end $;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $
declare denied boolean:=false;
begin
  begin
    perform public.redeem_block_invite(current_setting('test.invite_two'));
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Revoked invitation was redeemed'; end if;
end $;

-- Pending applicants can cancel their request, and approved members can leave.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.make_block_invite(current_setting('test.block_uuid')::uuid) as invite_three \gset
select set_config('test.invite_three',:'invite_three',false);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.redeem_block_invite(current_setting('test.invite_three'));
select public.leave_block(current_setting('test.block_uuid')::uuid);
do $
begin
  if (select count(*) from public.blocks) <> 0 then
    raise exception 'Cancelled applicant can still see the Block';
  end if;
end $;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.make_block_invite(current_setting('test.block_uuid')::uuid) as invite_four \gset
select set_config('test.invite_four',:'invite_four',false);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.redeem_block_invite(current_setting('test.invite_four'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.review_block_member(current_setting('test.block_uuid')::uuid,
  '22222222-2222-4222-8222-222222222222'::uuid,true);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select public.leave_block(current_setting('test.block_uuid')::uuid);
do $
begin
  if public.is_block_member(current_setting('test.block_uuid')::uuid) then
    raise exception 'Former member retained membership';
  end if;
end $;

-- Founders cannot accidentally abandon their Block.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
do $
declare denied boolean:=false;
begin
  begin
    perform public.leave_block(current_setting('test.block_uuid')::uuid);
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Founder unexpectedly left their Block'; end if;
end $;

-- Messages can be redacted by their original approved sender, not outsiders.
insert into public.block_messages(block_id,sender_id,channel,body) values (
  current_setting('test.block_uuid')::uuid,auth.uid(),'general','This is an example');
select id as own_message_id from public.block_messages
  where sender_id=auth.uid() and body='This is an example' order by id desc limit 1 \gset
select set_config('test.own_message_id',:'own_message_id',false);
select public.delete_own_block_message(current_setting('test.own_message_id')::bigint);
do $
begin
  if not exists (select 1 from public.block_messages
      where id=current_setting('test.own_message_id')::bigint
        and redacted_at is not null and body='Message removed by sender') then
    raise exception 'Message redaction failed';
  end if;
end $;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $
declare denied boolean:=false;
begin
  begin
    perform public.delete_own_block_message(current_setting('test.own_message_id')::bigint);
  exception when others then denied:=true;
  end;
  if not denied then raise exception 'Outsider redacted another member message'; end if;
end $;

reset role;
select 'Block Chat authentication, invites, approval, RLS, reports and removal passed' as result;
