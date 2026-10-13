
-- All client mutations pass through the authenticated command API. The private
-- function owns transactions; every branch checks identity, role and ownership.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check (length(trim(name)) between 2 and 80),
 role text not null check (role in ('shipper','driver')),
 phone text not null default '' check (length(phone)<=25),
 created_at timestamptz not null default now()
);
create table public.loads (
 id uuid primary key default gen_random_uuid(), shipper_id uuid not null references public.profiles(id),
 pickup text not null, destination text not null,
 cargo text not null check(length(trim(cargo)) between 3 and 2000),
 vehicle text not null check(vehicle in ('Mini truck','Pickup','LCV','Open truck','Container','Trailer','Refrigerated')),
 pickup_date date not null, price numeric(12,2) check(price>=0), currency text not null default 'INR' check(currency='INR'),
 contact_preference text not null default 'after_acceptance' check(contact_preference in ('after_acceptance','phone')),
 status text not null default 'open' check(status in ('open','assigned','in_transit','completed','cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(pickup<>destination)
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(), load_id uuid not null references public.loads(id),
 driver_id uuid not null references public.profiles(id),
 status text not null default 'requested' check(status in ('requested','accepted','in_transit','completed','declined','cancelled')),
 delivery_reported_at timestamptz, reason text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(load_id,driver_id)
);
create unique index one_assigned_driver_per_load on public.bookings(load_id) where status in ('accepted','in_transit','completed');
create index loads_owner_idx on public.loads(shipper_id,created_at desc);
create index loads_discovery_idx on public.loads(status,pickup,destination,vehicle,pickup_date);
create index bookings_driver_idx on public.bookings(driver_id,created_at desc);
create index bookings_load_idx on public.bookings(load_id);
create table public.booking_events (
 id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id),
 actor_id uuid not null references public.profiles(id), status text not null, note text not null default '',
 created_at timestamptz not null default now()
);
create index booking_events_booking_idx on public.booking_events(booking_id,created_at);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references public.profiles(id),
 title text not null, body text not null, load_id uuid references public.loads(id), booking_id uuid references public.bookings(id),
 created_at timestamptz not null default now(), read_at timestamptz
);
create index notifications_recipient_idx on public.notifications(recipient_id,created_at desc);
alter table public.profiles enable row level security;
alter table public.loads enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_events enable row level security;
alter table public.notifications enable row level security;
-- No client INSERT/UPDATE/DELETE grants: direct writes cannot bypass transitions.
revoke all on public.profiles, public.loads, public.bookings, public.booking_events, public.notifications from anon, authenticated;
grant select on public.profiles, public.loads, public.bookings, public.notifications to authenticated;
create policy own_profile on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy visible_loads on public.loads for select to authenticated using (status='open' or shipper_id=(select auth.uid()));
create policy own_bookings on public.bookings for select to authenticated using (driver_id=(select auth.uid()));
create policy own_notifications on public.notifications for select to authenticated using (recipient_id=(select auth.uid()));

