-- Demo data for local/testing use only.
-- Demo password for both accounts: Demo1234!
-- Run in the Supabase SQL Editor after the migrations.

begin;

create extension if not exists pgcrypto;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'demo.shipper@lorry.link',
    crypt('Demo1234!', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Asha Mehta","role":"shipper"}'::jsonb,
    now(), now()
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 'demo.driver@lorry.link',
    crypt('Demo1234!', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Ravi Kumar","role":"driver"}'::jsonb,
    now(), now()
  )
on conflict do nothing;

insert into public.profiles (id, name, role, phone)
values
  ('10000000-0000-0000-0000-000000000001', 'Asha Mehta', 'shipper', '+91 98765 10001'),
  ('10000000-0000-0000-0000-000000000002', 'Ravi Kumar', 'driver', '+91 98765 10002')
on conflict (id) do update set name = excluded.name, phone = excluded.phone;

insert into public.loads (
  id, shipper_id, pickup, destination, cargo, vehicle, pickup_date,
  price, contact_preference, status, created_at, updated_at
)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Mumbai', 'Pune', 'Consumer electronics, 18 cartons', 'Mini truck', current_date + 2, 18500, 'phone', 'open', now() - interval '2 hours', now() - interval '2 hours'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Bengaluru', 'Chennai', 'Automotive spare parts, 420 kg', 'LCV', current_date + 4, 24000, 'after_acceptance', 'open', now() - interval '5 hours', now() - interval '5 hours'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Delhi', 'Jaipur', 'Furniture and household goods, 1.2 tonnes', 'Open truck', current_date + 1, 31500, 'after_acceptance', 'assigned', now() - interval '2 days', now() - interval '18 hours'),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Hyderabad', 'Kochi', 'Pharmaceutical supplies, temperature controlled', 'Refrigerated', current_date - 1, 52000, 'after_acceptance', 'in_transit', now() - interval '4 days', now() - interval '6 hours'),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'Ahmedabad', 'Surat', 'Textile rolls, 800 kg', 'Container', current_date - 8, 27500, 'after_acceptance', 'completed', now() - interval '12 days', now() - interval '5 days'),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'Kolkata', 'Kochi', 'Retail display units, 30 pieces', 'Pickup', current_date + 6, 16000, 'after_acceptance', 'cancelled', now() - interval '10 days', now() - interval '8 days'),
  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 'Pune', 'Nashik', 'Fresh produce, 600 kg', 'Refrigerated', current_date + 3, 14500, 'after_acceptance', 'open', now() - interval '1 day', now() - interval '1 day'),
  ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001', 'Chennai', 'Coimbatore', 'Industrial tools and equipment', 'Trailer', current_date + 7, 22000, 'after_acceptance', 'open', now() - interval '30 minutes', now() - interval '30 minutes'),
  ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000001', 'Surat', 'Mumbai', 'Packaged food products, 900 kg', 'Open truck', current_date + 5, 19800, 'phone', 'open', now() - interval '45 minutes', now() - interval '45 minutes'),
  ('20000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000001', 'Jaipur', 'Delhi', 'Ceramic tiles, 1.5 tonnes', 'Container', current_date + 8, 35000, 'after_acceptance', 'open', now() - interval '3 hours', now() - interval '3 hours'),
  ('20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000001', 'Kochi', 'Bengaluru', 'Restaurant kitchen equipment', 'LCV', current_date + 1, 28500, 'after_acceptance', 'assigned', now() - interval '3 days', now() - interval '1 day'),
  ('20000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000001', 'Chennai', 'Hyderabad', 'Textile machinery components, 700 kg', 'Trailer', current_date - 1, 41000, 'after_acceptance', 'in_transit', now() - interval '5 days', now() - interval '4 hours'),
  ('20000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000001', 'Mysuru', 'Bengaluru', 'Office furniture, 45 items', 'Pickup', current_date - 6, 12500, 'after_acceptance', 'completed', now() - interval '10 days', now() - interval '4 days'),
  ('20000000-0000-0000-0000-000000000014', '10000000-0000-0000-0000-000000000001', 'Nagpur', 'Pune', 'Packaged household goods, 500 kg', 'Mini truck', current_date + 9, 17500, 'after_acceptance', 'cancelled', now() - interval '14 days', now() - interval '12 days')
on conflict (id) do update set
  pickup = excluded.pickup, destination = excluded.destination, cargo = excluded.cargo,
  vehicle = excluded.vehicle, pickup_date = excluded.pickup_date, price = excluded.price,
  contact_preference = excluded.contact_preference, status = excluded.status,
  updated_at = excluded.updated_at;

