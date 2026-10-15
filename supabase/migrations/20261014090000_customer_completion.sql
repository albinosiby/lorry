-- Customer completion: private verification documents, customer truck
-- discovery/invitations, and strictly scoped active-trip location commands.

alter table public.bookings
  add column if not exists source text not null default 'driver_request'
    check (source in ('driver_request', 'customer_invitation'));

create table if not exists public.profile_documents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  document_type text not null check (document_type in ('identity')),
  storage_path text not null unique,
  status text not null default 'submitted'
    check (status in ('submitted', 'verified', 'rejected')),
  rejection_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists profile_documents_profile_idx
  on public.profile_documents(profile_id, created_at desc);
alter table public.profile_documents enable row level security;
revoke all on public.profile_documents from anon, authenticated;

-- Private bucket: files are only selected/uploaded by their owning account.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-documents', 'profile-documents', false, 8388608,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update set public = false;

drop policy if exists profile_documents_upload_own on storage.objects;
create policy profile_documents_upload_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
drop policy if exists profile_documents_read_own on storage.objects;
create policy profile_documents_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

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
begin
  if uid is null then raise exception 'Please sign in to continue.'; end if;
  select * into profile from public.profiles where id = uid;
  if profile.id is null then raise exception 'Complete your profile first.'; end if;

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
    select coalesce(jsonb_agg(to_jsonb(x) order by x.available_from asc), '[]'::jsonb)
      into result from (
        select
          a.*,
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
        where a.status = 'open'
          and a.available_from <= now() + interval '30 days'
          and (nullif(trim(payload->>'location'), '') is null
            or lower(a.current_location) like '%' || lower(trim(payload->>'location')) || '%')
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
    select a into availability
      from public.truck_availability a
      where a.id = (payload->>'availability_id')::uuid and a.status = 'open' for update;
    select v into vehicle from public.vehicles v where v.id = availability.vehicle_id;
    if availability.id is null or vehicle.id is null then
      raise exception 'This truck is no longer available.';
    end if;
    if vehicle.capacity_tonnes < load_row.weight_tonnes
       or (load_row.required_vehicle_length_ft is not null
         and vehicle.length_ft < load_row.required_vehicle_length_ft) then
      raise exception 'This truck does not meet the load capacity or length requirement.';
    end if;
    select * into booking from public.bookings
      where load_id = load_row.id and driver_id = availability.driver_id for update;
    if booking.id is null then
      insert into public.bookings(load_id, driver_id, source)
      values (load_row.id, availability.driver_id, 'customer_invitation')
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
    select * into load_row from public.loads where id = booking.load_id for update;
    if booking.id is null or booking.driver_id <> uid or booking.source <> 'customer_invitation'
       or booking.status <> 'requested' or load_row.status <> 'open' then
      raise exception 'This invitation is no longer available.';
    end if;
    update public.bookings set status = 'accepted', updated_at = now() where id = booking.id;
    update public.loads set status = 'assigned', updated_at = now() where id = load_row.id;
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
    select b into booking from public.bookings b
      where b.id = (payload->>'booking_id')::uuid for update;
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

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
