-- LORRY LINK: resume after bootstrap stopped at driver-document commands
--
-- Run this once ONLY after lorry_link_production_bootstrap.sql failed with:
-- "Could not upgrade lorry_next_api driver document commands."
-- The earlier schema statements were already applied. This file resumes at the
-- failed function upgrade and continues through the final migration.
--
-- Bound to production project jsefeymuzseawddtsbrk.

-- Resuming failed source migration: 20261014130000_driver_document_workflow.sql

do $$
declare
  function_definition text;
  old_guard constant text := $sql$if action like 'vehicles.%' or action like 'availability.%' or action like 'finance.%' or action = 'documents.list' then
    if profile.role <> 'driver' and not profile.driver_enabled then
      raise exception 'Enable the driver profile to use this feature.';
    end if;
  end if;$sql$;
  new_guard constant text := $sql$if action like 'vehicles.%' or action like 'availability.%' or action like 'finance.%' or action like 'documents.%' then
    if profile.role <> 'driver' and not profile.driver_enabled then
      raise exception 'Enable the driver profile to use this feature.';
    end if;
  end if;$sql$;
  old_documents constant text := $sql$  if action = 'documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.driver_documents d where d.driver_id = uid;
    return result;
  end if;

  if action = 'tracking.get' then$sql$;
  new_documents constant text := $sql$  if action = 'documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.driver_documents d where d.driver_id = uid;
    return result;
  end if;

  if action = 'documents.register' then
    if coalesce(payload->>'document_type', '') not in (
      'identity', 'driving_license', 'vehicle_registration', 'insurance', 'permit', 'fitness_certificate'
    ) then
      raise exception 'Choose a supported driver document.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    if nullif(payload->>'expires_on', '') is not null
       and (payload->>'expires_on')::date < current_date then
      raise exception 'Document expiry date cannot be in the past.';
    end if;
    if nullif(payload->>'vehicle_id', '') is not null then
      select * into vehicle from public.vehicles
        where id = (payload->>'vehicle_id')::uuid and owner_id = uid;
      if vehicle.id is null then
        raise exception 'Choose one of your registered trucks.';
      end if;
    end if;
    if coalesce(payload->>'document_type', '') in (
      'vehicle_registration', 'insurance', 'permit', 'fitness_certificate'
    ) and nullif(payload->>'vehicle_id', '') is null then
      raise exception 'Choose the truck this document belongs to.';
    end if;
    with inserted as (
      insert into public.driver_documents(
        driver_id, vehicle_id, document_type, storage_path, expires_on
      ) values (
        uid, nullif(payload->>'vehicle_id', '')::uuid, payload->>'document_type',
        payload->>'storage_path', nullif(payload->>'expires_on', '')::date
      ) returning *
    )
    select to_jsonb(inserted) into result from inserted;
    if payload->>'document_type' = 'identity' then
      update public.profiles set verification_status = 'submitted', updated_at = now()
        where id = uid and verification_status = 'pending';
    end if;
    return result;
  end if;

  if action = 'tracking.get' then$sql$;
begin
  select pg_get_functiondef('private.lorry_next_api(text,jsonb)'::regprocedure)
    into function_definition;
  -- The deployed function was created on Windows and contains CRLF line ends.
  -- Normalize it before matching the deliberately formatted command blocks.
  function_definition := replace(function_definition, chr(13), '');
  if position(old_guard in function_definition) = 0
      or position(old_documents in function_definition) = 0 then
    raise exception 'Could not upgrade lorry_next_api driver document commands.';
  end if;
  function_definition := replace(function_definition, old_guard, new_guard);
  function_definition := replace(function_definition, old_documents, new_documents);
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014140000_fix_driver_document_type_values.sql
-- ============================================================================

-- Driver-document table constraints use snake-case values. Correct the
-- protected command introduced by the previous migration accordingly.
do $$
declare
  function_definition text;
