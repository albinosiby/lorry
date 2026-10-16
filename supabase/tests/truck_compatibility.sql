-- Run inside BEGIN/ROLLBACK; no fixture accounts or notifications are retained.
do $$
declare customer uuid:=gen_random_uuid(); driver uuid:=gen_random_uuid();
 truck uuid:=gen_random_uuid(); load_id uuid; tonnes numeric; answer jsonb;
 rejected boolean; kind text; availability uuid; draft jsonb;
begin
 insert into auth.users(id,email) values(customer,customer::text||'@fit.invalid'),(driver,driver::text||'@fit.invalid');
 insert into public.profiles(id,name,role,phone,address,customer_enabled,driver_enabled)
 values(customer,'Fit QA customer','shipper','9999999991','QA',true,false),
 (driver,'Fit QA driver','driver','9999999992','QA',false,true);
 insert into public.vehicles(id,owner_id,registration_number,vehicle_type,body_type,length_ft,capacity_tonnes,is_default)
 values(truck,driver,'QA'||substr(truck::text,1,8),'LCV','LCV',17.55,4,true);
 perform set_config('request.jwt.claim.sub',driver::text,true);
 answer:=public.lorry_next_api('vehicles.save',jsonb_build_object('id',truck,'registration_number','QA'||substr(truck::text,1,8),
   'vehicle_type','LCV','body_type','LCV','length_ft',17.55,'capacity_tonnes',4));
 if (answer->>'length_ft')::numeric<>17.55 then raise exception 'FAIL: truck custom length rounded'; end if;
 perform public.lorry_next_api('availability.save',jsonb_build_object('vehicle_id',truck,'current_location','QA Kochi','latitude',10,'longitude',76,'available_from',now()));
 select id into availability from public.truck_availability where vehicle_id=truck and status='open';
 foreach kind in array array['Mini truck','Pickup','LCV','Open truck'] loop
   foreach tonnes in array array[1,1.5,2,3,4]::numeric[] loop
     load_id:=gen_random_uuid();
     insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,weight_tonnes,required_vehicle_length_ft,pickup_latitude,pickup_longitude)
     values(load_id,customer,'QA Kochi','QA Kannur','Fit QA',kind,current_date+1,tonnes,17.55,10,76);
     perform set_config('request.jwt.claim.sub',driver::text,true);
     answer:=public.lorry_api('loads.list',jsonb_build_object('vehicle','LCV','max_weight_tonnes',4,'min_vehicle_length_ft',17.55));
     if not exists(select 1 from jsonb_array_elements(answer) x where x->>'id'=load_id::text) then raise exception 'FAIL: compatible load hidden'; end if;
     perform public.lorry_api('bookings.request',jsonb_build_object('load_id',load_id,'vehicle_id',truck));
     perform set_config('request.jwt.claim.sub',customer::text,true);
     answer:=public.lorry_customer_api('customer.trucks.list',jsonb_build_object('load_id',load_id));
     if not exists(select 1 from jsonb_array_elements(answer) x where x->>'vehicle_id'=truck::text) then raise exception 'FAIL: compatible truck hidden'; end if;
     perform public.lorry_customer_api('customer.truck.invite',jsonb_build_object('load_id',load_id,'availability_id',availability));
   end loop;
 end loop;
 perform set_config('request.jwt.claim.sub',driver::text,true);
 foreach kind in array array['Pickup','Container','Refrigerated','Trailer'] loop
   load_id:=gen_random_uuid();
   insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,weight_tonnes,required_vehicle_length_ft)
   values(load_id,customer,'QA Kochi','QA Kannur','Fit QA',kind,current_date+1,case when kind='Pickup' then 4.01 else 1 end,10);
   rejected:=false;
   begin perform public.lorry_api('bookings.request',jsonb_build_object('load_id',load_id,'vehicle_id',truck)); exception when others then rejected:=true; end;
   if not rejected then raise exception 'FAIL: overweight/specialised load accepted'; end if;
 end loop;
 load_id:=gen_random_uuid();
 insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,weight_tonnes,required_vehicle_length_ft)
 values(load_id,customer,'QA Kochi','QA Kannur','Fit QA','Pickup',current_date+1,1,17.56);
 rejected:=false;
 begin perform public.lorry_api('bookings.request',jsonb_build_object('load_id',load_id,'vehicle_id',truck)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: excess deck requirement accepted'; end if;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 draft:=jsonb_build_object('id',gen_random_uuid(),'pickup','QA Kochi','destination','QA Kannur','cargo','Custom length QA',
   'vehicle','Pickup','pickup_date',current_date+1,'price',12000,'weight_tonnes',2,'required_vehicle_length_ft',17.55,'contact_preference','after_acceptance',
   'pickup_latitude',10,'pickup_longitude',76,'destination_latitude',12,'destination_longitude',75,'unload_stops','[]'::jsonb);
 answer:=public.lorry_api('loads.create',draft);
 if (answer->>'required_vehicle_length_ft')::numeric<>17.55 then raise exception 'FAIL: load custom length rounded'; end if;
 answer:=public.lorry_api('loads.edit',draft||jsonb_build_object('required_vehicle_length_ft',16.25));
 if (answer->>'required_vehicle_length_ft')::numeric<>16.25 then raise exception 'FAIL: edited load custom length rounded'; end if;
end $$;
