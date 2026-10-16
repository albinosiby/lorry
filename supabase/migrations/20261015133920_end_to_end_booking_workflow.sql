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
