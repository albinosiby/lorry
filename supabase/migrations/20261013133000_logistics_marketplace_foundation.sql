-- LORRY LINK marketplace foundation
--
-- This migration is deliberately additive.  Existing loads/bookings continue
-- to use lorry_api; the new tables are protected by RLS and are intended for
-- the next driver/customer workflows and trusted server-side integrations.

-- A person may post loads and also drive. `role` remains the primary role for
-- backwards compatibility with the first release, while these flags describe
-- the capabilities the person has enabled.
alter table public.profiles
  add column if not exists customer_enabled boolean not null default true,
  add column if not exists driver_enabled boolean not null default false,
  add column if not exists preferred_language text not null default 'en'
    check (preferred_language in ('en', 'ml', 'hi')),
  add column if not exists photo_path text,
  add column if not exists address text,
  add column if not exists company_name text,
  add column if not exists verification_status text not null default 'pending'
    check (verification_status in ('pending', 'submitted', 'verified', 'rejected')),
  add column if not exists updated_at timestamptz not null default now();

update public.profiles
set customer_enabled = (role = 'shipper'),
    driver_enabled = (role = 'driver')
where (role = 'shipper' and not customer_enabled)
   or (role = 'driver' and not driver_enabled);

-- Phone is an operational contact detail. Keep the validation in a trigger so
-- every RPC and future admin tool gets the same server-side guarantee.
create or replace function private.require_profile_phone()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if length(trim(coalesce(new.phone, ''))) = 0 then
    raise exception 'Phone number is required.';
  end if;
  if new.phone !~ '^\\+?[0-9 ()-]{7,25}$' then
    raise exception 'Enter a valid phone number.';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_require_phone on public.profiles;
create trigger profiles_require_phone
before insert or update of phone, name, preferred_language, photo_path, address, company_name
on public.profiles for each row execute function private.require_profile_phone();

-- Freight fields used by customer load posting and driver matching.
alter table public.loads
  add column if not exists weight_tonnes numeric(8,2) not null default 1
    check (weight_tonnes > 0 and weight_tonnes <= 100),
  add column if not exists required_vehicle_length_ft numeric(6,2),
  add column if not exists pickup_at timestamptz,
  add column if not exists special_note text not null default ''
    check (length(special_note) <= 1000),
  add column if not exists pickup_latitude numeric(9,6),
  add column if not exists pickup_longitude numeric(9,6),
  add column if not exists destination_latitude numeric(9,6),
  add column if not exists destination_longitude numeric(9,6),
  add constraint loads_pickup_latitude_range
    check (pickup_latitude is null or pickup_latitude between -90 and 90),
  add constraint loads_pickup_longitude_range
    check (pickup_longitude is null or pickup_longitude between -180 and 180),
  add constraint loads_destination_latitude_range
    check (destination_latitude is null or destination_latitude between -90 and 90),
  add constraint loads_destination_longitude_range
    check (destination_longitude is null or destination_longitude between -180 and 180);

create index if not exists loads_matching_idx on public.loads
  (status, vehicle, weight_tonnes, required_vehicle_length_ft, pickup_date);