begin
  select pg_get_functiondef('private.lorry_next_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, '''drivingLicense''', '''driving_license''');
  function_definition := replace(function_definition, '''vehicleRegistration''', '''vehicle_registration''');
  function_definition := replace(function_definition, '''fitnessCertificate''', '''fitness_certificate''');
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014150000_filter_driver_loads_by_truck_fit.sql
-- ============================================================================

-- Let drivers narrow the marketplace to loads that fit their available truck.
do $$
declare
  function_definition text;
  old_filters constant text := $sql$and (nullif(payload->>'vehicle','') is null or ld.vehicle=payload->>'vehicle')
       and (nullif(payload->>'status','') is null or ld.status=payload->>'status')$sql$;
  new_filters constant text := $sql$and (nullif(payload->>'vehicle','') is null or ld.vehicle=payload->>'vehicle')
       and (nullif(payload->>'max_weight_tonnes','') is null
         or ld.weight_tonnes <= (payload->>'max_weight_tonnes')::numeric)
       and (nullif(payload->>'min_vehicle_length_ft','') is null
         or coalesce(ld.required_vehicle_length_ft, 0) <= (payload->>'min_vehicle_length_ft')::numeric)
       and (nullif(payload->>'status','') is null or ld.status=payload->>'status')$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, chr(13), '');
  if position(old_filters in function_definition) = 0 then
    raise exception 'Could not upgrade lorry_api load-fit filters.';
  end if;
  function_definition := replace(function_definition, old_filters, new_filters);
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014160000_expose_active_booking_on_customer_loads.sql
-- ============================================================================

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


-- ============================================================================
-- Source migration: 20261014170000_track_initial_location_and_delivery_report.sql
-- ============================================================================

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


-- ============================================================================
-- Source migration: 20261014180000_add_intermediate_unload_stops.sql
-- ============================================================================

-- A load may be delivered in parts before reaching its final destination.
alter table public.loads
  add column if not exists unload_stops jsonb not null default '[]'::jsonb,
  add constraint loads_unload_stops_array
    check (jsonb_typeof(unload_stops) = 'array');

do $$
declare
  function_definition text;
  validation constant text := $sql$ if action in ('loads.create','loads.edit') then
   if jsonb_typeof(coalesce(payload->'unload_stops', '[]'::jsonb)) <> 'array'
      or jsonb_array_length(coalesce(payload->'unload_stops', '[]'::jsonb)) > 10 then
     raise exception 'Add up to 10 valid unloading stops.';
   end if;
   if exists (
     select 1
     from jsonb_array_elements(coalesce(payload->'unload_stops', '[]'::jsonb)) as stop
     where jsonb_typeof(stop) <> 'object'
        or length(trim(coalesce(stop->>'location', ''))) < 2
   ) then
     raise exception 'Each unloading stop needs a location.';
   end if;
 end if;
$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position('if action in (''loads.create'',''loads.edit'') then' in function_definition) = 0
      or position(',pickup_at,special_note)' in function_definition) = 0
      or position('coalesce(trim(payload->>''special_note''),'''')) returning * into l;' in function_definition) = 0
      or position('special_note=coalesce(trim(payload->>''special_note''),''''),updated_at=now()' in function_definition) = 0 then
    raise exception 'Could not upgrade LORRY LINK load commands for unloading stops.';
  end if;
  function_definition := replace(
    function_definition,
    'if action in (''loads.create'',''loads.edit'') then',
    validation || ' if action in (''loads.create'',''loads.edit'') then'
  );
  function_definition := replace(
    function_definition,
    ',pickup_at,special_note)',
    ',pickup_at,special_note,unload_stops)'
  );
  function_definition := replace(
    function_definition,
    'coalesce(trim(payload->>''special_note''),'''')) returning * into l;',
    'coalesce(trim(payload->>''special_note''),''''),coalesce(payload->''unload_stops'',''[]''::jsonb)) returning * into l;'
  );
  function_definition := replace(
    function_definition,
    'special_note=coalesce(trim(payload->>''special_note''),''''),updated_at=now()',
    'special_note=coalesce(trim(payload->>''special_note''),''''),unload_stops=coalesce(payload->''unload_stops'',''[]''::jsonb),updated_at=now()'
  );
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014200000_nearby_available_truck_matching.sql
-- ============================================================================

-- GPS-based available-truck discovery. Availability is only public when the
-- driver has explicitly posted a current location and is not on an active trip.

alter table public.bookings
  add column if not exists availability_id uuid
    references public.truck_availability(id) on delete set null;

create index if not exists bookings_availability_idx
  on public.bookings(availability_id)
  where availability_id is not null;

create or replace function private.lorry_customer_api(
  action text,
  payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  profile public.profiles;
  load_row public.loads;
  availability public.truck_availability;
  vehicle public.vehicles;
  booking public.bookings;
  result jsonb;
  item record;
  search_term text := lower(trim(coalesce(payload->>'query', '')));
  requested_type text := nullif(trim(payload->>'vehicle_type'), '');
  sort_mode text := coalesce(nullif(payload->>'sort', ''), 'nearest');
  source_lat numeric := nullif(payload->>'latitude', '')::numeric;
  source_lng numeric := nullif(payload->>'longitude', '')::numeric;
  radius_km numeric := least(greatest(coalesce(nullif(payload->>'radius_km', '')::numeric, 50), 5), 250);
  minimum_capacity numeric := nullif(payload->>'min_capacity_tonnes', '')::numeric;
begin
  if uid is null then
    raise exception 'Please sign in to continue.';
  end if;
  select * into profile from public.profiles where id = uid;
  if profile.id is null then
    raise exception 'Complete your profile first.';
  end if;

  if action = 'profile.documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.profile_documents d where d.profile_id = uid;
    return result;
  end if;

  if action = 'profile.documents.register' then
    if payload->>'document_type' <> 'identity' then
      raise exception 'Choose a supported identity document.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    insert into public.profile_documents(profile_id, document_type, storage_path)
    values (uid, 'identity', payload->>'storage_path')
    returning to_jsonb(profile_documents.*) into result;
    update public.profiles set verification_status = 'submitted', updated_at = now()
      where id = uid and verification_status = 'pending';
    return result;
  end if;

  if action = 'customer.trucks.list' then
    if profile.role <> 'shipper' and not profile.customer_enabled then
      raise exception 'Enable customer access to browse available trucks.';
    end if;
    if sort_mode not in ('nearest', 'capacity_high', 'capacity_low', 'type') then
      raise exception 'Choose a supported truck sort option.';
    end if;
    if source_lat is not null and (source_lat < -90 or source_lat > 90)
      or source_lng is not null and (source_lng < -180 or source_lng > 180) then
      raise exception 'Invalid search location.';
    end if;
    if nullif(payload->>'load_id', '') is not null then
      select * into load_row from public.loads
        where id = (payload->>'load_id')::uuid
          and shipper_id = uid
          and status = 'open';
      if load_row.id is null then
        raise exception 'Choose one of your open loads.';
      end if;
      requested_type := coalesce(requested_type, load_row.vehicle);
      source_lat := coalesce(source_lat, load_row.pickup_latitude);
      source_lng := coalesce(source_lng, load_row.pickup_longitude);
      minimum_capacity := greatest(coalesce(minimum_capacity, 0), load_row.weight_tonnes);
    end if;

    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
      into result from (
        select
          a.*,
          distance.distance_km,
          p.name as driver_name,
          p.verification_status as driver_verification_status,
          p.photo_path as driver_photo_path,
          jsonb_build_object(
            'id', v.id,
            'vehicle_type', v.vehicle_type,
            'body_type', v.body_type,
            'length_ft', v.length_ft,
            'capacity_tonnes', v.capacity_tonnes,
            'verification_status', v.verification_status,
            'registration_label', right(v.registration_number, 4)
          ) as vehicle
        from public.truck_availability a
        join public.vehicles v on v.id = a.vehicle_id
        join public.profiles p on p.id = a.driver_id
        cross join lateral (
          select case
            when source_lat is null or source_lng is null then null
            else round((6371 * acos(least(1::numeric, greatest(-1::numeric,
              cos(radians(source_lat)) * cos(radians(a.latitude)) *
              cos(radians(a.longitude) - radians(source_lng)) +
              sin(radians(source_lat)) * sin(radians(a.latitude))
            ))))::numeric, 2)
          end as distance_km
        ) distance
        where a.status = 'open'
          and a.latitude is not null and a.longitude is not null
          and a.available_from <= now()
          and (a.available_until is null or a.available_until > now())
          and not exists (
            select 1 from public.bookings active_booking
            where active_booking.driver_id = a.driver_id
              and active_booking.status = 'in_transit'
          )
          and (minimum_capacity is null or v.capacity_tonnes >= minimum_capacity)
          and (requested_type is null or v.vehicle_type = requested_type or v.body_type = requested_type)
          and (load_row.id is null or (
            v.capacity_tonnes >= load_row.weight_tonnes
            and (load_row.required_vehicle_length_ft is null or v.length_ft >= load_row.required_vehicle_length_ft)
          ))
          and (source_lat is null or distance.distance_km <= radius_km)
          and (search_term = ''
            or lower(p.name) like '%' || search_term || '%'
            or lower(v.registration_number) like '%' || search_term || '%'
            or lower(a.current_location) like '%' || search_term || '%')
        order by
          case when sort_mode = 'nearest' then distance.distance_km end asc nulls last,
          case when sort_mode = 'capacity_high' then v.capacity_tonnes end desc nulls last,
          case when sort_mode = 'capacity_low' then v.capacity_tonnes end asc nulls last,
          case when sort_mode = 'type' then lower(v.vehicle_type) end asc nulls last,
          a.available_from asc
      ) x;
    return result;
  end if;

  if action = 'customer.truck.invite' then
    if profile.role <> 'shipper' and not profile.customer_enabled then
      raise exception 'Only customers can invite an available truck.';
    end if;
    select * into load_row from public.loads
      where id = (payload->>'load_id')::uuid and shipper_id = uid for update;
    if load_row.id is null or load_row.status <> 'open' then
      raise exception 'Choose one of your open loads.';
    end if;
    select a into availability from public.truck_availability a
      where a.id = (payload->>'availability_id')::uuid
        and a.status = 'open'
        and a.latitude is not null and a.longitude is not null
        and a.available_from <= now()
        and (a.available_until is null or a.available_until > now())
      for update;
    if availability.id is null then
      raise exception 'This truck is no longer available.';
    end if;
    if exists (
      select 1 from public.bookings active_booking
      where active_booking.driver_id = availability.driver_id
        and active_booking.status = 'in_transit'
    ) then
      raise exception 'This driver is currently on a trip.';
    end if;
    select v into vehicle from public.vehicles v where v.id = availability.vehicle_id;
    if vehicle.id is null then
      raise exception 'This truck is no longer available.';
    end if;
    if vehicle.capacity_tonnes < load_row.weight_tonnes
       or (load_row.required_vehicle_length_ft is not null and vehicle.length_ft < load_row.required_vehicle_length_ft)
       or (vehicle.vehicle_type <> load_row.vehicle and vehicle.body_type <> load_row.vehicle) then
      raise exception 'This truck does not match the load requirements.';
    end if;
    select * into booking from public.bookings
      where load_id = load_row.id
        and driver_id = availability.driver_id
        and status in ('requested', 'accepted', 'in_transit')
      for update;
    if booking.id is null then
      insert into public.bookings(load_id, driver_id, source, availability_id)
      values (load_row.id, availability.driver_id, 'customer_invitation', availability.id)
      returning * into booking;
      insert into public.booking_events(booking_id, actor_id, status, note)
      values (booking.id, uid, 'requested', 'Customer invited this truck');
      insert into public.notifications(recipient_id, title, body, load_id, booking_id)
      values (availability.driver_id, 'Truck invitation', profile.name || ' invited your truck for a load', load_row.id, booking.id);
    end if;
    return to_jsonb(booking);
  end if;

  if action = 'customer.invitation.accept' then
    select * into booking from public.bookings where id = (payload->>'booking_id')::uuid for update;
    select * into load_row from public.loads l where l.id = booking.load_id for update;
    if booking.id is null or booking.driver_id <> uid or booking.source <> 'customer_invitation'
       or booking.status <> 'requested' or load_row.status <> 'open' then
      raise exception 'This invitation is no longer available.';
    end if;
    update public.bookings set status = 'accepted', updated_at = now() where id = booking.id;
    update public.loads set status = 'assigned', updated_at = now() where id = load_row.id;
    update public.truck_availability set status = 'matched', updated_at = now()
      where id = booking.availability_id and driver_id = uid and status = 'open';
    for item in update public.bookings set status = 'declined', reason = 'Another driver was selected', updated_at = now()
      where load_id = load_row.id and id <> booking.id and status = 'requested' returning * loop
      insert into public.booking_events(booking_id, actor_id, status, note)
      values (item.id, uid, 'declined', 'Another driver was selected');
      insert into public.notifications(recipient_id, title, body, load_id, booking_id)
      values (item.driver_id, 'Booking declined', 'Another driver was selected', load_row.id, item.id);
    end loop;
    insert into public.booking_events(booking_id, actor_id, status, note)
    values (booking.id, uid, 'accepted', 'Driver accepted the customer invitation');
    insert into public.notifications(recipient_id, title, body, load_id, booking_id)
    values (load_row.shipper_id, 'Truck invitation accepted', 'Your driver is ready to coordinate.', load_row.id, booking.id);
    return '{}'::jsonb;
  end if;

  if action = 'tracking.get' then
    select to_jsonb(t) into result from public.active_trip_locations t
    join public.bookings b on b.id = t.booking_id
    join public.loads l on l.id = b.load_id
    where t.booking_id = (payload->>'booking_id')::uuid
      and (b.driver_id = uid or l.shipper_id = uid);
    return result;
  end if;

  if action = 'tracking.update' then
    select b into booking from public.bookings b where b.id = (payload->>'booking_id')::uuid for update;
    select l into load_row from public.loads l where l.id = booking.load_id;
    if booking.id is null or booking.driver_id <> uid or booking.status <> 'in_transit' then
      raise exception 'Location sharing is available only during your active trip.';
    end if;
    if (payload->>'latitude')::numeric not between -90 and 90
       or (payload->>'longitude')::numeric not between -180 and 180 then
      raise exception 'Invalid location.';
    end if;
    insert into public.active_trip_locations(booking_id, driver_id, latitude, longitude, accuracy_meters, heading_degrees, recorded_at)
    values (booking.id, uid, (payload->>'latitude')::numeric, (payload->>'longitude')::numeric,
      (payload->>'accuracy_meters')::numeric, (payload->>'heading_degrees')::numeric,
      coalesce((payload->>'recorded_at')::timestamptz, now()))
    on conflict (booking_id) do update set
      latitude = excluded.latitude, longitude = excluded.longitude,
      accuracy_meters = excluded.accuracy_meters, heading_degrees = excluded.heading_degrees,
      recorded_at = excluded.recorded_at, received_at = now();
    return '{}'::jsonb;
  end if;

  raise exception 'Unsupported customer marketplace action.';
end;
$$;
revoke all on function private.lorry_customer_api(text, jsonb) from public, anon, authenticated;
grant execute on function private.lorry_customer_api(text, jsonb) to authenticated;

create or replace function public.lorry_customer_api(
  action text, payload jsonb default '{}'::jsonb
) returns jsonb language sql security invoker set search_path = '' as $$
  select private.lorry_customer_api(action, payload);
$$;
revoke all on function public.lorry_customer_api(text, jsonb) from public, anon;
grant execute on function public.lorry_customer_api(text, jsonb) to authenticated;

-- Availability posts require an explicit GPS point, and a driver who has an
-- active trip cannot publish another public availability post.
do $$
declare
  function_definition text;
  old_location_guard constant text := $sql$    if length(trim(coalesce(payload->>'current_location', ''))) < 2 then
      raise exception 'Enter your current location.';
    end if;$sql$;
  new_location_guard constant text := $sql$    if length(trim(coalesce(payload->>'current_location', ''))) < 2 then
      raise exception 'Enter your current location.';
    end if;
    if nullif(payload->>'latitude', '') is null or nullif(payload->>'longitude', '') is null then
      raise exception 'Use your current GPS location before posting availability.';
    end if;
    if (payload->>'latitude')::numeric not between -90 and 90
       or (payload->>'longitude')::numeric not between -180 and 180 then
      raise exception 'Invalid availability location.';
    end if;
    if exists (
      select 1 from public.bookings b
      where b.driver_id = uid and b.status = 'in_transit'
    ) then
      raise exception 'Finish the active trip before making a truck available.';
    end if;$sql$;
  old_visibility constant text := $sql$where a.status = 'open' and a.available_from <= now() + interval '30 days'$sql$;
  new_visibility constant text := $sql$where a.status = 'open'
            and a.latitude is not null and a.longitude is not null
            and a.available_from <= now() + interval '30 days'
            and (a.available_until is null or a.available_until > now())
            and not exists (
              select 1 from public.bookings active_booking
              where active_booking.driver_id = a.driver_id
                and active_booking.status = 'in_transit'
            )$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_next_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position(old_location_guard in function_definition) = 0
      or position(old_visibility in function_definition) = 0 then
    raise exception 'Could not upgrade truck availability commands.';
  end if;
  function_definition := replace(function_definition, old_location_guard, new_location_guard);
  function_definition := replace(function_definition, old_visibility, new_visibility);
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014200500_truck_availability_vehicle_index.sql
-- ============================================================================

-- Supports the vehicle foreign key and availability-to-vehicle lookup.
create index if not exists truck_availability_vehicle_idx
  on public.truck_availability (vehicle_id);


-- ============================================================================
-- Source migration: 20261014210000_require_load_route_coordinates.sql
-- ============================================================================

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


-- ============================================================================
-- Source migration: 20261014220000_customer_identity_document_workflow.sql
-- ============================================================================

-- Customers submit one identity document of their choice and can safely
-- replace or remove it from their profile.
alter table public.profile_documents
  drop constraint if exists profile_documents_document_type_check;
alter table public.profile_documents
  add constraint profile_documents_document_type_check
  check (document_type in ('identity', 'aadhaar', 'pan', 'driving_licence'));

drop policy if exists profile_documents_delete_own on storage.objects;
create policy profile_documents_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

do $$
declare
  function_definition text;
  old_declaration constant text := $sql$  booking public.bookings;
  result jsonb;$sql$;
  new_declaration constant text := $sql$  booking public.bookings;
  profile_document public.profile_documents;
  result jsonb;$sql$;
  old_list constant text := $sql$  if action = 'profile.documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.profile_documents d where d.profile_id = uid;
    return result;
  end if;$sql$;
  new_list constant text := $sql$  if action = 'profile.documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
      into result from (
        select * from public.profile_documents
        where profile_id = uid
        order by created_at desc
        limit 1
      ) d;
    return result;
  end if;$sql$;
  old_register constant text := $sql$  if action = 'profile.documents.register' then
    if payload->>'document_type' <> 'identity' then
      raise exception 'Choose a supported identity document.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    insert into public.profile_documents(profile_id, document_type, storage_path)
    values (uid, 'identity', payload->>'storage_path')
    returning to_jsonb(profile_documents.*) into result;
    update public.profiles set verification_status = 'submitted', updated_at = now()
      where id = uid and verification_status = 'pending';
    return result;
  end if;$sql$;
  new_register constant text := $sql$  if action = 'profile.documents.register' then
    if coalesce(payload->>'document_type', '') not in ('aadhaar', 'pan', 'driving_licence') then
      raise exception 'Choose Aadhaar, PAN or driving licence.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    select * into profile_document from public.profile_documents
      where profile_id = uid order by created_at desc limit 1 for update;
    if profile_document.id is null then
      insert into public.profile_documents(profile_id, document_type, storage_path)
      values (uid, payload->>'document_type', payload->>'storage_path')
      returning to_jsonb(profile_documents.*) into result;
    else
      update public.profile_documents
      set document_type = payload->>'document_type',
          storage_path = payload->>'storage_path',
          status = 'submitted',
          rejection_reason = null,
          reviewed_at = null,
          created_at = now()
      where id = profile_document.id
      returning to_jsonb(profile_documents.*) into result;
    end if;
    update public.profiles set verification_status = 'submitted', updated_at = now()
      where id = uid;
    return result;
  end if;

  if action = 'profile.documents.remove' then
    select * into profile_document from public.profile_documents
      where id = (payload->>'id')::uuid and profile_id = uid for update;
    if profile_document.id is null then
      raise exception 'This identity document is unavailable.';
    end if;
    delete from public.profile_documents where id = profile_document.id;
    if not exists (select 1 from public.profile_documents where profile_id = uid) then
      update public.profiles set verification_status = 'pending', updated_at = now()
        where id = uid;
    end if;
    return '{}'::jsonb;
  end if;$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_customer_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position(old_declaration in function_definition) = 0
      or position(old_list in function_definition) = 0
      or position(old_register in function_definition) = 0 then
    raise exception 'Could not upgrade customer identity document commands.';
  end if;
  function_definition := replace(function_definition, old_declaration, new_declaration);
  function_definition := replace(function_definition, old_list, new_list);
  function_definition := replace(function_definition, old_register, new_register);
  execute function_definition;
end;
$$;


-- ============================================================================
-- Source migration: 20261014224000_record_collected_freight_on_delivery.sql
-- ============================================================================

-- A driver reports delivery with the amount actually collected. Keep the
-- booking event and finance income in one RPC transaction.
create unique index if not exists one_freight_income_per_booking
  on public.finance_entries(booking_id)
  where booking_id is not null and entry_type = 'income' and category = 'freight';

do $$
declare
  function_definition text;
  old_delivery constant text := $sql$   elsif next_status='delivery_reported' then
     if b.driver_id<>uid or b.status<>'in_transit' then raise exception 'Only the driver of an active trip can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'::jsonb; end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;$sql$;
  new_delivery constant text := $sql$   elsif next_status='delivery_reported' then
     if b.driver_id<>uid or b.status<>'in_transit' then raise exception 'Only the driver of an active trip can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'::jsonb; end if;
     if coalesce((payload->>'amount_collected')::numeric, 0) <= 0 then
       raise exception 'Enter the amount collected before reporting delivery.';
     end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;
     insert into public.finance_entries(driver_id, booking_id, entry_type, category, amount, occurred_on, note)
     values (uid, b.id, 'income', 'freight', (payload->>'amount_collected')::numeric, current_date, 'Freight collected on delivery');$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, chr(13), '');
  if position(old_delivery in function_definition) = 0 then
    raise exception 'Could not add collected freight to the delivery workflow.';
  end if;
  execute replace(function_definition, old_delivery, new_delivery);
end;
$$;


-- ============================================================================
-- Source migration: 20261014230000_always_expose_authorized_contact_details.sql
-- ============================================================================

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


-- ============================================================================
-- Source migration: 20261015071745_fcm_push_notifications.sql
-- ============================================================================

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema private to service_role;

create table public.push_tokens (
  token text primary key check(length(token) between 20 and 4096),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index push_tokens_profile_idx on public.push_tokens(profile_id);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;
grant all on public.push_tokens to service_role;

create table public.push_jobs (
  notification_id uuid primary key references public.notifications(id) on delete cascade,
  state text not null default 'pending' check(state in ('pending','sending','sent','failed')),
  attempts integer not null default 0,
  updated_at timestamptz not null default now(),
  last_error text
);
alter table public.push_jobs enable row level security;
revoke all on public.push_jobs from anon, authenticated;
grant all on public.push_jobs to service_role;
create index push_jobs_pending_idx on public.push_jobs(state, updated_at) where state <> 'sent';

-- Only this server-side hook and the service-role dispatcher can read the key.
select vault.create_secret(gen_random_uuid()::text || gen_random_uuid()::text, 'fcm_webhook_secret');

create function private.register_push_token(device_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  if device_token is null or length(device_token) not between 20 and 4096 then
    raise exception 'Invalid device token.';
  end if;
  insert into public.push_tokens(token,profile_id) values(device_token,auth.uid())
  on conflict(token) do update set profile_id=auth.uid(),updated_at=now();
end $$;
revoke all on function private.register_push_token(text) from public,anon,authenticated;
grant execute on function private.register_push_token(text) to authenticated;
create function public.register_push_token(device_token text) returns void
language sql security invoker set search_path='' as $$ select private.register_push_token(device_token); $$;
revoke all on function public.register_push_token(text) from public,anon;
grant execute on function public.register_push_token(text) to authenticated;

create function private.remove_push_token(device_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  delete from public.push_tokens where token=device_token and profile_id=auth.uid();
end $$;
revoke all on function private.remove_push_token(text) from public,anon,authenticated;
grant execute on function private.remove_push_token(text) to authenticated;
create function public.remove_push_token(device_token text) returns void
language sql security invoker set search_path='' as $$ select private.remove_push_token(device_token); $$;
revoke all on function public.remove_push_token(text) from public,anon;
grant execute on function public.remove_push_token(text) to authenticated;

create function private.claim_push_job(job_id uuid, webhook_secret text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job public.push_jobs; result jsonb;
begin
  if webhook_secret is null or webhook_secret is distinct from
    (select decrypted_secret from vault.decrypted_secrets where name='fcm_webhook_secret' limit 1)
    then raise exception 'Unauthorized push request.'; end if;
  select * into job from public.push_jobs where notification_id=job_id for update;
  if job.notification_id is null or job.state='sent' or job.attempts>=5
    or (job.state='sending' and job.updated_at>now()-interval '3 minutes') then return null; end if;
  update public.push_jobs set state='sending',attempts=attempts+1,updated_at=now()
    where notification_id=job_id;
  select to_jsonb(n) || jsonb_build_object('tokens',
    (select coalesce(jsonb_agg(t.token),'[]') from public.push_tokens t where t.profile_id=n.recipient_id))
    into result from public.notifications n where n.id=job_id;
  return result;
end $$;
revoke all on function private.claim_push_job(uuid,text) from public,anon,authenticated;
grant execute on function private.claim_push_job(uuid,text) to service_role;
create function public.claim_push_job(job_id uuid, webhook_secret text) returns jsonb
language sql security invoker set search_path='' as $$ select private.claim_push_job(job_id,webhook_secret); $$;
revoke all on function public.claim_push_job(uuid,text) from public,anon,authenticated;
grant execute on function public.claim_push_job(uuid,text) to service_role;

create function private.send_push_request(job_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform net.http_post(
    url := 'https://jsefeymuzseawddtsbrk.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type','application/json','x-push-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='fcm_webhook_secret' limit 1)),
    body := jsonb_build_object('notification_id',job_id), timeout_milliseconds := 10000);
end $$;
revoke all on function private.send_push_request(uuid) from public,anon,authenticated;

create function private.queue_notification_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.push_jobs(notification_id) values(new.id);
  perform private.send_push_request(new.id);
  return new;
end $$;
revoke all on function private.queue_notification_push() from public,anon,authenticated;
create trigger notification_push after insert on public.notifications
for each row execute function private.queue_notification_push();

create function private.retry_push_jobs() returns void
language plpgsql security definer set search_path='' as $$
declare job record;
begin
  for job in select notification_id from public.push_jobs
    where state<>'sent' and attempts<5 and updated_at<now()-interval '3 minutes'
    order by updated_at limit 20 loop
    perform private.send_push_request(job.notification_id);
  end loop;
end $$;
revoke all on function private.retry_push_jobs() from public,anon,authenticated;
select cron.schedule('retry-lorry-push','*/3 * * * *','select private.retry_push_jobs()');


-- ============================================================================
-- Source migration: 20261015073259_fcm_vault_credentials.sql
-- ============================================================================

-- The actual service-account JSON is provisioned directly into encrypted
-- Vault storage. Never include it in a migration or client configuration.
create function private.fcm_service_account() returns jsonb
language sql security definer set search_path='' as $$
  select decrypted_secret::jsonb from vault.decrypted_secrets
    where name='fcm_service_account' limit 1;
$$;
revoke all on function private.fcm_service_account() from public,anon,authenticated;
grant execute on function private.fcm_service_account() to service_role;
create function public.fcm_service_account() returns jsonb
language sql security invoker set search_path='' as $$
  select private.fcm_service_account();
$$;
revoke all on function public.fcm_service_account() from public,anon,authenticated;
grant execute on function public.fcm_service_account() to service_role;


-- ============================================================================
-- Source migration: 20261015110000_allow_rerequest_cancelled_bookings.sql
-- ============================================================================

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


-- ============================================================================
-- Source migration: 20261015113508_collection_and_location_status.sql
-- ============================================================================

alter table public.bookings add column item_collected_at timestamptz;
alter table public.active_trip_locations add column location_enabled boolean not null default true;
alter table public.active_trip_locations add column status_checked_at timestamptz not null default now();

create function private.refresh_location_status() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='INSERT' or new.recorded_at is distinct from old.recorded_at then
    new.location_enabled:=true; new.status_checked_at:=now();
  end if;
  return new;
end $$;
revoke all on function private.refresh_location_status() from public,anon,authenticated;
create trigger refresh_location_status before insert or update on public.active_trip_locations
for each row execute function private.refresh_location_status();

create function private.trip_location_status(booking_id uuid, enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.bookings b where b.id=booking_id
    and b.driver_id=auth.uid() and b.status in ('accepted','in_transit')) then
    raise exception 'Only the assigned driver can update location sharing.';
  end if;
  update public.active_trip_locations t set location_enabled=enabled,status_checked_at=now()
    where t.booking_id=trip_location_status.booking_id;
end $$;
revoke all on function private.trip_location_status(uuid,boolean) from public,anon,authenticated;
grant execute on function private.trip_location_status(uuid,boolean) to authenticated;
create function public.trip_location_status(booking_id uuid, enabled boolean) returns void
language sql security invoker set search_path='' as $$select private.trip_location_status(booking_id,enabled);$$;
revoke all on function public.trip_location_status(uuid,boolean) from public,anon;
grant execute on function public.trip_location_status(uuid,boolean) to authenticated;

do $$
declare source text;
boundary text := $s$   elsif next_status='in_transit' then$s$;
collection text := $s$   elsif next_status='item_collected' then
     if b.driver_id<>uid or b.status<>'accepted' then raise exception 'Only the assigned driver can collect this load.'; end if;
     if b.item_collected_at is not null then return '{}'::jsonb; end if;
     if (payload->>'latitude') is null or (payload->>'longitude') is null
       or (payload->>'latitude')::numeric not between -90 and 90
       or (payload->>'longitude')::numeric not between -180 and 180 then
       raise exception 'Enable location before confirming collection.';
     end if;
     update public.bookings set item_collected_at=now(),updated_at=now() where id=b.id;
     insert into public.active_trip_locations(booking_id,driver_id,latitude,longitude,recorded_at)
       values(b.id,uid,(payload->>'latitude')::numeric,(payload->>'longitude')::numeric,now())
       on conflict(booking_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,recorded_at=now();
   elsif next_status='in_transit' then
     if b.item_collected_at is null then raise exception 'Confirm Item collected before starting the trip.'; end if;$s$;
begin
 select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure),chr(13),'') into source;
 if position(boundary in source)=0 then raise exception 'Trip transition boundary missing'; end if;
 source:=replace(source,boundary,collection);
 source:=replace(source,$s$if next_status<>'delivery_reported' then$s$,$s$if next_status not in ('delivery_reported','item_collected') then$s$);
 execute source;
end $$;


-- ============================================================================
-- Source migration: 20261015133920_end_to_end_booking_workflow.sql
-- ============================================================================

-- Keep the existing lifecycle codes for compatibility. Collection and delivery
-- timestamps provide the finer-grained stages; payment is an independent ledger.
alter table public.bookings
  add column vehicle_id uuid references public.vehicles(id) on delete set null,
  add column agreed_freight numeric check (agreed_freight > 0),
  add column unloaded_stop_indices integer[] not null default '{}',
  add column delivery_issue text;
create index bookings_vehicle_workflow_idx on public.bookings(vehicle_id, status);
-- Partial payments need several ledger rows per booking. The ledger primary
-- key is the idempotency key, while the booking lock serializes balance checks.
drop index public.one_freight_income_per_booking;
create index freight_payments_booking_idx on public.finance_entries(booking_id)
  where booking_id is not null and entry_type='income' and category='freight';
update public.bookings b set vehicle_id=a.vehicle_id
from public.truck_availability a where a.id=b.availability_id;
update public.bookings b set agreed_freight=l.price
from public.loads l where l.id=b.load_id and l.price>0;

-- Serializing on the driver's profile protects assignments on different loads.
-- No unique index is imposed on historical conflicting bookings: they are kept.
create function private.check_booking_truck(driver uuid, truck uuid, load_id uuid,
  excluded_booking uuid default null, require_free boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.vehicles; l public.loads;
begin
  perform 1 from public.profiles where id=driver for update;
  select * into l from public.loads where id=load_id;
  select * into v from public.vehicles where id=truck and owner_id=driver for update;
  if v.id is null then raise exception 'Select one of your trucks before continuing.'; end if;
  if v.capacity_tonnes<l.weight_tonnes
    or v.length_ft<coalesce(l.required_vehicle_length_ft,0)
    or (lower(v.vehicle_type)<>lower(l.vehicle) and lower(v.body_type)<>lower(l.vehicle)) then
    raise exception 'This truck does not fit the load capacity, length or body type.';
  end if;
  if require_free and exists(select 1 from public.bookings b
    where b.id is distinct from excluded_booking
      and (b.driver_id=driver or b.vehicle_id=truck)
      and (b.status='accepted' or (b.status='in_transit' and b.delivery_reported_at is null))) then
    raise exception 'This driver or truck already has an assigned or active trip.';
  end if;
  return v.id;
end $$;
revoke all on function private.check_booking_truck(uuid,uuid,uuid,uuid,boolean) from public,anon,authenticated;

create function private.booking_extra(booking uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
   'vehicle_id',b.vehicle_id,'assigned_vehicle',to_jsonb(v),
   'agreed_freight',b.agreed_freight,'amount_collected',coalesce(f.total,0),
   'payment_status',case when b.agreed_freight is null then 'freight_unset'
     when coalesce(f.total,0)>=b.agreed_freight then 'paid'
     when coalesce(f.total,0)>0 then 'partial' else 'unpaid' end,
   'payment_balance',case when b.agreed_freight is null then null else greatest(0,b.agreed_freight-coalesce(f.total,0)) end,
   'item_collected_at',b.item_collected_at,'unloaded_stop_indices',b.unloaded_stop_indices,
   'delivery_issue',b.delivery_issue)
 from public.bookings b left join public.vehicles v on v.id=b.vehicle_id
 left join lateral (select sum(amount) total from public.finance_entries
   where booking_id=b.id and driver_id=b.driver_id and entry_type='income' and category='freight') f on true
 where b.id=booking;
$$;
revoke all on function private.booking_extra(uuid) from public,anon,authenticated;

alter function private.lorry_api(text,jsonb) rename to lorry_api_before_workflow;
revoke all on function private.lorry_api_before_workflow(text,jsonb) from public,anon,authenticated;

create function private.lorry_api(action text,payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); b public.bookings; l public.loads; result jsonb;
  truck uuid; target_status text:=payload->>'status'; payment_id uuid;
  collected_amount numeric; total numeric; agreed numeric; stop_index integer; counterparty uuid;
begin
 if uid is null or not exists(select 1 from auth.users where id=uid) then raise exception 'Please sign in to continue.'; end if;
 if action='bookings.request' then
   if not exists(select 1 from public.profiles where id=uid and (role='driver' or driver_enabled)) then
     raise exception 'Enable driver access first.'; end if;
   select * into l from public.loads where id=(payload->>'load_id')::uuid for update;
   if l.id is null or l.shipper_id=uid or l.status<>'open' then raise exception 'This load is no longer available.'; end if;
   truck:=private.check_booking_truck(uid,nullif(payload->>'vehicle_id','')::uuid,l.id);
   select * into b from public.bookings where load_id=l.id and driver_id=uid for update;
   if b.id is not null and b.status='requested' then return to_jsonb(b); end if;
   if b.id is not null and b.status not in ('declined','cancelled') then raise exception 'This booking is already assigned.'; end if;
   agreed:=coalesce(l.price,nullif(payload->>'agreed_freight','')::numeric);
   if b.id is null then
     insert into public.bookings(load_id,driver_id,vehicle_id,agreed_freight)
     values(l.id,uid,truck,agreed) returning * into b;
   else
     update public.bookings set status='requested',vehicle_id=truck,agreed_freight=agreed,
       reason=null,source='driver_request',availability_id=null,updated_at=now()
       where id=b.id returning * into b;
   end if;
   insert into public.booking_events(booking_id,actor_id,status) values(b.id,uid,'requested');
   insert into public.notifications(recipient_id,title,body,load_id,booking_id)
     values(l.shipper_id,'New booking request','A driver requested your load.',l.id,b.id);
   return to_jsonb(b);
 end if;
 if action in ('bookings.transition','bookings.payment','bookings.assign_truck','bookings.stop_unloaded','bookings.delivery_issue') then
   select load_id into truck from public.bookings where id=(payload->>'id')::uuid;
   select * into l from public.loads where id=truck for update;
   select * into b from public.bookings where id=(payload->>'id')::uuid for update;
   if b.id is null or (b.driver_id<>uid and l.shipper_id<>uid) then raise exception 'This booking is unavailable.'; end if;
   perform 1 from public.profiles where id=b.driver_id for update;
   counterparty:=case when uid=b.driver_id then l.shipper_id else b.driver_id end;
   if action='bookings.assign_truck' then
     if b.driver_id<>uid or b.status not in ('requested','accepted') then
       raise exception 'Only the driver can select a truck before the trip starts.'; end if;
     truck:=private.check_booking_truck(uid,(payload->>'vehicle_id')::uuid,l.id,b.id,b.status='accepted');
     update public.bookings set vehicle_id=truck,updated_at=now() where id=b.id;
     insert into public.notifications(recipient_id,title,body,load_id,booking_id)
       values(counterparty,'Assigned truck updated','The driver selected the truck for your load.',l.id,b.id);
     return '{}';
   elsif action='bookings.payment' then
     if b.driver_id<>uid or b.delivery_reported_at is null or b.status not in ('in_transit','completed') then
       raise exception 'Only the assigned driver can record collection after delivery.'; end if;
     payment_id:=(payload->>'payment_id')::uuid;
     collected_amount:=(payload->>'amount_collected')::numeric;
     if payment_id is null or collected_amount is null or collected_amount<=0 or collected_amount='NaN'::numeric then raise exception 'Enter a valid collection amount.'; end if;
     if exists(select 1 from public.finance_entries where id=payment_id) then
       if not exists(select 1 from public.finance_entries where id=payment_id and driver_id=uid
         and booking_id=b.id and entry_type='income' and category='freight' and finance_entries.amount=collected_amount) then
         raise exception 'Payment reference already used.'; end if;
       return '{}';
     end if;
     select coalesce(sum(f.amount),0) into total from public.finance_entries f where booking_id=b.id
       and driver_id=uid and entry_type='income' and category='freight';
     agreed:=coalesce(b.agreed_freight,nullif(payload->>'agreed_freight','')::numeric);
     if agreed is null or agreed<=0 or agreed='NaN'::numeric then raise exception 'Enter the agreed freight amount first.'; end if;
     if total+collected_amount>agreed then raise exception 'Collection exceeds the remaining freight balance.'; end if;
     update public.bookings set agreed_freight=agreed,updated_at=now() where id=b.id;
     insert into public.finance_entries(id,driver_id,booking_id,entry_type,category,amount,occurred_on,note)
       values(payment_id,uid,b.id,'income','freight',collected_amount,(now() at time zone 'Asia/Kolkata')::date,'Freight payment collected');
     insert into public.booking_events(booking_id,actor_id,status,note) values(b.id,uid,'payment_recorded','Collected ₹'||collected_amount::text);
     insert into public.notifications(recipient_id,title,body,load_id,booking_id)
       values(counterparty,'Freight payment recorded','The driver recorded collection of ₹'||collected_amount::text,l.id,b.id);
     return '{}';
   elsif action='bookings.stop_unloaded' then
     if b.driver_id<>uid or b.status<>'in_transit' or b.delivery_reported_at is not null then raise exception 'Only the driver of an active trip can mark unloading.'; end if;
     stop_index:=(payload->>'stop_index')::integer;
     if stop_index is null or stop_index<0 or stop_index>=jsonb_array_length(l.unload_stops) then raise exception 'Choose a valid unloading stop.'; end if;
     if stop_index=any(b.unloaded_stop_indices) then return '{}'; end if;
     update public.bookings set unloaded_stop_indices=array_append(unloaded_stop_indices,stop_index),updated_at=now() where id=b.id;
     insert into public.booking_events(booking_id,actor_id,status,note) values(b.id,uid,'stop_unloaded','Unloaded at stop '||(stop_index+1)::text);
     insert into public.notifications(recipient_id,title,body,load_id,booking_id)
       values(counterparty,'Intermediate unloading completed',l.unload_stops->stop_index->>'location',l.id,b.id);
     return '{}';
   elsif action='bookings.delivery_issue' then
     if l.shipper_id<>uid or b.delivery_reported_at is null or b.status='completed' then raise exception 'Report an issue before confirming receipt.'; end if;
     if length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Describe the delivery issue.'; end if;
     update public.bookings set delivery_issue=left(trim(payload->>'reason'),1000),updated_at=now() where id=b.id;
     insert into public.booking_events(booking_id,actor_id,status,note) values(b.id,uid,'delivery_issue',left(trim(payload->>'reason'),1000));
     insert into public.notifications(recipient_id,title,body,load_id,booking_id)
       values(counterparty,'Customer reported a delivery issue','Contact the customer before resolving this booking.',l.id,b.id);
     return '{}';
   elsif target_status='delivery_reported' then
     if b.driver_id<>uid or b.status not in ('in_transit','completed') then raise exception 'Only the assigned driver can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'; end if;
     if cardinality(b.unloaded_stop_indices)<jsonb_array_length(l.unload_stops) then raise exception 'Confirm unloading at each intermediate stop first.'; end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;
     -- Availability must be freshly posted with the driver's new position.
     update public.truck_availability set status='closed',updated_at=now()
       where driver_id=b.driver_id and status in ('open','matched');
     insert into public.booking_events(booking_id,actor_id,status) values(b.id,uid,'delivery_reported');
     insert into public.notifications(recipient_id,title,body,load_id,booking_id)
       values(counterparty,'Delivery reported','Confirm receipt or report an issue. Payment is tracked separately.',l.id,b.id);
     return '{}';
   else
     if target_status in ('accepted','item_collected','in_transit')
       and not (target_status='accepted' and b.status='accepted')
       and not (target_status='in_transit' and b.status='in_transit') then
       perform private.check_booking_truck(b.driver_id,b.vehicle_id,l.id,b.id,true);
     end if;
     if target_status='completed' and b.delivery_issue is not null then
       -- Confirming receipt explicitly resolves the issue; the event history stays.
       update public.bookings set delivery_issue=null where id=b.id;
     end if;
   end if;
 end if;
 result:=private.lorry_api_before_workflow(action,payload);
 if action='bookings.get' then return result||private.booking_extra((result->>'id')::uuid); end if;
 if action='bookings.list' then
   select coalesce(jsonb_agg(item||private.booking_extra((item->>'id')::uuid) order by ord),'[]') into result
     from jsonb_array_elements(result) with ordinality as rows(item,ord);
 elsif action='loads.get' and result->>'booking_id' is not null then
   result:=result||private.booking_extra((result->>'booking_id')::uuid);
 elsif action='loads.list' then
   select coalesce(jsonb_agg(case when item->>'booking_id' is null then item
     else item||private.booking_extra((item->>'booking_id')::uuid) end order by ord),'[]') into result
     from jsonb_array_elements(result) with ordinality as rows(item,ord);
 end if;
 return result;
end $$;
revoke all on function private.lorry_api(text,jsonb) from public,anon;
grant execute on function private.lorry_api(text,jsonb) to authenticated;
create or replace function public.lorry_api(action text,payload jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$select private.lorry_api(action,payload);$$;

-- Invitations reserve their advertised truck, using the same driver lock as
-- direct bookings. This prevents two customers assigning the same driver.
alter function private.lorry_customer_api(text,jsonb) rename to lorry_customer_api_before_workflow;
revoke all on function private.lorry_customer_api_before_workflow(text,jsonb) from public,anon,authenticated;
create function private.lorry_customer_api(action text,payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); b public.bookings; a public.truck_availability; result jsonb;
begin
 if uid is null then raise exception 'Please sign in to continue.'; end if;
 if action='customer.invitation.accept' then
   select * into b from public.bookings where id=(payload->>'booking_id')::uuid;
   if b.id is null or b.driver_id<>uid then raise exception 'This invitation is unavailable.'; end if;
   perform 1 from public.loads where id=b.load_id for update;
   select * into b from public.bookings where id=b.id for update;
   select * into a from public.truck_availability where id=b.availability_id;
   perform private.check_booking_truck(uid,a.vehicle_id,b.load_id,b.id,true);
   update public.bookings set vehicle_id=a.vehicle_id,agreed_freight=(select price from public.loads where id=b.load_id) where id=b.id;
 elsif action='tracking.update' then
   if not exists(select 1 from public.bookings where id=(payload->>'booking_id')::uuid
     and driver_id=uid and status='in_transit' and delivery_reported_at is null) then
     raise exception 'Location sharing has ended for this trip.';
   end if;
 end if;
 result:=private.lorry_customer_api_before_workflow(action,payload);
 if action='customer.truck.invite' and result->>'source'='customer_invitation' then
   select * into a from public.truck_availability where id=(payload->>'availability_id')::uuid;
   update public.bookings set vehicle_id=a.vehicle_id,
     agreed_freight=(select price from public.loads where id=(payload->>'load_id')::uuid)
     where id=(result->>'id')::uuid;
   result:=result||private.booking_extra((result->>'id')::uuid);
 end if;
 return result;
end $$;
revoke all on function private.lorry_customer_api(text,jsonb) from public,anon;
grant execute on function private.lorry_customer_api(text,jsonb) to authenticated;
create or replace function public.lorry_customer_api(action text,payload jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$select private.lorry_customer_api(action,payload);$$;

-- Update discovery predicates without replacing unrelated customer features.
do $$declare source text; begin
 select pg_get_functiondef('private.lorry_customer_api_before_workflow(text,jsonb)'::regprocedure) into source;
 source:=replace(source,'select b into booking','select b.* into booking');
 source:=replace(source,'select l into load_row','select l.* into load_row');
 source:=replace(source,'select a into availability','select a.* into availability');
 source:=replace(source,'select v into vehicle','select v.* into vehicle');
 source:=replace(source, 'active_booking.status = ''in_transit''',
   '(active_booking.status = ''accepted'' or (active_booking.status = ''in_transit'' and active_booking.delivery_reported_at is null))');
 execute source;
