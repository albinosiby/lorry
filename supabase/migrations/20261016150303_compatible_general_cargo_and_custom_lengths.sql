-- One compatibility rule shared by discovery, invitations and booking guards.
-- Capacity and deck length are still checked separately at every assignment.
create function private.vehicle_type_fits_load(truck_type text, body_type text, required_type text)
returns boolean language sql immutable security invoker set search_path='' as $$
  select coalesce(
    lower(trim(required_type)) in (lower(trim(truck_type)), lower(trim(body_type)))
    or (lower(trim(required_type)) in ('mini truck','pickup','lcv','open truck')
      and (lower(trim(truck_type)) in ('mini truck','pickup','lcv','open truck')
        or lower(trim(body_type)) in ('mini truck','pickup','lcv','open truck'))), false);
$$;
revoke all on function private.vehicle_type_fits_load(text,text,text) from public,anon,authenticated;

-- Preserve the existing functions, ownership checks, locks and privileges.
-- Fail rather than silently skipping a predicate if the upstream code changes.
do $migration$
declare definition text; old_predicate text; new_predicate text;
begin
  definition := pg_get_functiondef('private.check_booking_truck(uuid,uuid,uuid,uuid,boolean)'::regprocedure);
  old_predicate := '(lower(v.vehicle_type)<>lower(l.vehicle) and lower(v.body_type)<>lower(l.vehicle))';
  if strpos(definition,old_predicate)=0 then raise exception 'Booking fit predicate changed'; end if;
  execute replace(definition,old_predicate,'not private.vehicle_type_fits_load(v.vehicle_type,v.body_type,l.vehicle)');

  definition := pg_get_functiondef('private.lorry_api_before_workflow(text,jsonb)'::regprocedure);
  old_predicate := 'ld.vehicle=payload->>''vehicle''';
  if strpos(definition,old_predicate)=0 then raise exception 'Marketplace fit predicate changed'; end if;
  execute replace(definition,old_predicate,
    'private.vehicle_type_fits_load(payload->>''vehicle'',payload->>''vehicle'',ld.vehicle)');

  definition := pg_get_functiondef('private.lorry_customer_api_before_workflow(text,jsonb)'::regprocedure);
  -- Explicit customer type filters remain exact. When browsing for a load,
  -- use compatibility instead of assigning its type as an exact search filter.
  old_predicate := 'requested_type := coalesce(requested_type, load_row.vehicle);';
  if strpos(definition,old_predicate)=0 then raise exception 'Discovery type default changed'; end if;
  definition := replace(definition,old_predicate,'-- Load compatibility checked independently below.');
  old_predicate := 'v.capacity_tonnes >= load_row.weight_tonnes';
  if strpos(definition,old_predicate)=0 then raise exception 'Discovery fit predicate changed'; end if;
  definition := replace(definition,old_predicate,
    'v.capacity_tonnes >= load_row.weight_tonnes and private.vehicle_type_fits_load(v.vehicle_type,v.body_type,load_row.vehicle)');
  old_predicate := '(vehicle.vehicle_type <> load_row.vehicle and vehicle.body_type <> load_row.vehicle)';
  if strpos(definition,old_predicate)=0 then raise exception 'Invitation fit predicate changed'; end if;
  execute replace(definition,old_predicate,
    'not private.vehicle_type_fits_load(vehicle.vehicle_type,vehicle.body_type,load_row.vehicle)');
end $migration$;
