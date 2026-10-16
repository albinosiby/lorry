-- Run inside BEGIN/ROLLBACK. Never retain test accounts or freight.
do $$
<<qa>>
declare owner_id uuid:=gen_random_uuid(); carrier_id uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid();
  freight_id uuid:=gen_random_uuid(); spare_id uuid:=gen_random_uuid(); truck_id uuid:=gen_random_uuid();
  booking_id uuid; answer jsonb; draft jsonb; rejected boolean;
begin
  insert into auth.users(id,email) values
    (owner_id,owner_id::text||'@driver-posting.invalid'),
    (carrier_id,carrier_id::text||'@driver-posting.invalid'),
    (other_id,other_id::text||'@driver-posting.invalid');
  insert into public.profiles(id,name,role,phone,address,driver_enabled,customer_enabled) values
    (owner_id,'QA driver owner','driver','9999999991','QA',true,false),
    (carrier_id,'QA carrier','driver','9999999992','QA',true,false),
    (other_id,'QA outsider','driver','9999999993','QA',true,false);
  insert into public.vehicles(id,owner_id,registration_number,vehicle_type,body_type,length_ft,capacity_tonnes,is_default)
    values(truck_id,carrier_id,'QA'||substr(truck_id::text,1,8),'Open truck','Open truck',20,10,true);
  draft:=jsonb_build_object('id',freight_id,'pickup','QA Kochi','destination','QA Kannur',
    'cargo','QA driver freight','vehicle','Open truck','pickup_date',current_date+1,'price',12000,
    'weight_tonnes',4.5,'required_vehicle_length_ft',14,'contact_preference','phone',
    'pickup_latitude',10,'pickup_longitude',76,'destination_latitude',12,'destination_longitude',75,
    'unload_stops','[]'::jsonb);
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  answer:=public.lorry_api('loads.create',draft);
  if answer->>'shipper_id'<>owner_id::text then raise exception 'FAIL: driver not owner'; end if;
  perform public.lorry_api('loads.create',draft); -- Safe retry.
  perform public.lorry_api('loads.edit',draft||jsonb_build_object('cargo','QA updated driver freight'));
  answer:=public.lorry_api('loads.list',jsonb_build_object('mine',true));
  if not exists(select 1 from jsonb_array_elements(answer) x where x->>'id'=freight_id::text) then raise exception 'FAIL: own load missing'; end if;
  answer:=public.lorry_api('loads.list','{}');
  if exists(select 1 from jsonb_array_elements(answer) x where x->>'shipper_id'=owner_id::text) then raise exception 'FAIL: own loads in marketplace'; end if;
  rejected:=false;
  begin perform public.lorry_api('bookings.request',jsonb_build_object('load_id',freight_id)); exception when others then rejected:=true; end;
  if not rejected then raise exception 'FAIL: self booking allowed'; end if;
  perform set_config('request.jwt.claim.sub',other_id::text,true);
  rejected:=false;
  begin perform public.lorry_api('loads.edit',draft); exception when others then rejected:=true; end;
  if not rejected then raise exception 'FAIL: outsider edited load'; end if;
  perform set_config('request.jwt.claim.sub',carrier_id::text,true);
  answer:=public.lorry_api('loads.list','{}');
  if not exists(select 1 from jsonb_array_elements(answer) x where x->>'id'=freight_id::text) then raise exception 'FAIL: other driver cannot find load'; end if;
  answer:=public.lorry_api('bookings.request',jsonb_build_object('load_id',freight_id,'vehicle_id',truck_id));
  booking_id:=(answer->>'id')::uuid;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  answer:=public.lorry_api('bookings.list',jsonb_build_object('incoming',true,'load_id',freight_id));
  if jsonb_array_length(answer)<>1 then raise exception 'FAIL: owner cannot review request'; end if;
  answer:=public.lorry_api('bookings.list',jsonb_build_object('load_id',freight_id));
  if jsonb_array_length(answer)<>0 then raise exception 'FAIL: posted freight in carrier trips'; end if;
  perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking_id,'status','accepted'));
  perform set_config('request.jwt.claim.sub',carrier_id::text,true);
  perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking_id,'status','item_collected','latitude',10,'longitude',76));
  perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking_id,'status','in_transit','latitude',10,'longitude',76));
  perform public.lorry_customer_api('tracking.update',jsonb_build_object('booking_id',booking_id,'latitude',11,'longitude',75));
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  answer:=public.lorry_customer_api('tracking.get',jsonb_build_object('booking_id',booking_id));
  if (answer->>'latitude')::numeric<>11 then raise exception 'FAIL: driver owner cannot track carrier'; end if;
  perform set_config('request.jwt.claim.sub',carrier_id::text,true);
  perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking_id,'status','delivery_reported'));
  perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking_id,'payment_id',gen_random_uuid(),'amount_collected',12000));
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking_id,'status','completed'));
  if exists(select 1 from public.finance_entries f where f.booking_id=qa.booking_id and f.driver_id=owner_id) then raise exception 'FAIL: owner received carrier income'; end if;
  if (select coalesce(sum(f.amount),0) from public.finance_entries f where f.booking_id=qa.booking_id and f.driver_id=carrier_id)<>12000 then raise exception 'FAIL: carrier income missing'; end if;
  perform public.lorry_api('loads.create',draft||jsonb_build_object('id',spare_id));
  perform public.lorry_api('loads.cancel',jsonb_build_object('id',spare_id));
end $$;