-- Keep the established lorry_api command contract, but include the new load
-- fields in its existing create/edit commands. This is a targeted source
-- replacement so deployments that used the core migration do not lose its
-- concurrency and transition guarantees.
do $$
declare
  function_definition text;
  old_insert constant text := $sql$insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,contact_preference)
     values((payload->>'id')::uuid,uid,payload->>'pickup',payload->>'destination',trim(payload->>'cargo'),payload->>'vehicle',(payload->>'pickup_date')::date,(payload->>'price')::numeric,coalesce(payload->>'contact_preference','after_acceptance')) returning * into l;$sql$;
  new_insert constant text := $sql$insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,contact_preference,weight_tonnes,required_vehicle_length_ft,pickup_at,special_note)
     values((payload->>'id')::uuid,uid,payload->>'pickup',payload->>'destination',trim(payload->>'cargo'),payload->>'vehicle',(payload->>'pickup_date')::date,(payload->>'price')::numeric,coalesce(payload->>'contact_preference','after_acceptance'),coalesce((payload->>'weight_tonnes')::numeric,1),(payload->>'required_vehicle_length_ft')::numeric,(payload->>'pickup_at')::timestamptz,coalesce(trim(payload->>'special_note'),'')) returning * into l;$sql$;
  old_update constant text := $sql$update public.loads set pickup=payload->>'pickup',destination=payload->>'destination',cargo=trim(payload->>'cargo'),vehicle=payload->>'vehicle',pickup_date=(payload->>'pickup_date')::date,price=(payload->>'price')::numeric,contact_preference=payload->>'contact_preference',updated_at=now() where id=l.id returning * into l;$sql$;
  new_update constant text := $sql$update public.loads set pickup=payload->>'pickup',destination=payload->>'destination',cargo=trim(payload->>'cargo'),vehicle=payload->>'vehicle',pickup_date=(payload->>'pickup_date')::date,price=(payload->>'price')::numeric,contact_preference=payload->>'contact_preference',weight_tonnes=coalesce((payload->>'weight_tonnes')::numeric,1),required_vehicle_length_ft=(payload->>'required_vehicle_length_ft')::numeric,pickup_at=(payload->>'pickup_at')::timestamptz,special_note=coalesce(trim(payload->>'special_note'),''),updated_at=now() where id=l.id returning * into l;$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  if position(old_insert in function_definition) = 0
      or position(old_update in function_definition) = 0 then
    raise exception 'Could not upgrade lorry_api load commands. Apply the core LORRY LINK migration before this migration.';
  end if;
  function_definition := replace(function_definition, old_insert, new_insert);
  function_definition := replace(function_definition, old_update, new_update);
  execute function_definition;
end
$$;

-- Driver vehicle and verification records. A driver can register several
-- vehicles but only one is normally marked available at a time.
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  registration_number text not null,
  vehicle_type text not null check (vehicle_type in ('Mini truck', 'Pickup', 'LCV', 'Open truck', 'Container', 'Trailer', 'Refrigerated')),
  body_type text not null default 'Open truck',
  length_ft numeric(6,2) not null check (length_ft > 0 and length_ft <= 80),
  capacity_tonnes numeric(8,2) not null check (capacity_tonnes > 0 and capacity_tonnes <= 100),
  is_default boolean not null default false,
  verification_status text not null default 'pending' check (verification_status in ('pending', 'submitted', 'verified', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, registration_number)
);
create unique index if not exists one_default_vehicle_per_driver
  on public.vehicles(owner_id) where is_default;
create index if not exists vehicles_match_idx
  on public.vehicles(vehicle_type, capacity_tonnes, length_ft);

create table if not exists public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete cascade,
  document_type text not null check (document_type in ('identity', 'driving_license', 'vehicle_registration', 'insurance', 'permit', 'fitness_certificate')),
  storage_path text not null,
  status text not null default 'submitted' check (status in ('submitted', 'verified', 'rejected')),
  rejection_reason text,
  expires_on date,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists driver_documents_owner_idx on public.driver_documents(driver_id, created_at desc);

