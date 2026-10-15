-- Load labels remain human-readable, while map-picked coordinates make route
-- matching and map features precise. Intermediate unloading stops keep their
-- coordinates in the existing JSONB array.
do $$
declare
  function_definition text;
  old_insert constant text := $sql$insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,contact_preference,weight_tonnes,required_vehicle_length_ft,pickup_at,special_note,unload_stops)
     values((payload->>'id')::uuid,uid,payload->>'pickup',payload->>'destination',trim(payload->>'cargo'),payload->>'vehicle',(payload->>'pickup_date')::date,(payload->>'price')::numeric,coalesce(payload->>'contact_preference','after_acceptance'),coalesce((payload->>'weight_tonnes')::numeric,1),(payload->>'required_vehicle_length_ft')::numeric,(payload->>'pickup_at')::timestamptz,coalesce(trim(payload->>'special_note'),''),coalesce(payload->'unload_stops','[]'::jsonb)) returning * into l;$sql$;
  new_insert constant text := $sql$insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,contact_preference,weight_tonnes,required_vehicle_length_ft,pickup_at,special_note,pickup_latitude,pickup_longitude,destination_latitude,destination_longitude,unload_stops)
     values((payload->>'id')::uuid,uid,payload->>'pickup',payload->>'destination',trim(payload->>'cargo'),payload->>'vehicle',(payload->>'pickup_date')::date,(payload->>'price')::numeric,coalesce(payload->>'contact_preference','after_acceptance'),coalesce((payload->>'weight_tonnes')::numeric,1),(payload->>'required_vehicle_length_ft')::numeric,(payload->>'pickup_at')::timestamptz,coalesce(trim(payload->>'special_note'),''),(payload->>'pickup_latitude')::numeric,(payload->>'pickup_longitude')::numeric,(payload->>'destination_latitude')::numeric,(payload->>'destination_longitude')::numeric,coalesce(payload->'unload_stops','[]'::jsonb)) returning * into l;$sql$;
  old_update constant text := $sql$update public.loads set pickup=payload->>'pickup',destination=payload->>'destination',cargo=trim(payload->>'cargo'),vehicle=payload->>'vehicle',pickup_date=(payload->>'pickup_date')::date,price=(payload->>'price')::numeric,contact_preference=payload->>'contact_preference',weight_tonnes=coalesce((payload->>'weight_tonnes')::numeric,1),required_vehicle_length_ft=(payload->>'required_vehicle_length_ft')::numeric,pickup_at=(payload->>'pickup_at')::timestamptz,special_note=coalesce(trim(payload->>'special_note'),''),unload_stops=coalesce(payload->'unload_stops','[]'::jsonb),updated_at=now() where id=l.id returning * into l;$sql$;
  new_update constant text := $sql$update public.loads set pickup=payload->>'pickup',destination=payload->>'destination',cargo=trim(payload->>'cargo'),vehicle=payload->>'vehicle',pickup_date=(payload->>'pickup_date')::date,price=(payload->>'price')::numeric,contact_preference=payload->>'contact_preference',weight_tonnes=coalesce((payload->>'weight_tonnes')::numeric,1),required_vehicle_length_ft=(payload->>'required_vehicle_length_ft')::numeric,pickup_at=(payload->>'pickup_at')::timestamptz,special_note=coalesce(trim(payload->>'special_note'),''),pickup_latitude=(payload->>'pickup_latitude')::numeric,pickup_longitude=(payload->>'pickup_longitude')::numeric,destination_latitude=(payload->>'destination_latitude')::numeric,destination_longitude=(payload->>'destination_longitude')::numeric,unload_stops=coalesce(payload->'unload_stops','[]'::jsonb),updated_at=now() where id=l.id returning * into l;$sql$;
  old_validation_boundary constant text := $sql$ end if;
 if action in ('loads.create','loads.edit') then
   if profile.role<>'shipper' then raise exception 'Only shippers may publish loads.'; end if;$sql$;
  new_validation_boundary constant text := $sql$ end if;
 if action in ('loads.create','loads.edit') then
   if coalesce(jsonb_typeof(payload->'pickup_latitude'), '') <> 'number'
      or coalesce(jsonb_typeof(payload->'pickup_longitude'), '') <> 'number'
      or coalesce(jsonb_typeof(payload->'destination_latitude'), '') <> 'number'
      or coalesce(jsonb_typeof(payload->'destination_longitude'), '') <> 'number' then
     raise exception 'Pick the exact pickup and destination locations on the map.';
   end if;
   if (payload->>'pickup_latitude')::numeric not between -90 and 90
      or (payload->>'pickup_longitude')::numeric not between -180 and 180
      or (payload->>'destination_latitude')::numeric not between -90 and 90
      or (payload->>'destination_longitude')::numeric not between -180 and 180 then
     raise exception 'The selected route location is invalid.';
   end if;
   if exists (
     select 1
     from jsonb_array_elements(coalesce(payload->'unload_stops', '[]'::jsonb)) as stop
     where coalesce(jsonb_typeof(stop->'latitude'), '') <> 'number'
        or coalesce(jsonb_typeof(stop->'longitude'), '') <> 'number'
        or (stop->>'latitude')::numeric not between -90 and 90
        or (stop->>'longitude')::numeric not between -180 and 180
   ) then
     raise exception 'Pick the exact location for every unloading stop.';
   end if;
 end if;
 if action in ('loads.create','loads.edit') then
   if profile.role<>'shipper' then raise exception 'Only shippers may publish loads.'; end if;$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position(old_insert in function_definition) = 0
      or position(old_update in function_definition) = 0
      or position(old_validation_boundary in function_definition) = 0 then
    raise exception 'Could not upgrade LORRY LINK load commands for map-picked locations.';
  end if;
  function_definition := replace(function_definition, old_insert, new_insert);
  function_definition := replace(function_definition, old_update, new_update);
  function_definition := replace(
    function_definition,
    old_validation_boundary,
    new_validation_boundary
  );
  execute function_definition;
end;
$$;