end $$;

-- The general finance form may not bypass the booking payment checks.
alter function private.lorry_next_api(text,jsonb) rename to lorry_next_api_before_workflow;
revoke all on function private.lorry_next_api_before_workflow(text,jsonb) from public,anon,authenticated;
do $$declare source text; begin
 select pg_get_functiondef('private.lorry_next_api_before_workflow(text,jsonb)'::regprocedure) into source;
 source:=replace(source,'b.driver_id = uid and b.status = ''in_transit''',
   'b.driver_id = uid and (b.status = ''accepted'' or (b.status = ''in_transit'' and b.delivery_reported_at is null))');
 source:=replace(source,'active_booking.status = ''in_transit''',
   '(active_booking.status = ''accepted'' or (active_booking.status = ''in_transit'' and active_booking.delivery_reported_at is null))');
 execute source;
end $$;
create function private.lorry_next_api(action text,payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); result jsonb;
begin
 if uid is null then raise exception 'Please sign in to continue.'; end if;
 if action='tracking.update' then return private.lorry_customer_api(action,payload); end if;
 if action='finance.save' and nullif(payload->>'booking_id','') is not null then
   if not exists(select 1 from public.bookings where id=(payload->>'booking_id')::uuid and driver_id=uid) then raise exception 'Choose one of your bookings.'; end if;
   if payload->>'entry_type'='income' and payload->>'category'='freight' then raise exception 'Record freight collection from Booking details to update the payment balance.'; end if;
 elsif action='availability.save' then
   perform 1 from public.profiles where id=uid for update;
   if exists(select 1 from public.bookings where driver_id=uid and
      (status='accepted' or (status='in_transit' and delivery_reported_at is null))) then
     raise exception 'Finish your assigned trip before posting availability.';
   end if;
 end if;
 result:=private.lorry_next_api_before_workflow(action,payload);
 if action='availability.list' then
   select coalesce(jsonb_agg(item||jsonb_build_object('busy',exists(select 1 from public.bookings b
     where b.driver_id=(item->>'driver_id')::uuid and
       (b.status='accepted' or (b.status='in_transit' and b.delivery_reported_at is null)))) order by ord),'[]')
     into result from jsonb_array_elements(result) with ordinality as rows(item,ord);
 end if;
 return result;
