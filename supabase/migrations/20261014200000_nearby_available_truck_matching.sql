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
