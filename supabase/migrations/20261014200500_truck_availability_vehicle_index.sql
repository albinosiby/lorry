-- Supports the vehicle foreign key and availability-to-vehicle lookup.
create index if not exists truck_availability_vehicle_idx
  on public.truck_availability (vehicle_id);
