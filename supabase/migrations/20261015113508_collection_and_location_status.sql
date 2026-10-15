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