insert into public.bookings (
  id, load_id, driver_id, status, delivery_reported_at, reason, created_at, updated_at
)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'accepted', null, null, now() - interval '20 hours', now() - interval '18 hours'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'in_transit', now() - interval '2 hours', null, now() - interval '4 days', now() - interval '6 hours'),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', 'completed', now() - interval '6 days', null, now() - interval '12 days', now() - interval '5 days'),
  ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'requested', null, null, now() - interval '3 hours', now() - interval '3 hours'),
  ('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'requested', null, null, now() - interval '50 minutes', now() - interval '50 minutes'),
  ('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000002', 'accepted', null, null, now() - interval '2 days', now() - interval '1 day'),
  ('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000002', 'in_transit', now() - interval '1 hour', null, now() - interval '5 days', now() - interval '4 hours'),
  ('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000002', 'completed', now() - interval '5 days', null, now() - interval '10 days', now() - interval '4 days')
on conflict (id) do update set
  status = excluded.status, delivery_reported_at = excluded.delivery_reported_at,
  reason = excluded.reason, updated_at = excluded.updated_at;

insert into public.booking_events (id, booking_id, actor_id, status, note, created_at)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '20 hours'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '18 hours'),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '4 days'),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'accepted', 'Load owner accepted the request', now() - interval '3 days'),
  ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'in_transit', 'Trip started', now() - interval '6 hours'),
  ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'delivery_reported', 'Delivery reported by driver', now() - interval '2 hours'),
  ('40000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '12 days'),
  ('40000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '11 days'),
  ('40000000-0000-0000-0000-000000000009', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'in_transit', 'Trip started', now() - interval '7 days'),
  ('40000000-0000-0000-0000-000000000010', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'delivery_reported', 'Delivery reported by driver', now() - interval '6 days'),
  ('40000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'completed', 'Delivery confirmed by shipper', now() - interval '5 days'),
  ('40000000-0000-0000-0000-000000000012', '30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '3 hours'),
  ('40000000-0000-0000-0000-000000000013', '30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '50 minutes'),
  ('40000000-0000-0000-0000-000000000014', '30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '2 days'),
  ('40000000-0000-0000-0000-000000000015', '30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '1 day'),
  ('40000000-0000-0000-0000-000000000016', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '5 days'),
  ('40000000-0000-0000-0000-000000000017', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '4 days'),
  ('40000000-0000-0000-0000-000000000018', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'in_transit', 'Trip started', now() - interval '4 hours'),
  ('40000000-0000-0000-0000-000000000019', '30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'delivery_reported', 'Delivery reported by driver', now() - interval '1 hour'),
  ('40000000-0000-0000-0000-000000000020', '30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent', now() - interval '10 days'),
  ('40000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '9 days'),
  ('40000000-0000-0000-0000-000000000022', '30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'in_transit', 'Trip started', now() - interval '6 days'),
  ('40000000-0000-0000-0000-000000000023', '30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'delivery_reported', 'Delivery reported by driver', now() - interval '5 days'),
  ('40000000-0000-0000-0000-000000000024', '30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001', 'completed', 'Delivery confirmed by shipper', now() - interval '4 days')
on conflict (id) do nothing;

insert into public.notifications (id, recipient_id, title, body, load_id, booking_id, created_at, read_at)
values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'New booking request', 'Ravi Kumar requested your load', '20000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000004', now() - interval '3 hours', null),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Booking accepted', 'Delhi to Jaipur', '20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', now() - interval '18 hours', now() - interval '17 hours'),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Booking accepted', 'Delhi to Jaipur', '20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', now() - interval '18 hours', null),
  ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'Delivery reported', 'Hyderabad to Kochi', '20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', now() - interval '2 hours', null),
  ('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'New booking request', 'Ravi Kumar requested your load', '20000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000005', now() - interval '50 minutes', null),
  ('50000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'Booking accepted', 'Kochi to Bengaluru', '20000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000006', now() - interval '1 day', null),
  ('50000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'Delivery reported', 'Chennai to Hyderabad', '20000000-0000-0000-0000-000000000012', '30000000-0000-0000-0000-000000000007', now() - interval '1 hour', null),
  ('50000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'Trip completed', 'Mysuru to Bengaluru', '20000000-0000-0000-0000-000000000013', '30000000-0000-0000-0000-000000000008', now() - interval '4 days', now() - interval '3 days')
on conflict (id) do nothing;

commit;

-- Sign in through the app with either:
-- demo.shipper@lorry.link / Demo1234!
-- demo.driver@lorry.link  / Demo1234!