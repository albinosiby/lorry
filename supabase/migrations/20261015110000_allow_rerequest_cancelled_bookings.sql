-- Allow drivers to re-request an open load if their previous booking was cancelled or declined.
-- Also ensure loads.get only returns an active booking_id for drivers, so cancelled requests do not lock them out.

do $$
declare
  function_definition text;
  old_get_target constant text := 'or driver_id=uid) limit 1;';
  new_get_target constant text := 'or (driver_id=uid and status in (''requested'',''accepted'',''in_transit'',''completed''))) limit 1;';

  old_check_booking constant text := 'if b.id is not null then return to_jsonb(b); end if;';
  new_check_booking constant text := 'if b.id is not null and b.status in (''requested'',''accepted'',''in_transit'',''completed'') then return to_jsonb(b); end if;';

  old_insert_booking constant text := $sql$insert into public.bookings(load_id,driver_id) values(l.id,uid) returning * into b;
   insert into public.booking_events(booking_id,actor_id,status) values(b.id,uid,'requested');$sql$;

  new_insert_booking constant text := $sql$if b.id is not null then
     update public.bookings set status='requested',reason=null,source='driver_request',delivery_reported_at=null,updated_at=now() where id=b.id returning * into b;
     insert into public.booking_events(booking_id,actor_id,status,note) values(b.id,uid,'requested','Request re-submitted');
   else
     insert into public.bookings(load_id,driver_id) values(l.id,uid) returning * into b;
     insert into public.booking_events(booking_id,actor_id,status) values(b.id,uid,'requested');
   end if;$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;

  if position(old_get_target in function_definition) > 0 then
    function_definition := replace(function_definition, old_get_target, new_get_target);
  end if;

  if position(old_check_booking in function_definition) > 0 then
    function_definition := replace(function_definition, old_check_booking, new_check_booking);
  end if;

  if position(old_insert_booking in function_definition) > 0 then
    function_definition := replace(function_definition, old_insert_booking, new_insert_booking);
  end if;

  execute function_definition;
  raise notice 'Successfully applied booking re-request upgrade!';
end;
$$;