-- Availability is a driver post, not a load. It is the reverse marketplace
-- path: a customer can invite an appropriate available truck.
create table if not exists public.truck_availability (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  current_location text not null check (length(trim(current_location)) >= 2),
  latitude numeric(9,6),
  longitude numeric(9,6),
  preferred_destination text,
  available_from timestamptz not null,
  available_until timestamptz,
  note text not null default '' check (length(note) <= 500),
  status text not null default 'open' check (status in ('open', 'matched', 'closed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180),
  check (available_until is null or available_until > available_from)
);
create index if not exists truck_availability_discovery_idx
  on public.truck_availability(status, available_from, vehicle_id);
create index if not exists truck_availability_driver_idx
  on public.truck_availability(driver_id, created_at desc);

-- Live location is retained as the latest point only. A background worker or
-- authenticated Edge Function writes it after validating the active booking;
-- the client never receives a service-role key.
create table if not exists public.active_trip_locations (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  latitude numeric(9,6) not null check (latitude between -90 and 90),
  longitude numeric(9,6) not null check (longitude between -180 and 180),
  accuracy_meters numeric(8,2),
  heading_degrees numeric(6,2) check (heading_degrees is null or heading_degrees between 0 and 360),
  recorded_at timestamptz not null,
  received_at timestamptz not null default now()
);
create index if not exists active_trip_locations_driver_idx on public.active_trip_locations(driver_id, recorded_at desc);

create table if not exists public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete set null,
  entry_type text not null check (entry_type in ('income', 'expense')),
  category text not null check (category in ('freight', 'fuel', 'toll', 'maintenance', 'driver_allowance', 'other')),
  amount numeric(12,2) not null check (amount > 0),
  occurred_on date not null default current_date,
  note text not null default '' check (length(note) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists finance_entries_driver_idx on public.finance_entries(driver_id, occurred_on desc);

-- This is a short-lived cache filled by the protected Nearby Services Edge
-- Function. Google Places keys stay in function secrets; cached result data is
-- safe for signed-in users and lets us limit paid provider calls.
create table if not exists public.nearby_service_cache (
  id uuid primary key default gen_random_uuid(),
  provider_place_id text not null,
  service_type text not null check (service_type in ('fuel', 'truck_stop', 'weighbridge', 'workshop', 'tyre', 'hospital')),
  name text not null,
  address text,
  latitude numeric(9,6) not null check (latitude between -90 and 90),
  longitude numeric(9,6) not null check (longitude between -180 and 180),
  rating numeric(3,2),
  is_open_now boolean,
  refreshed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique(provider_place_id, service_type)
);
create index if not exists nearby_service_cache_lookup_idx
  on public.nearby_service_cache(service_type, expires_at);

alter table public.vehicles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.truck_availability enable row level security;
alter table public.active_trip_locations enable row level security;
alter table public.finance_entries enable row level security;
alter table public.nearby_service_cache enable row level security;

-- No direct client writes. Command/Edge APIs own all mutations and verify the
-- active role and booking transition first.
revoke all on public.vehicles, public.driver_documents, public.truck_availability,
  public.active_trip_locations, public.finance_entries, public.nearby_service_cache
  from anon, authenticated;
grant select on public.active_trip_locations, public.nearby_service_cache to authenticated;

create policy active_trip_location_for_booking_party on public.active_trip_locations
  for select to authenticated using (
    exists (
      select 1 from public.bookings b
      join public.loads l on l.id = b.load_id
      where b.id = booking_id
        and (b.driver_id = (select auth.uid()) or l.shipper_id = (select auth.uid()))
    )
  );
create policy nearby_service_cache_for_signed_in_users on public.nearby_service_cache
  for select to authenticated using ((select auth.uid()) is not null);

-- Database Changes after October 2026 require explicit API exposure. Grants
-- above intentionally expose only the two safe read models; all other data is
-- returned by role-scoped RPC/Edge Function responses.

create or replace function private.lorry_next_api(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  profile public.profiles;
  vehicle public.vehicles;
  availability public.truck_availability;
  finance public.finance_entries;
  result jsonb;
begin
  if uid is null then
    raise exception 'Please sign in to continue.';
  end if;
  select * into profile from public.profiles where id = uid;
  if profile.id is null then
    raise exception 'Complete your profile first.';
  end if;

  if action = 'profile.details.save' then
    if length(trim(coalesce(payload->>'phone', ''))) = 0 then
      raise exception 'Phone number is required.';
    end if;
    update public.profiles set
      phone = trim(payload->>'phone'),
      preferred_language = coalesce(nullif(payload->>'preferred_language', ''), preferred_language),
      photo_path = nullif(trim(payload->>'photo_path'), ''),
      address = nullif(trim(payload->>'address'), ''),
      company_name = nullif(trim(payload->>'company_name'), ''),
      customer_enabled = coalesce((payload->>'customer_enabled')::boolean, customer_enabled),
      driver_enabled = coalesce((payload->>'driver_enabled')::boolean, driver_enabled)
    where id = uid
    returning * into profile;
    if not profile.customer_enabled and not profile.driver_enabled then
      raise exception 'Enable customer or driver access.';
    end if;
    return to_jsonb(profile);
  end if;

  if action like 'vehicles.%' or action like 'availability.%' or action like 'finance.%' or action = 'documents.list' then
    if profile.role <> 'driver' and not profile.driver_enabled then
      raise exception 'Enable the driver profile to use this feature.';
    end if;
  end if;

  if action = 'vehicles.list' then
    select coalesce(jsonb_agg(to_jsonb(v) order by v.is_default desc, v.created_at desc), '[]'::jsonb)
      into result from public.vehicles v where v.owner_id = uid;
    return result;
  end if;

  if action = 'vehicles.save' then
    if coalesce(payload->>'vehicle_type', '') not in ('Mini truck', 'Pickup', 'LCV', 'Open truck', 'Container', 'Trailer', 'Refrigerated') then
      raise exception 'Choose a valid vehicle type.';
    end if;
    if length(trim(coalesce(payload->>'registration_number', ''))) < 4 then
      raise exception 'Enter a valid vehicle registration number.';
    end if;
    if coalesce((payload->>'length_ft')::numeric, 0) <= 0 or coalesce((payload->>'capacity_tonnes')::numeric, 0) <= 0 then
      raise exception 'Vehicle length and capacity must be greater than zero.';
    end if;
    if coalesce((payload->>'is_default')::boolean, false) then
      update public.vehicles set is_default = false, updated_at = now() where owner_id = uid;
    end if;
    if nullif(payload->>'id', '') is null then
      insert into public.vehicles(owner_id, registration_number, vehicle_type, body_type, length_ft, capacity_tonnes, is_default)
      values (uid, upper(trim(payload->>'registration_number')), payload->>'vehicle_type', coalesce(nullif(trim(payload->>'body_type'), ''), payload->>'vehicle_type'), (payload->>'length_ft')::numeric, (payload->>'capacity_tonnes')::numeric, coalesce((payload->>'is_default')::boolean, false))
      returning * into vehicle;
    else
      update public.vehicles set
        registration_number = upper(trim(payload->>'registration_number')),
        vehicle_type = payload->>'vehicle_type',
        body_type = coalesce(nullif(trim(payload->>'body_type'), ''), payload->>'vehicle_type'),
        length_ft = (payload->>'length_ft')::numeric,
        capacity_tonnes = (payload->>'capacity_tonnes')::numeric,
        is_default = coalesce((payload->>'is_default')::boolean, is_default),
        updated_at = now()
      where id = (payload->>'id')::uuid and owner_id = uid
      returning * into vehicle;
      if vehicle.id is null then
        raise exception 'This vehicle is unavailable.';
      end if;
    end if;
    return to_jsonb(vehicle);
  end if;

  if action = 'availability.list' then
    if coalesce((payload->>'mine')::boolean, false) then
      select coalesce(jsonb_agg(to_jsonb(a) order by a.available_from asc), '[]'::jsonb)
        into result from public.truck_availability a where a.driver_id = uid;
    else
      select coalesce(jsonb_agg(to_jsonb(x) order by x.available_from asc), '[]'::jsonb)
        into result from (
          select a.*, jsonb_build_object(
            'vehicle_type', v.vehicle_type,
            'length_ft', v.length_ft,
            'capacity_tonnes', v.capacity_tonnes,
            'verification_status', v.verification_status,
            'driver_name', p.name,
            'driver_photo_path', p.photo_path
          ) as vehicle
          from public.truck_availability a
          join public.vehicles v on v.id = a.vehicle_id
          join public.profiles p on p.id = a.driver_id
          where a.status = 'open' and a.available_from <= now() + interval '30 days'
        ) x;
    end if;
    return result;
  end if;

  if action = 'availability.save' then
    select * into vehicle from public.vehicles where id = (payload->>'vehicle_id')::uuid and owner_id = uid;
    if vehicle.id is null then
      raise exception 'Choose one of your registered vehicles.';
    end if;
    if length(trim(coalesce(payload->>'current_location', ''))) < 2 then
      raise exception 'Enter your current location.';
    end if;
    if nullif(payload->>'id', '') is null then
      insert into public.truck_availability(driver_id, vehicle_id, current_location, latitude, longitude, preferred_destination, available_from, available_until, note)
      values (uid, vehicle.id, trim(payload->>'current_location'), (payload->>'latitude')::numeric, (payload->>'longitude')::numeric, nullif(trim(payload->>'preferred_destination'), ''), coalesce((payload->>'available_from')::timestamptz, now()), (payload->>'available_until')::timestamptz, coalesce(trim(payload->>'note'), ''))
      returning * into availability;
    else
      update public.truck_availability set
        vehicle_id = vehicle.id,
        current_location = trim(payload->>'current_location'),
        latitude = (payload->>'latitude')::numeric,
        longitude = (payload->>'longitude')::numeric,
        preferred_destination = nullif(trim(payload->>'preferred_destination'), ''),
        available_from = coalesce((payload->>'available_from')::timestamptz, available_from),
        available_until = (payload->>'available_until')::timestamptz,
        note = coalesce(trim(payload->>'note'), ''),
        status = 'open', updated_at = now()
      where id = (payload->>'id')::uuid and driver_id = uid and status = 'open'
      returning * into availability;
      if availability.id is null then
        raise exception 'Only your open availability posts can be edited.';
      end if;
    end if;
    return to_jsonb(availability);
  end if;

  if action = 'availability.close' then
    update public.truck_availability set status = 'closed', updated_at = now()
      where id = (payload->>'id')::uuid and driver_id = uid and status = 'open';
    return '{}'::jsonb;
  end if;

  if action = 'finance.list' then
    select coalesce(jsonb_agg(to_jsonb(f) order by f.occurred_on desc, f.created_at desc), '[]'::jsonb)
      into result from public.finance_entries f where f.driver_id = uid;
    return result;
  end if;
  if action = 'finance.save' then
    if coalesce(payload->>'entry_type', '') not in ('income', 'expense') or coalesce((payload->>'amount')::numeric, 0) <= 0 then
      raise exception 'Enter a valid finance entry.';
    end if;
    insert into public.finance_entries(driver_id, booking_id, entry_type, category, amount, occurred_on, note)
    values (uid, nullif(payload->>'booking_id', '')::uuid, payload->>'entry_type', coalesce(nullif(payload->>'category', ''), 'other'), (payload->>'amount')::numeric, coalesce((payload->>'occurred_on')::date, current_date), coalesce(trim(payload->>'note'), ''))
    returning * into finance;
    return to_jsonb(finance);
  end if;

  if action = 'documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.driver_documents d where d.driver_id = uid;
    return result;
  end if;

  if action = 'tracking.get' then
    select coalesce(to_jsonb(t), '{}'::jsonb) into result
    from public.active_trip_locations t
    join public.bookings b on b.id = t.booking_id
    join public.loads l on l.id = b.load_id
    where t.booking_id = (payload->>'booking_id')::uuid
      and (b.driver_id = uid or l.shipper_id = uid);
    return result;
  end if;
  raise exception 'Unsupported marketplace action.';
end;
$$;
revoke all on function private.lorry_next_api(text,jsonb) from public, anon, authenticated;
grant execute on function private.lorry_next_api(text,jsonb) to authenticated;
create or replace function public.lorry_next_api(action text, payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.lorry_next_api(action, payload);
$$;
revoke all on function public.lorry_next_api(text,jsonb) from public, anon;
grant execute on function public.lorry_next_api(text,jsonb) to authenticated;
