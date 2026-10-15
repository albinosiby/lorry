-- Demo data for local/testing use only.
-- Demo password for both accounts: Demo1234!
-- Run in the Supabase SQL Editor after the migrations.

begin;

create extension if not exists pgcrypto;

-- 1. AUTH USERS
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

-- 2. PUBLIC PROFILES
insert into public.profiles (
  id, name, role, phone, customer_enabled, driver_enabled,
  preferred_language, company_name, address, verification_status
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    'Asha Mehta',
    'shipper',
    '+919876510001',
    true,
    false,
    'en',
    'Mehta Logistics & Supply Chain',
    'Plot 42, Transport Nagar, Bhiwandi, Maharashtra',
    'verified'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'Ravi Kumar',
    'driver',
    '+919876510002',
    false,
    true,
    'en',
    'RK Roadlines Express Fleet',
    'Shop 12, Sector 18, Vashi, Navi Mumbai, Maharashtra',
    'verified'
  )
on conflict (id) do update set
  name = excluded.name,
  phone = excluded.phone,
  customer_enabled = excluded.customer_enabled,
  driver_enabled = excluded.driver_enabled,
  company_name = excluded.company_name,
  address = excluded.address,
  verification_status = excluded.verification_status,
  updated_at = now();

-- 3. DRIVER FLEET (VEHICLES)
insert into public.vehicles (
  id, owner_id, registration_number, vehicle_type, body_type,
  length_ft, capacity_tonnes, is_default, verification_status,
  created_at, updated_at
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'MH 12 RN 4589',
    'Container',
    'Container',
    32.0,
    18.5,
    true,
    'verified',
    now() - interval '30 days',
    now() - interval '2 days'
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    'MH 14 GC 8821',
    'Open truck',
    'Open truck',
    22.0,
    12.0,
    false,
    'verified',
    now() - interval '20 days',
    now() - interval '5 days'
  ),
  (
    '60000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    'DL 01 AB 3412',
    'Trailer',
    'Trailer',
    40.0,
    28.0,
    false,
    'verified',
    now() - interval '15 days',
    now() - interval '1 day'
  )
on conflict (owner_id, registration_number) do update set
  vehicle_type = excluded.vehicle_type,
  body_type = excluded.body_type,
  length_ft = excluded.length_ft,
  capacity_tonnes = excluded.capacity_tonnes,
  is_default = excluded.is_default,
  verification_status = excluded.verification_status,
  updated_at = now();

-- 4. DRIVER COMPLIANCE DOCUMENTS
insert into public.driver_documents (
  id, driver_id, vehicle_id, document_type, storage_path,
  status, expires_on, created_at, reviewed_at
)
values
  (
    '70000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    null,
    'identity',
    '10000000-0000-0000-0000-000000000002/identity/aadhaar_verified.pdf',
    'verified',
    null,
    now() - interval '25 days',
    now() - interval '24 days'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    null,
    'driving_license',
    '10000000-0000-0000-0000-000000000002/driving_license/dl_commercial.pdf',
    'verified',
    '2032-12-31',
    now() - interval '25 days',
    now() - interval '24 days'
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'vehicle_registration',
    '10000000-0000-0000-0000-000000000002/vehicle_registration/rc_smartcard.pdf',
    'verified',
    '2035-08-15',
    now() - interval '25 days',
    now() - interval '24 days'
  ),
  (
    '70000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'insurance',
    '10000000-0000-0000-0000-000000000002/insurance/comprehensive_policy.pdf',
    'verified',
    '2027-06-30',
    now() - interval '25 days',
    now() - interval '24 days'
  ),
  (
    '70000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'permit',
    '10000000-0000-0000-0000-000000000002/permit/national_permit_all_india.pdf',
    'verified',
    '2028-03-31',
    now() - interval '25 days',
    now() - interval '24 days'
  ),
  (
    '70000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'fitness_certificate',
    '10000000-0000-0000-0000-000000000002/fitness_certificate/fitness_valid.pdf',
    'verified',
    '2027-09-30',
    now() - interval '25 days',
    now() - interval '24 days'
  )
