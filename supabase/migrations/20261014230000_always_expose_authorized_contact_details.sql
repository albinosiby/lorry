-- Both parties to a marketplace load or booking need a direct contact number.
-- These values are returned only through authenticated commands that already
-- verify access to the load or booking.
do $$
declare
  function_definition text;
  old_load_phone constant text := $sql$'owner_phone',case when l.contact_preference='phone' then (select phone from public.profiles where id=l.shipper_id) else '' end$sql$;
  new_load_phone constant text := $sql$'owner_phone',(select phone from public.profiles where id=l.shipper_id)$sql$;
  old_booking_phone constant text := $sql$'other_phone',case when b.status in ('accepted','in_transit','completed') then (select phone from public.profiles where id=target) else '' end$sql$;
  new_booking_phone constant text := $sql$'other_phone',(select phone from public.profiles where id=target)$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  if position(old_load_phone in function_definition) = 0
      or position(old_booking_phone in function_definition) = 0 then
    raise exception 'Could not update LORRY LINK contact visibility.';
  end if;
  function_definition := replace(function_definition, old_load_phone, new_load_phone);
  function_definition := replace(function_definition, old_booking_phone, new_booking_phone);
  execute function_definition;
end;
$$;
