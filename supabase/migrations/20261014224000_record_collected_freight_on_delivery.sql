-- A driver reports delivery with the amount actually collected. Keep the
-- booking event and finance income in one RPC transaction.
create unique index if not exists one_freight_income_per_booking
  on public.finance_entries(booking_id)
  where booking_id is not null and entry_type = 'income' and category = 'freight';

do $$
declare
  function_definition text;
  old_delivery constant text := $sql$   elsif next_status='delivery_reported' then
     if b.driver_id<>uid or b.status<>'in_transit' then raise exception 'Only the driver of an active trip can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'::jsonb; end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;$sql$;
  new_delivery constant text := $sql$   elsif next_status='delivery_reported' then
     if b.driver_id<>uid or b.status<>'in_transit' then raise exception 'Only the driver of an active trip can report delivery.'; end if;
     if b.delivery_reported_at is not null then return '{}'::jsonb; end if;
     if coalesce((payload->>'amount_collected')::numeric, 0) <= 0 then
       raise exception 'Enter the amount collected before reporting delivery.';
     end if;
     update public.bookings set delivery_reported_at=now(),updated_at=now() where id=b.id;
     insert into public.finance_entries(driver_id, booking_id, entry_type, category, amount, occurred_on, note)
     values (uid, b.id, 'income', 'freight', (payload->>'amount_collected')::numeric, current_date, 'Freight collected on delivery');$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, chr(13), '');
  if position(old_delivery in function_definition) = 0 then
    raise exception 'Could not add collected freight to the delivery workflow.';
  end if;
  execute replace(function_definition, old_delivery, new_delivery);
end;
$$;
