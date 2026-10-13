-- Event history is intentionally exposed only through the party-scoped RPC.
create policy events_via_command_api on public.booking_events for select to authenticated using (false);
-- New Supabase projects may include this DDL event trigger. It must not be an RPC.
do $$ begin
 if to_regprocedure('public.rls_auto_enable()') is not null then
  revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
 end if;
end $$;
create index booking_events_actor_idx on public.booking_events(actor_id);
create index notifications_load_idx on public.notifications(load_id);
create index notifications_booking_idx on public.notifications(booking_id);
