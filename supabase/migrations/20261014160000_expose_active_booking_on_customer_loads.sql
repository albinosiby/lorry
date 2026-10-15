-- Customer My Loads needs the accepted booking identifier in order to open the
-- protected live-tracking screen for an active trip. Keep the existing API and
-- authorization contract intact; this only adds a scalar booking_id field to
-- each customer-owned load returned by loads.list.
do $$
declare
  function_definition text;
  old_projection constant text := $sql$select ld.*, (select count(*) from public.bookings bk where bk.load_id=ld.id and bk.status='requested' and ld.shipper_id=uid) as request_count$sql$;
  new_projection constant text := $sql$select ld.*,
       (select bk.id from public.bookings bk
          where bk.load_id = ld.id
            and bk.status in ('accepted', 'in_transit', 'completed')
          order by bk.updated_at desc, bk.id desc
          limit 1) as booking_id,
       (select count(*) from public.bookings bk where bk.load_id=ld.id and bk.status='requested' and ld.shipper_id=uid) as request_count$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, chr(13), '');
  if position(old_projection in function_definition) = 0 then
    raise exception 'Could not upgrade loads.list with the active booking id.';
  end if;
  execute replace(function_definition, old_projection, new_projection);
end;
$$;
