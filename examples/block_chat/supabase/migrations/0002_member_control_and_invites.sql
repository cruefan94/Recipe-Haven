-- Block Chat 0002: member self-service and invitation safety.
-- Apply after 0001_private_blocks.sql in the DEDICATED Block Chat database.
-- The mobile client must not be able to mutate memberships or invitations directly.

-- Let pending applicants cancel their request, and approved non-owners leave.
-- The founder/owner must retain ownership until a future secure ownership-transfer
-- or Block-deletion workflow exists.
create or replace function public.leave_block(p_block uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  update public.block_memberships
    set status='removed', updated_at=now()
    where block_id=p_block and user_id=(select auth.uid())
      and status in ('approved','pending') and role <> 'owner';
  if not found then
    raise exception 'No leaveable membership. Block founders cannot leave yet';
  end if;
end $$;

-- Administrators see metadata only, never the secret or hashed invite code.
-- Tokens can be shared only by the administrator who generated them.
create or replace function public.active_block_invites(p_block uuid)
returns table(invite_id uuid, issued_at timestamptz, expires_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_block_admin(p_block) then raise exception 'Access denied'; end if;
  return query
    select i.id,i.created_at,i.expires_at
    from public.block_invites i
    where i.block_id=p_block and i.redeemed_at is null and i.expires_at>now()
    order by i.created_at desc;
end $$;

-- Revocation invalidates the token immediately while retaining the audit row.
create or replace function public.revoke_block_invite(p_invite uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_block uuid;
begin
  select i.block_id into v_block
    from public.block_invites i where i.id=p_invite for update;
  if v_block is null or not public.is_block_admin(v_block) then
    raise exception 'Access denied';
  end if;
  update public.block_invites
    set expires_at=now()
    where id=p_invite and redeemed_at is null and expires_at>now();
  if not found then raise exception 'Invitation is no longer active'; end if;
end $$;

-- Deleting a message means redaction for other members, NOT cryptographic erasure.
-- Reports, existing screenshots, and backups may retain copies.
create or replace function public.delete_own_block_message(p_message bigint)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_message public.block_messages%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into v_message from public.block_messages
    where id=p_message for update;
  if not found
    or v_message.sender_id <> (select auth.uid())
    or not public.is_block_member(v_message.block_id) then
    raise exception 'Access denied';
  end if;
  if v_message.redacted_at is not null then
    raise exception 'Message is already removed';
  end if;
  update public.block_messages
    set body='Message removed by sender', redacted_at=now()
    where id=p_message;
end $$;

revoke all on function public.leave_block(uuid),
  public.active_block_invites(uuid), public.revoke_block_invite(uuid),
  public.delete_own_block_message(bigint) from public,anon;
grant execute on function public.leave_block(uuid),
  public.active_block_invites(uuid), public.revoke_block_invite(uuid),
  public.delete_own_block_message(bigint) to authenticated;
