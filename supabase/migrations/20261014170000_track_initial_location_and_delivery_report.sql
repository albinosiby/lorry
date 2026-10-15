-- Make the first GPS point atomic with starting a trip, and expose a
-- driver's delivery report on customer-facing load responses.
do $$
declare
  function_definition text;
  old_start constant text := $sql$     update public.loads set status='in_transit',updated_at=now() where id=l.id;$sql$;
  new_start constant text := $sql$     if nullif(payload->>'latitude', '') is null
        or nullif(payload->>'longitude', '') is null then
       raise exception 'A current GPS location is required to start a trip.';
     end if;
     if (payload->>'latitude')::numeric not between -90 and 90
        or (payload->>'longitude')::numeric not between -180 and 180 then
       raise exception 'Invalid trip location.';
     end if;
     update public.loads set status='in_transit',updated_at=now() where id=l.id;
     insert into public.active_trip_locations(
       booking_id, driver_id, latitude, longitude, recorded_at
     ) values (
       b.id, uid, (payload->>'latitude')::numeric,
       (payload->>'longitude')::numeric, now()
     ) on conflict (booking_id) do update set
       latitude = excluded.latitude,
       longitude = excluded.longitude,
       recorded_at = excluded.recorded_at,
       received_at = now();$sql$;
  old_list constant text := $sql$       (select bk.id from public.bookings bk
          where bk.load_id = ld.id
            and bk.status in ('accepted', 'in_transit', 'completed')
          order by bk.updated_at desc, bk.id desc
          limit 1) as booking_id,
       (select count(*) from public.bookings bk where bk.load_id=ld.id and bk.status='requested' and ld.shipper_id=uid) as request_count$sql$;
  new_list constant text := $sql$       (select bk.id from public.bookings bk
          where bk.load_id = ld.id
            and bk.status in ('accepted', 'in_transit', 'completed')
          order by bk.updated_at desc, bk.id desc
          limit 1) as booking_id,
       (select bk.delivery_reported_at from public.bookings bk
          where bk.load_id = ld.id
            and bk.status in ('accepted', 'in_transit', 'completed')
          order by bk.updated_at desc, bk.id desc
          limit 1) as delivery_reported_at,
       (select count(*) from public.bookings bk where bk.load_id=ld.id and bk.status='requested' and ld.shipper_id=uid) as request_count$sql$;
  old_get constant text := $sql$'booking_id',target,'owner_name',$sql$;
  new_get constant text := $sql$'booking_id',target,'delivery_reported_at',(select delivery_reported_at from public.bookings where id=target),'owner_name',$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position(old_start in function_definition) = 0
      or position(old_list in function_definition) = 0
      or position(old_get in function_definition) = 0 then
    raise exception 'Could not upgrade LORRY LINK trip tracking and delivery status commands.';
  end if;
  function_definition := replace(function_definition, old_start, new_start);
  function_definition := replace(function_definition, old_list, new_list);
  function_definition := replace(function_definition, old_get, new_get);
  execute function_definition;
end;
$$;