end $$;
revoke all on function private.lorry_next_api(text,jsonb) from public,anon;
grant execute on function private.lorry_next_api(text,jsonb) to authenticated;
create or replace function public.lorry_next_api(action text,payload jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$select private.lorry_next_api(action,payload);$$;


-- ============================================================================
-- Source migration: 20261015154859_driver_load_posting.sql
-- ============================================================================

-- Posting is an ownership capability, not a reason to change account role.
-- Keep existing route validation, edit ownership, trip and payment guards.
do $$
declare source text;
  old_guard text := $guard$if profile.role<>'shipper' then raise exception 'Only shippers may publish loads.'; end if;$guard$;
  new_guard text := $guard$if profile.role not in ('shipper','driver') then raise exception 'Only customers and drivers may publish loads.'; end if;$guard$;
  old_market text := $guard$else ld.status='open' end$guard$;
  new_market text := $guard$else ld.status='open' and ld.shipper_id<>uid end$guard$;
  old_bookings text := $guard$where (bk.driver_id=uid or ld.shipper_id=uid)$guard$;
  new_bookings text := $guard$where (case
    when coalesce((payload->>'incoming')::boolean,false) then ld.shipper_id=uid
    when profile.role='driver' then bk.driver_id=uid
    else ld.shipper_id=uid end)$guard$;
begin
  select pg_get_functiondef('private.lorry_api_before_workflow(text,jsonb)'::regprocedure) into source;
  if position(old_guard in source)=0 or position(old_market in source)=0
     or position(old_bookings in source)=0 then
    raise exception 'Unexpected logistics API definition; review driver posting migration.';
  end if;
  source := replace(source,old_guard,new_guard);
  source := replace(source,old_market,new_market);
  source := replace(source,old_bookings,new_bookings);
  -- Driver home counts should agree with the marketplace excluding own freight.
  source := replace(source,
    '(select count(*) from public.loads where status=''open'')',
    '(select count(*) from public.loads where status=''open'' and shipper_id<>uid)');
  execute source;
end $$;

-- Replacing the private implementation preserves its non-public ACL.
revoke all on function private.lorry_api_before_workflow(text,jsonb) from public,anon,authenticated;


-- ============================================================================
-- Source migration: 20261016150303_compatible_general_cargo_and_custom_lengths.sql
-- ============================================================================

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
