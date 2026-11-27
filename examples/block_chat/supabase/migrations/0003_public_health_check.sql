-- Block Chat 0003: safe, anonymous deployment health check.
-- This function has no arguments, reads no tables, and reveals no user data.
-- The mobile application's protected operations remain authenticated + RLS gated.
create or replace function public.block_chat_health()
returns text language sql stable security invoker set search_path = ''
as $$
  select 'block-chat-v3'::text;
$$;

revoke all on function public.block_chat_health() from public,anon,authenticated;
grant execute on function public.block_chat_health() to anon,authenticated;