on conflict (id) do update set
  document_type = excluded.document_type,
  storage_path = excluded.storage_path,
  status = excluded.status,
  expires_on = excluded.expires_on,
  reviewed_at = excluded.reviewed_at;

-- 5. TRUCK AVAILABILITY POST
insert into public.truck_availability (
  id, driver_id, vehicle_id, current_location, latitude, longitude,
  preferred_destination, available_from, available_until, note, status,
  created_at, updated_at
)
values
  (
    '80000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'Bhiwandi Logistics Hub, Mumbai',
    19.296700,
    73.063100,
    'Pune / Nashik / Gujarat Corridor',
    now(),
    now() + interval '5 days',
    'Ready for immediate loading. Clean 32ft multi-axle container with GPS.',
    'open',
    now() - interval '2 hours',
    now() - interval '2 hours'
  )
on conflict (id) do update set
  current_location = excluded.current_location,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  preferred_destination = excluded.preferred_destination,
  available_from = excluded.available_from,
  available_until = excluded.available_until,
  note = excluded.note,
  status = excluded.status,
  updated_at = now();

-- 6. FREIGHT LOADS MARKETPLACE (WITH FULL COORDINATES & UNLOAD STOPS)
insert into public.loads (
  id, shipper_id, pickup, destination, cargo, vehicle, pickup_date,
  price, currency, contact_preference, status, weight_tonnes,
  required_vehicle_length_ft, pickup_at, special_note,
  pickup_latitude, pickup_longitude, destination_latitude, destination_longitude,
  unload_stops, created_at, updated_at
)
values
  -- Load 1: Mumbai to Pune (Open)
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Bhiwandi Hub, Mumbai',
    'Chakan MIDC, Pune',
    'Automotive spare parts & sensor modules, 18 cartons',
    'Container',
    current_date + 1,
    26500,
    'INR',
    'after_acceptance',
    'open',
    14.5,
    32.0,
    (current_date + 1 + time '10:00') at time zone 'Asia/Kolkata',
    'Hydraulic dock available at pickup. Handle electronics carefully.',
    19.296700, 73.063100,
    18.760600, 73.863600,
    '[{"location":"Talegaon Industrial Area, Pune","unload_tonnes":0.5,"latitude":18.730000,"longitude":73.680000}]'::jsonb,
    now() - interval '2 hours',
    now() - interval '2 hours'
  ),

  -- Load 2: Bengaluru to Chennai (Open)
  (
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Whitefield Depot, Bengaluru',
    'Ambattur Industrial Estate, Chennai',
    'Precision server racks & networking equipment, 12 crates',
    'Container',
    current_date + 2,
    34000,
    'INR',
    'after_acceptance',
    'open',
    6.8,
    24.0,
    (current_date + 2 + time '09:30') at time zone 'Asia/Kolkata',
    'Waterproof sealed container mandatory.',
    12.969800, 77.750000,
    13.114300, 80.154800,
    '[{"location":"Hosur Sipcot Complex, Tamil Nadu","unload_tonnes":1.2,"latitude":12.740900,"longitude":77.825300}]'::jsonb,
    now() - interval '5 hours',
    now() - interval '5 hours'
  ),

  -- Load 3: Delhi to Jaipur (Assigned to Ravi Kumar)
  (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Sanjay Gandhi Transport Nagar, Delhi',
    'VKI Industrial Area, Jaipur',
    'Heavy engineering tools & electrical power cables',
    'Open truck',
    current_date + 1,
    31500,
    'INR',
    'after_acceptance',
    'assigned',
    9.5,
    22.0,
    (current_date + 1 + time '11:00') at time zone 'Asia/Kolkata',
    'Provide heavy tarpaulin covering for transit.',
    28.751300, 77.143700,
    26.985500, 75.773500,
    '[{"location":"Neemrana Japanese Zone, Rajasthan","unload_tonnes":0.8,"latitude":27.988800,"longitude":76.388300}]'::jsonb,
    now() - interval '2 days',
    now() - interval '18 hours'
  ),

  -- Load 4: Hyderabad to Kochi (In Transit with Ravi Kumar)
  (
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'Patancheru Pharma Zone, Hyderabad',
    'Willingdon Island Port, Kochi',
    'Pharmaceutical vaccine supplies, temperature-controlled 4°C',
    'Refrigerated',
    current_date - 1,
    68000,
    'INR',
    'after_acceptance',
    'in_transit',
    12.0,
    32.0,
    (current_date - 1 + time '08:00') at time zone 'Asia/Kolkata',
    'Maintain continuous 2°C to 8°C datalogger verification.',
    17.531200, 78.264400,
    9.961000, 76.270900,
    '[{"location":"Peenya Industrial Estate, Bengaluru","unload_tonnes":1.5,"latitude":13.028500,"longitude":77.519700}]'::jsonb,
    now() - interval '4 days',
    now() - interval '6 hours'
  ),

  -- Load 5: Ahmedabad to Surat (Completed)
  (
    '20000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'Sanand GIDC, Ahmedabad',
    'Sachin GIDC, Surat',
    'Polyester yarn rolls & woven fabric bales, 800 kg',
    'Container',
    current_date - 8,
    27500,
    'INR',
    'after_acceptance',
    'completed',
    8.5,
    20.0,
    (current_date - 8 + time '14:00') at time zone 'Asia/Kolkata',
    'Clean floor required. No chemical smell in truck container.',
    22.986800, 72.380900,
    21.084700, 72.868700,
    '[]'::jsonb,
    now() - interval '12 days',
    now() - interval '5 days'
  ),

  -- Load 6: Kolkata to Kochi (Cancelled)
  (
    '20000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000001',
    'Dankuni Freight Terminal, Kolkata',
    'Willingdon Island, Kochi',
    'Commercial stainless kitchen display units, 30 pieces',
    'Trailer',
    current_date + 6,
    95000,
    'INR',
    'after_acceptance',
    'cancelled',
    22.0,
    40.0,
    (current_date + 6 + time '10:00') at time zone 'Asia/Kolkata',
    'Long-distance inter-state permit required.',
    22.684100, 88.293400,
    9.961000, 76.270900,
    '[]'::jsonb,
    now() - interval '10 days',
    now() - interval '8 days'
  ),

  -- Load 7: Nashik to Mumbai (Open - Requested by Ravi Kumar)
  (
    '20000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000001',
    'Ambad MIDC, Nashik',
    'Bhiwandi Hub, Mumbai',
    'Organic export table grapes, pre-cooled crates',
    'Refrigerated',
    current_date + 1,
    21500,
    'INR',
    'after_acceptance',
    'open',
    7.2,
    20.0,
    (current_date + 1 + time '07:30') at time zone 'Asia/Kolkata',
    'Immediate morning departure required.',
    19.957200, 73.731400,
    19.296700, 73.063100,
    '[]'::jsonb,
    now() - interval '1 day',
    now() - interval '1 day'
  ),

  -- Load 8: Chennai to Coimbatore (Open - Requested by Ravi Kumar)
  (
    '20000000-0000-0000-0000-000000000008',
    '10000000-0000-0000-0000-000000000001',
    'Sri City Industrial Park, Chennai',
    'SIDCO Kurichi, Coimbatore',
    'Heavy spinning mill gear assemblies & high-torque motors',
    'Trailer',
    current_date + 3,
    46000,
    'INR',
    'after_acceptance',
    'open',
    19.0,
    32.0,
    (current_date + 3 + time '12:00') at time zone 'Asia/Kolkata',
    'Crane loading at both source and destination docks.',
    13.535000, 80.038000,
    10.941200, 76.969700,
    '[{"location":"Tirupur Textile Hub, Tamil Nadu","unload_tonnes":2.5,"latitude":11.108500,"longitude":77.341100}]'::jsonb,
    now() - interval '30 minutes',
    now() - interval '30 minutes'
  ),

  -- Load 9: Surat to Mumbai (Open)
  (
    '20000000-0000-0000-0000-000000000009',
    '10000000-0000-0000-0000-000000000001',
    'Sachin GIDC, Surat',
    'Kalamboli Steel Market, Navi Mumbai',
    'Packaged FMCG dry food & edible oils, 900 cartons',
    'Open truck',
    current_date + 2,
    29800,
    'INR',
    'phone',
    'open',
    11.5,
    22.0,
    (current_date + 2 + time '16:00') at time zone 'Asia/Kolkata',
    'Driver must carry photo identity and delivery challan.',
    21.084700, 72.868700,
    19.021000, 73.102000,
    '[]'::jsonb,
    now() - interval '45 minutes',
    now() - interval '45 minutes'
  ),

  -- Load 10: Jaipur to Delhi (Open)
  (
    '20000000-0000-0000-0000-000000000010',
    '10000000-0000-0000-0000-000000000001',
    'VKI Industrial Area, Jaipur',
    'Okhla Industrial Area, Delhi',
    'Glazed ceramic floor tiles on reinforced wooden pallets',
    'Container',
    current_date + 3,
    38500,
    'INR',
    'after_acceptance',
    'open',
    17.0,
    32.0,
    (current_date + 3 + time '11:00') at time zone 'Asia/Kolkata',
    'Heavy fragile load. Strapping belts required.',
    26.985500, 75.773500,
    28.535500, 77.273200,
    '[]'::jsonb,
    now() - interval '3 hours',
    now() - interval '3 hours'
  ),

  -- Load 11: Kochi to Bengaluru (Assigned)
  (
    '20000000-0000-0000-0000-000000000011',
    '10000000-0000-0000-0000-000000000001',
    'Kalamassery Industrial Belt, Kochi',
    'Electronic City, Bengaluru',
    'Rubber vulcanized parts & marine packaging items',
    'LCV',
    current_date + 2,
    32000,
    'INR',
    'after_acceptance',
    'assigned',
    4.8,
    16.0,
    (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
    'Commercial tax e-way bill issued.',
    10.054400, 76.321600,
    12.839900, 77.677000,
    '[{"location":"Palakkad Industrial Corridor, Kerala","unload_tonnes":1.0,"latitude":10.786700,"longitude":76.654800}]'::jsonb,
    now() - interval '3 days',
    now() - interval '1 day'
  ),

  -- Load 12: Chennai to Hyderabad (In Transit)
  (
    '20000000-0000-0000-0000-000000000012',
    '10000000-0000-0000-0000-000000000001',
    'Ambattur Industrial Estate, Chennai',
    'Cherlapally Industrial Area, Hyderabad',
    'High-voltage switchgear & transformer panels, 700 kg',
    'Trailer',
    current_date - 2,
    58000,
    'INR',
    'after_acceptance',
    'in_transit',
    24.5,
    40.0,
    (current_date - 2 + time '08:30') at time zone 'Asia/Kolkata',
    'Over-dimensional load lights enabled.',
    13.114300, 80.154800,
    17.472000, 78.598000,
    '[{"location":"Nellore Logistics Park, Andhra Pradesh","unload_tonnes":2.0,"latitude":14.442600,"longitude":79.986500}]'::jsonb,
    now() - interval '5 days',
    now() - interval '4 hours'
  ),

  -- Load 13: Mysuru to Bengaluru (Completed)
  (
    '20000000-0000-0000-0000-000000000013',
    '10000000-0000-0000-0000-000000000001',
    'Hebbal Industrial Area, Mysuru',
    'Yeshwanthpur APMC Yard, Bengaluru',
    'Processed sandalwood handicrafts & incense crates, 45 items',
    'Pickup',
    current_date - 5,
    14500,
    'INR',
    'after_acceptance',
    'completed',
    1.8,
    12.0,
    (current_date - 5 + time '15:00') at time zone 'Asia/Kolkata',
    'Fast delivery on delivery voucher confirmation.',
    12.357000, 76.613500,
    13.028000, 77.540000,
    '[]'::jsonb,
    now() - interval '10 days',
    now() - interval '4 days'
  ),

  -- Load 14: Nagpur to Pune (Open)
  (
    '20000000-0000-0000-0000-000000000014',
    '10000000-0000-0000-0000-000000000001',
    'Butibori MIDC, Nagpur',
    'Hadapsar Industrial Estate, Pune',
    'Cotton lint bales & industrial seeds, 500 kg',
    'Open truck',
    current_date + 4,
    42000,
    'INR',
    'after_acceptance',
    'open',
    15.0,
    24.0,
    (current_date + 4 + time '09:00') at time zone 'Asia/Kolkata',
    'Cover with double-layer waterproof tarpaulin.',
    20.916700, 79.000000,
    18.508900, 73.925900,
    '[{"location":"MIDC Industrial Area, Jalna","unload_tonnes":1.0,"latitude":19.841000,"longitude":75.886000}]'::jsonb,
    now() - interval '14 days',
    now() - interval '12 days'
  ),

  -- Load 15: Gurugram to Ludhiana (Open)
  (
    '20000000-0000-0000-0000-000000000015',
    '10000000-0000-0000-0000-000000000001',
    'IMT Manesar, Gurugram',
    'Dhandari Kalan, Ludhiana',
    'Bicycle frames & precision automotive sheet metal parts',
    'Open truck',
    current_date + 1,
    36000,
    'INR',
    'after_acceptance',
    'open',
    11.0,
    22.0,
    (current_date + 1 + time '14:30') at time zone 'Asia/Kolkata',
    'Loading bays equipped with overhead gantry cranes.',
    28.358800, 76.938000,
    30.871100, 75.922100,
    '[{"location":"Ambala Cantt Freight Depot, Haryana","unload_tonnes":2.0,"latitude":30.378200,"longitude":76.776700}]'::jsonb,
    now() - interval '1 day',
    now() - interval '1 day'
  ),

  -- Load 16: Indore to Mumbai (Open)
  (
    '20000000-0000-0000-0000-000000000016',
    '10000000-0000-0000-0000-000000000001',
    'Pithampur Industrial Area, Indore',
    'Bhiwandi Hub, Mumbai',
    'Heavy commercial vehicle leaf springs & forged axles',
    'Container',
    current_date + 2,
    49500,
    'INR',
    'after_acceptance',
    'open',
    18.0,
    32.0,
    (current_date + 2 + time '10:00') at time zone 'Asia/Kolkata',
    'Direct highway route via Dhule / Nashik.',
    22.614200, 75.682600,
    19.296700, 73.063100,
    '[{"location":"Dhule Bypass Transshipment Yard, MH","unload_tonnes":1.5,"latitude":20.904200,"longitude":74.774900}]'::jsonb,
    now() - interval '6 hours',
    now() - interval '6 hours'
  ),

  -- Load 17: Vadodara to Hyderabad (Open)
  (
    '20000000-0000-0000-0000-000000000017',
    '10000000-0000-0000-0000-000000000001',
    'Makarpura GIDC, Vadodara',
    'Patancheru Industrial Area, Hyderabad',
    'Chemical process valves & heavy pipeline fittings',
    'Trailer',
    current_date + 3,
    72000,
    'INR',
    'after_acceptance',
    'open',
    26.0,
    40.0,
    (current_date + 3 + time '11:30') at time zone 'Asia/Kolkata',
    'Industrial consignment with GST e-Way bills.',
    22.253000, 73.195000,
    17.531200, 78.264400,
    '[{"location":"MIDC Industrial Area, Nanded, MH","unload_tonnes":3.0,"latitude":19.138300,"longitude":77.321000}]'::jsonb,
    now() - interval '8 hours',
    now() - interval '8 hours'
  ),

  -- Load 18: Visakhapatnam to Chennai (Open)
  (
    '20000000-0000-0000-0000-000000000018',
    '10000000-0000-0000-0000-000000000001',
    'Autonagar Port Corridor, Visakhapatnam',
    'Sri City SEZ, Chennai',
    'Export frozen seafood cartons, -18°C continuous deep freeze',
    'Refrigerated',
    current_date + 1,
    62000,
    'INR',
    'after_acceptance',
    'open',
    14.0,
    32.0,
    (current_date + 1 + time '08:00') at time zone 'Asia/Kolkata',
    'Verify reefer compressor setpoint before departure.',
    17.697800, 83.210700,
    13.535000, 80.038000,
    '[{"location":"Vijayawada Logistics Terminal, Andhra Pradesh","unload_tonnes":2.0,"latitude":16.506200,"longitude":80.648000}]'::jsonb,
    now() - interval '4 hours',
    now() - interval '4 hours'
  )
on conflict (id) do update set
  pickup = excluded.pickup,
  destination = excluded.destination,
  cargo = excluded.cargo,
  vehicle = excluded.vehicle,
  pickup_date = excluded.pickup_date,
  price = excluded.price,
  currency = excluded.currency,
  contact_preference = excluded.contact_preference,
  status = excluded.status,
  weight_tonnes = excluded.weight_tonnes,
  required_vehicle_length_ft = excluded.required_vehicle_length_ft,
  pickup_at = excluded.pickup_at,
  special_note = excluded.special_note,
  pickup_latitude = excluded.pickup_latitude,
  pickup_longitude = excluded.pickup_longitude,
  destination_latitude = excluded.destination_latitude,
  destination_longitude = excluded.destination_longitude,
  unload_stops = excluded.unload_stops,
  updated_at = now();

-- 7. BOOKINGS
insert into public.bookings (
  id, load_id, driver_id, status, delivery_reported_at, reason, source, created_at, updated_at
)
values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'accepted', null, null, 'driver_request', now() - interval '20 hours', now() - interval '18 hours'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'in_transit', now() - interval '2 hours', null, 'driver_request', now() - interval '4 days', now() - interval '6 hours'),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', 'completed', now() - interval '6 days', null, 'driver_request', now() - interval '12 days', now() - interval '5 days'),
  ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'requested', null, null, 'driver_request', now() - interval '3 hours', now() - interval '3 hours'),
  ('30000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'requested', null, null, 'driver_request', now() - interval '50 minutes', now() - interval '50 minutes'),
  ('30000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000002', 'accepted', null, null, 'driver_request', now() - interval '2 days', now() - interval '1 day'),
  ('30000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000002', 'in_transit', now() - interval '1 hour', null, 'driver_request', now() - interval '5 days', now() - interval '4 hours'),
  ('30000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000002', 'completed', now() - interval '5 days', null, 'driver_request', now() - interval '10 days', now() - interval '4 days')
on conflict (id) do update set
  status = excluded.status,
  delivery_reported_at = excluded.delivery_reported_at,
  reason = excluded.reason,
  source = excluded.source,
  updated_at = excluded.updated_at;

-- 8. ACTIVE LIVE TRIP LOCATIONS (FOR REAL-TIME GPS TRACKING SCREEN)
insert into public.active_trip_locations (
  booking_id, driver_id, latitude, longitude, accuracy_meters, heading_degrees, recorded_at, received_at
)
values
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 14.921400, 75.632100, 8.5, 185.0, now() - interval '3 minutes', now()),
  ('30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 15.828100, 79.740200, 12.0, 320.0, now() - interval '5 minutes', now())
on conflict (booking_id) do update set
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  accuracy_meters = excluded.accuracy_meters,
  heading_degrees = excluded.heading_degrees,
  recorded_at = excluded.recorded_at,
  received_at = now();

-- 9. BOOKING EVENTS
insert into public.booking_events (id, booking_id, actor_id, status, note, created_at)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent by Ravi Kumar', now() - interval '20 hours'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the booking request', now() - interval '18 hours'),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent by Ravi Kumar', now() - interval '4 days'),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'accepted', 'Load owner accepted the request', now() - interval '3 days'),
  ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'in_transit', 'Trip started from Hyderabad loading dock', now() - interval '6 hours'),
  ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'delivery_reported', 'Delivery reported by driver at destination gate', now() - interval '2 hours'),
  ('40000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'requested', 'Booking request sent by Ravi Kumar', now() - interval '12 days'),
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

-- 10. DRIVER FINANCE ENTRIES (EARNINGS & EXPENSES)
insert into public.finance_entries (
  id, driver_id, booking_id, entry_type, category, amount, occurred_on, note, created_at
)
values
  ('90000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 'income', 'freight', 27500.00, current_date - 5, 'Freight payout for Ahmedabad to Surat shipment', now() - interval '5 days'),
  ('90000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000008', 'income', 'freight', 14500.00, current_date - 4, 'Freight payout for Mysuru to Bengaluru shipment', now() - interval '4 days'),
  ('90000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', null, 'expense', 'fuel', 8500.00, current_date - 3, 'Diesel fill at HPCL Highway Pump', now() - interval '3 days'),
  ('90000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', null, 'expense', 'toll', 1450.00, current_date - 2, 'FASTag National Highway Tolls', now() - interval '2 days'),
  ('90000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', null, 'expense', 'maintenance', 2200.00, current_date - 1, 'Brake liner check and grease service', now() - interval '1 day')
on conflict (id) do update set
  amount = excluded.amount,
  occurred_on = excluded.occurred_on,
  note = excluded.note;

-- 11. NEARBY HIGHWAY SERVICES CACHE
insert into public.nearby_service_cache (
  id, provider_place_id, service_type, name, address, latitude, longitude, rating, is_open_now, refreshed_at, expires_at
)
values
  ('a0000000-0000-0000-0000-000000000001', 'place_ioc_bhiwandi', 'fuel', 'IndianOil Swagat Highway Pump', 'NH 160, Bhiwandi Bypass, MH', 19.301200, 73.058900, 4.4, true, now(), now() + interval '7 days'),
  ('a0000000-0000-0000-0000-000000000002', 'place_weigh_chakan', 'weighbridge', 'Chakan Electronic Weighbridge (100T)', 'Talegaon-Chakan Road, Chakan MIDC, MH', 18.761500, 73.859800, 4.6, true, now(), now() + interval '7 days'),
  ('a0000000-0000-0000-0000-000000000003', 'place_tata_workshop', 'workshop', 'Tata Motors Authorized Commercial Workshop', 'Mumbai-Pune Expressway Service Road, Panvel, MH', 18.995400, 73.123400, 4.5, true, now(), now() + interval '7 days'),
  ('a0000000-0000-0000-0000-000000000004', 'place_mrf_tyre', 'tyre', 'MRF Commercial Tyre & Wheel Alignment Hub', 'MIDC Industrial Area, Chakan, MH', 18.758000, 73.865000, 4.3, true, now(), now() + interval '7 days'),
  ('a0000000-0000-0000-0000-000000000005', 'place_dhabha_stop', 'truck_stop', 'Karnal Royal Truck Lay-By & Dhaba', 'NH 44, Murthal / Kundli Border', 28.981200, 77.072100, 4.7, true, now(), now() + interval '7 days')
on conflict (provider_place_id, service_type) do update set
  rating = excluded.rating,
  is_open_now = excluded.is_open_now,
  refreshed_at = now(),
  expires_at = now() + interval '7 days';

-- 12. NOTIFICATIONS
insert into public.notifications (id, recipient_id, title, body, load_id, booking_id, created_at, read_at)
values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'New booking request', 'Ravi Kumar requested your Nashik to Mumbai load', '20000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000004', now() - interval '3 hours', null),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Booking accepted', 'Delhi to Jaipur dispatch confirmed', '20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', now() - interval '18 hours', now() - interval '17 hours'),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Booking accepted', 'Delhi to Jaipur load confirmed. Proceed to loading dock.', '20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', now() - interval '18 hours', null),
  ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'Delivery reported', 'Hyderabad to Kochi shipment delivery reported', '20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', now() - interval '2 hours', null),
  ('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'New booking request', 'Ravi Kumar requested your Chennai to Coimbatore load', '20000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000005', now() - interval '50 minutes', null),
  ('50000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'Booking accepted', 'Kochi to Bengaluru load booked', '20000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000006', now() - interval '1 day', null),
  ('50000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'Delivery reported', 'Chennai to Hyderabad trip delivery logged', '20000000-0000-0000-0000-000000000012', '30000000-0000-0000-0000-000000000007', now() - interval '1 hour', null),
  ('50000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'Trip completed', 'Mysuru to Bengaluru payout recorded in finance', '20000000-0000-0000-0000-000000000013', '30000000-0000-0000-0000-000000000008', now() - interval '4 days', now() - interval '3 days')
on conflict (id) do nothing;

commit;

-- Sign in through the app with either:
-- demo.shipper@lorry.link / Demo1234!
-- demo.driver@lorry.link  / Demo1234!