create function private.lorry_api(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid := auth.uid(); profile public.profiles; l public.loads; b public.bookings;
 result jsonb; target uuid; item record; next_status text; count_rows integer;
begin
 if uid is null then raise exception 'Please sign in to continue.'; end if;
 if not exists(select 1 from auth.users where id=uid) then raise exception 'This account no longer exists.'; end if;
 select * into profile from public.profiles where id=uid;
 if action='profile.get' then if profile.id is null then return null; end if; return to_jsonb(profile); end if;
 if action='profile.save' then
   if length(trim(coalesce(payload->>'name',''))) not between 2 and 80 then raise exception 'Enter a name between 2 and 80 characters.'; end if;
   if profile.id is null then
     if coalesce(payload->>'role','') not in ('shipper','driver') then raise exception 'Choose a valid role.'; end if;
     insert into public.profiles(id,name,role,phone) values(uid,trim(payload->>'name'),payload->>'role',coalesce(payload->>'phone','')) returning * into profile;
   else
     update public.profiles set name=trim(payload->>'name'),phone=coalesce(payload->>'phone','') where id=uid returning * into profile;
   end if;
   return to_jsonb(profile);
 end if;
 if profile.id is null then raise exception 'Complete your profile first.'; end if;
 if action='loads.list' then
   select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into result from (
     select ld.*, (select count(*) from public.bookings bk where bk.load_id=ld.id and bk.status='requested' and ld.shipper_id=uid) as request_count
     from public.loads ld
     where (case when coalesce((payload->>'mine')::boolean,false) then ld.shipper_id=uid else ld.status='open' end)
       and (nullif(payload->>'pickup','') is null or ld.pickup=payload->>'pickup')
       and (nullif(payload->>'destination','') is null or ld.destination=payload->>'destination')
       and (nullif(payload->>'vehicle','') is null or ld.vehicle=payload->>'vehicle')
       and (nullif(payload->>'status','') is null or ld.status=payload->>'status')
     order by ld.created_at desc,ld.id limit 20 offset greatest(0,coalesce((payload->>'offset')::integer,0))
   ) x;
   return result;
 end if;
 if action='loads.get' then
   select * into l from public.loads where id=(payload->>'id')::uuid;
   if l.id is null or not (l.status='open' or l.shipper_id=uid or exists(select 1 from public.bookings where load_id=l.id and driver_id=uid)) then raise exception 'This load is unavailable.'; end if;
   select id into target from public.bookings where load_id=l.id and ((l.shipper_id=uid and status in ('accepted','in_transit','completed')) or driver_id=uid) limit 1;
   return to_jsonb(l) || jsonb_build_object('booking_id',target,'owner_name',(select name from public.profiles where id=l.shipper_id),'owner_phone',case when l.contact_preference='phone' then (select phone from public.profiles where id=l.shipper_id) else '' end);
 end if;
 if action in ('loads.create','loads.edit') then
   if profile.role<>'shipper' then raise exception 'Only shippers may publish loads.'; end if;
  if length(trim(coalesce(payload->>'pickup',''))) < 2 or length(trim(coalesce(payload->>'destination',''))) < 2 or lower(trim(payload->>'pickup'))=lower(trim(payload->>'destination')) then raise exception 'Choose different pickup and destination places.'; end if;
   if (payload->>'pickup_date')::date < (now() at time zone 'Asia/Kolkata')::date then raise exception 'Pickup date cannot be in the past.'; end if;
   if action='loads.create' then
     -- A client-generated ID makes a timed-out publish safe to retry.
     select * into l from public.loads where id=(payload->>'id')::uuid;
     if l.id is not null then
       if l.shipper_id<>uid then raise exception 'This load identifier is unavailable.'; end if;
       return to_jsonb(l);
     end if;
     insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,contact_preference)
     values((payload->>'id')::uuid,uid,payload->>'pickup',payload->>'destination',trim(payload->>'cargo'),payload->>'vehicle',(payload->>'pickup_date')::date,(payload->>'price')::numeric,coalesce(payload->>'contact_preference','after_acceptance')) returning * into l;
   else
     select * into l from public.loads where id=(payload->>'id')::uuid for update;
     if l.id is null or l.shipper_id<>uid or l.status<>'open' then raise exception 'Only your open loads can be edited.'; end if;
     if exists(select 1 from public.bookings where load_id=l.id and status='requested') then raise exception 'Resolve pending requests before changing this load.'; end if;
     update public.loads set pickup=payload->>'pickup',destination=payload->>'destination',cargo=trim(payload->>'cargo'),vehicle=payload->>'vehicle',pickup_date=(payload->>'pickup_date')::date,price=(payload->>'price')::numeric,contact_preference=payload->>'contact_preference',updated_at=now() where id=l.id returning * into l;
   end if;
   return to_jsonb(l);
 end if;
 if action='loads.cancel' then
   select * into l from public.loads where id=(payload->>'id')::uuid for update;
   if l.id is null or l.shipper_id<>uid then raise exception 'You cannot cancel this load.'; end if;
   if l.status='cancelled' then return '{}'::jsonb; end if;
   if l.status<>'open' then raise exception 'Cancel the accepted booking instead.'; end if;
   update public.loads set status='cancelled',updated_at=now() where id=l.id;
   for item in update public.bookings set status='cancelled',reason='Load cancelled by shipper',updated_at=now() where load_id=l.id and status='requested' returning * loop
     insert into public.booking_events(booking_id,actor_id,status,note) values(item.id,uid,'cancelled','Load cancelled by shipper');
     insert into public.notifications(recipient_id,title,body,load_id,booking_id) values(item.driver_id,'Load cancelled',l.pickup||' to '||l.destination,l.id,item.id);
   end loop;
   return '{}'::jsonb;
 end if;
 if action='bookings.request' then
   if profile.role<>'driver' then raise exception 'Only transporters and drivers can request a booking.'; end if;
   select * into l from public.loads where id=(payload->>'load_id')::uuid for update;
   select * into b from public.bookings where load_id=l.id and driver_id=uid;
   if b.id is not null then return to_jsonb(b); end if;
   if l.id is null or l.status<>'open' or l.shipper_id=uid then raise exception 'This load is no longer available.'; end if;
   insert into public.bookings(load_id,driver_id) values(l.id,uid) returning * into b;
   insert into public.booking_events(booking_id,actor_id,status) values(b.id,uid,'requested');
   insert into public.notifications(recipient_id,title,body,load_id,booking_id) values(l.shipper_id,'New booking request',profile.name||' requested your load',l.id,b.id);
   return to_jsonb(b);
 end if;
 if action='bookings.list' then
   select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
     select bk.*,to_jsonb(ld) as load,p.name as driver_name from public.bookings bk join public.loads ld on ld.id=bk.load_id join public.profiles p on p.id=bk.driver_id
     where (bk.driver_id=uid or ld.shipper_id=uid)
     and (nullif(payload->>'load_id','') is null or bk.load_id=(payload->>'load_id')::uuid)
     and (nullif(payload->>'status','') is null or bk.status=payload->>'status')
     order by bk.created_at desc,bk.id limit 20 offset greatest(0,coalesce((payload->>'offset')::integer,0))
   ) x;
   return result;
 end if;
 if action='bookings.get' then
   select * into b from public.bookings where id=(payload->>'id')::uuid;
   select * into l from public.loads where id=b.load_id;
   if b.id is null or (b.driver_id<>uid and l.shipper_id<>uid) then raise exception 'This booking is unavailable.'; end if;
   target:=case when uid=b.driver_id then l.shipper_id else b.driver_id end;
   return to_jsonb(b)||jsonb_build_object('load',to_jsonb(l),'driver_name',(select name from public.profiles where id=b.driver_id),'other_name',(select name from public.profiles where id=target),'other_phone',case when b.status in ('accepted','in_transit','completed') then (select phone from public.profiles where id=target) else '' end,'events',(select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at),'[]'::jsonb) from public.booking_events e where e.booking_id=b.id));
 end if;
 if action='bookings.transition' then
   -- Every booking operation locks the load FIRST to serialize competing requests.
   select load_id into target from public.bookings where id=(payload->>'id')::uuid;
   select * into l from public.loads where id=target for update;
   select * into b from public.bookings where id=(payload->>'id')::uuid for update;
   if b.id is null or (b.driver_id<>uid and l.shipper_id<>uid) then raise exception 'This booking is unavailable.'; end if;
   next_status:=payload->>'status';
   if next_status in ('accepted','declined') then
     if l.shipper_id<>uid then raise exception 'Only the load owner can decide requests.'; end if;
     if b.status=next_status then return '{}'::jsonb; end if;
     if b.status<>'requested' or l.status<>'open' then raise exception 'This request has already changed. Refresh and try again.'; end if;
     if next_status='accepted' then
       update public.loads set status='assigned',updated_at=now() where id=l.id;
       for item in update public.bookings set status='declined',reason='Another driver was selected',updated_at=now() where load_id=l.id and id<>b.id and status='requested' returning * loop
         insert into public.booking_events(booking_id,actor_id,status,note) values(item.id,uid,'declined','Another driver was selected');
         insert into public.notifications(recipient_id,title,body,load_id,booking_id) values(item.driver_id,'Booking declined','Another driver was selected',l.id,item.id);
       end loop;
     end if;
   elsif next_status='in_transit' then
     if b.driver_id<>uid then raise exception 'Only the assigned driver can start a trip.'; end if;
     if b.status='in_transit' then return '{}'::jsonb; end if;
     if b.status<>'accepted' then raise exception 'Only accepted trips can be started.'; end if;
     update public.loads set status='in_transit',updated_at=now() where id=l.id;
   elsif next_status='delivery_reported' then
     if b.driver_id<>uid or b.status<>'in_transit' then raise exception 'Only the driver of an active trip can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'::jsonb; end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;
   elsif next_status='completed' then
     if l.shipper_id<>uid then raise exception 'Only the shipper can confirm delivery.'; end if;
     if b.status='completed' then return '{}'::jsonb; end if;
     if b.status<>'in_transit' or b.delivery_reported_at is null then raise exception 'The driver must report delivery before you confirm it.'; end if;
     update public.loads set status='completed',updated_at=now() where id=l.id;
   elsif next_status='cancelled' then
     if b.status='cancelled' then return '{}'::jsonb; end if;
     if b.status not in ('requested','accepted') then raise exception 'Active or finished trips cannot be cancelled here.'; end if;
     if b.status='requested' and b.driver_id<>uid then raise exception 'Decline this request instead.'; end if;
     if length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'Please provide a cancellation reason.'; end if;
     if b.status='accepted' then update public.loads set status='cancelled',updated_at=now() where id=l.id; end if;
   else raise exception 'Unsupported booking action.';
   end if;
   if next_status<>'delivery_reported' then update public.bookings set status=next_status,reason=payload->>'reason',updated_at=now() where id=b.id; end if;
   insert into public.booking_events(booking_id,actor_id,status,note) values(b.id,uid,next_status,coalesce(payload->>'reason',''));
   target:=case when uid=b.driver_id then l.shipper_id else b.driver_id end;
   insert into public.notifications(recipient_id,title,body,load_id,booking_id) values(target,'Booking '||replace(next_status,'_',' '),l.pickup||' to '||l.destination,l.id,b.id);
   return '{}'::jsonb;
 end if;
 if action='notifications.list' then
   select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (select * from public.notifications where recipient_id=uid order by created_at desc,id limit 20 offset greatest(0,coalesce((payload->>'offset')::integer,0))) x;
   return result;
 end if;
 if action='notifications.read' then
   update public.notifications set read_at=coalesce(read_at,now()) where recipient_id=uid and (nullif(payload->>'id','') is null or id=(payload->>'id')::uuid);
   return '{}'::jsonb;
 end if;
 if action='home.get' then
   if profile.role='shipper' then
     select jsonb_build_object('open_count',count(*) filter(where status='open'),'active_count',count(*) filter(where status in ('assigned','in_transit')),'completed_count',count(*) filter(where status='completed')) into result from public.loads where shipper_id=uid;
     select count(*) into count_rows from public.bookings bk join public.loads ld on ld.id=bk.load_id where ld.shipper_id=uid and bk.status='requested';
   else
     select jsonb_build_object('open_count',(select count(*) from public.loads where status='open'),'active_count',count(*) filter(where status in ('accepted','in_transit')),'completed_count',count(*) filter(where status='completed')) into result from public.bookings where driver_id=uid;
     select count(*) into count_rows from public.bookings where driver_id=uid and status='requested';
   end if;
   return result||jsonb_build_object('pending_count',count_rows,'unread_count',(select count(*) from public.notifications where recipient_id=uid and read_at is null),'loads',private.lorry_api('loads.list',jsonb_build_object('mine',profile.role='shipper')));
 end if;
 raise exception 'Unsupported action.';
end $$;
revoke all on function private.lorry_api(text,jsonb) from public,anon,authenticated;
grant execute on function private.lorry_api(text,jsonb) to authenticated;
create function public.lorry_api(action text,payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.lorry_api(action,payload); $$;
revoke all on function public.lorry_api(text,jsonb) from public,anon;
grant execute on function public.lorry_api(text,jsonb) to authenticated;
