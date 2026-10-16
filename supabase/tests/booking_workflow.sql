-- Execute inside BEGIN/ROLLBACK (optionally after the migration in the same
-- transaction). All fixture users, notifications and ledger entries roll back.
do $$
declare customer uuid:=gen_random_uuid(); driver uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 truck uuid:=gen_random_uuid(); small_truck uuid:=gen_random_uuid(); load1 uuid:=gen_random_uuid(); load2 uuid:=gen_random_uuid();
 booking uuid; second_booking uuid; third_load uuid:=gen_random_uuid(); invitation uuid; availability uuid;
 payment uuid:=gen_random_uuid(); answer jsonb; rejected boolean;
begin
 insert into auth.users(id,email) values(customer,customer::text||'@workflow.invalid'),(driver,driver::text||'@workflow.invalid'),(outsider,outsider::text||'@workflow.invalid');
 insert into public.profiles(id,name,role,phone,address,customer_enabled,driver_enabled)
 values(customer,'Workflow QA customer','shipper','9999999991','QA',true,false),
 (driver,'Workflow QA driver','driver','9999999992','QA',false,true),
 (outsider,'Workflow QA outsider','driver','9999999993','QA',false,true);
 insert into public.vehicles(id,owner_id,registration_number,vehicle_type,body_type,length_ft,capacity_tonnes,is_default)
 values(truck,driver,'QA'||substr(truck::text,1,8),'Open truck','Open truck',20,10,true),
 (small_truck,driver,'QA'||substr(small_truck::text,1,8),'Open truck','Open truck',10,1,false);
 insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,weight_tonnes,required_vehicle_length_ft,
   pickup_latitude,pickup_longitude,destination_latitude,destination_longitude,unload_stops)
 values(load1,customer,'QA Kochi','QA Kannur','QA cargo','Open truck',current_date+1,12000,4,14,10,76,12,75,
   '[{"location":"QA Kozhikode","latitude":11,"longitude":75,"unload_tonnes":1}]'),
 (load2,customer,'QA Kochi','QA Kannur','QA cargo 2','Open truck',current_date+1,10000,4,14,10,76,12,75,'[]');
 perform set_config('request.jwt.claim.sub',driver::text,true);
 rejected:=false;
 begin perform public.lorry_api('bookings.request',jsonb_build_object('load_id',load1,'vehicle_id',small_truck)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: undersized truck accepted'; end if;
 answer:=public.lorry_api('bookings.request',jsonb_build_object('load_id',load1,'vehicle_id',truck)); booking:=(answer->>'id')::uuid;
 answer:=public.lorry_api('bookings.request',jsonb_build_object('load_id',load2,'vehicle_id',truck)); second_booking:=(answer->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','accepted'));
 rejected:=false;
 begin perform public.lorry_api('bookings.transition',jsonb_build_object('id',second_booking,'status','accepted')); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: overlapping assignment accepted'; end if;
 perform set_config('request.jwt.claim.sub',driver::text,true);
 rejected:=false;
 begin perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','in_transit','latitude',10,'longitude',76)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: trip started without collection'; end if;
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','item_collected','latitude',10,'longitude',76));
 perform set_config('request.jwt.claim.sub',customer::text,true);
 answer:=public.lorry_api('loads.get',jsonb_build_object('id',load1));
 if answer->>'item_collected_at' is null then raise exception 'FAIL: customer cannot see collection'; end if;
 perform set_config('request.jwt.claim.sub',driver::text,true);
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','in_transit','latitude',10,'longitude',76));
 perform public.lorry_customer_api('tracking.update',jsonb_build_object('booking_id',booking,'latitude',11,'longitude',75));
 perform public.trip_location_status(booking,false);
 perform set_config('request.jwt.claim.sub',customer::text,true);
 answer:=public.lorry_customer_api('tracking.get',jsonb_build_object('booking_id',booking));
 if (answer->>'latitude')::numeric<>11 or (answer->>'location_enabled')::boolean then raise exception 'FAIL: GPS-off lost point/status'; end if;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 answer:=public.lorry_customer_api('tracking.get',jsonb_build_object('booking_id',booking));
 if answer is not null then raise exception 'FAIL: outsider read GPS'; end if;
 perform set_config('request.jwt.claim.sub',driver::text,true);
 rejected:=false;
 begin perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','delivery_reported')); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: unfinished intermediate stop ignored'; end if;
 perform public.lorry_api('bookings.stop_unloaded',jsonb_build_object('id',booking,'stop_index',0));
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','delivery_reported'));
 if exists(select 1 from public.finance_entries where booking_id=booking) then raise exception 'FAIL: reporting delivery created income'; end if;
 rejected:=false;
 begin perform public.lorry_customer_api('tracking.update',jsonb_build_object('booking_id',booking,'latitude',12,'longitude',75)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: GPS accepted after delivery'; end if;
 perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking,'payment_id',payment,'amount_collected',5000));
 perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking,'payment_id',payment,'amount_collected',5000));
 answer:=public.lorry_api('bookings.get',jsonb_build_object('id',booking));
 if answer->>'payment_status'<>'partial' or (answer->>'payment_balance')::numeric<>7000 then raise exception 'FAIL: partial balance/idempotency'; end if;
 rejected:=false;
 begin perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking,'payment_id',gen_random_uuid(),'amount_collected',8000)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: overcollection accepted'; end if;
 -- Fresh availability is allowed even while customer confirmation is pending.
 perform public.lorry_next_api('availability.save',jsonb_build_object('vehicle_id',truck,'current_location','QA Kannur','latitude',12,'longitude',75,'available_from',now()));
 perform set_config('request.jwt.claim.sub',customer::text,true);
 answer:=public.lorry_customer_api('customer.trucks.list','{}');
 if not exists(select 1 from jsonb_array_elements(answer) x where x->>'driver_id'=driver::text) then raise exception 'FAIL: delivered driver hidden'; end if;
 perform public.lorry_api('bookings.delivery_issue',jsonb_build_object('id',booking,'reason','QA missing package'));
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',booking,'status','completed'));
 perform set_config('request.jwt.claim.sub',driver::text,true);
 perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking,'payment_id',gen_random_uuid(),'amount_collected',7000));
 answer:=public.lorry_api('bookings.get',jsonb_build_object('id',booking));
 if answer->>'payment_status'<>'paid' or answer->>'status'<>'completed' then raise exception 'FAIL: confirmed/paid final state'; end if;
 if (select count(*) from public.finance_entries where booking_id=booking)<>2 then raise exception 'FAIL: duplicate income'; end if;
 if (select sum(amount) from public.finance_entries where booking_id=booking)<>12000 then raise exception 'FAIL: finance total'; end if;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 rejected:=false;
 begin perform public.lorry_api('bookings.payment',jsonb_build_object('id',booking,'payment_id',gen_random_uuid(),'amount_collected',1000)); exception when others then rejected:=true; end;
 if not rejected then raise exception 'FAIL: outsider recorded payment'; end if;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 perform public.lorry_api('bookings.transition',jsonb_build_object('id',second_booking,'status','declined'));
 perform set_config('request.jwt.claim.sub',driver::text,true);
 answer:=public.lorry_api('bookings.request',jsonb_build_object('load_id',load2,'vehicle_id',truck));
 if answer->>'status'<>'requested' or (answer->>'id')::uuid<>second_booking then raise exception 'FAIL: declined request could not be resubmitted'; end if;
 insert into public.loads(id,shipper_id,pickup,destination,cargo,vehicle,pickup_date,price,weight_tonnes,required_vehicle_length_ft,
   pickup_latitude,pickup_longitude,destination_latitude,destination_longitude,unload_stops)
 values(third_load,customer,'QA Kannur','QA Kochi','QA invited cargo','Open truck',current_date+1,10000,4,14,12,75,10,76,'[]');
 select id into availability from public.truck_availability where driver_id=driver and status='open' limit 1;
 perform set_config('request.jwt.claim.sub',customer::text,true);
 answer:=public.lorry_customer_api('customer.truck.invite',jsonb_build_object('load_id',third_load,'availability_id',availability));
 invitation:=(answer->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',driver::text,true);
 perform public.lorry_customer_api('customer.invitation.accept',jsonb_build_object('booking_id',invitation));
 answer:=public.lorry_api('bookings.get',jsonb_build_object('id',invitation));
 if answer->>'status'<>'accepted' or (answer->>'vehicle_id')::uuid<>truck then raise exception 'FAIL: invitation did not assign advertised truck'; end if;
end $$;
