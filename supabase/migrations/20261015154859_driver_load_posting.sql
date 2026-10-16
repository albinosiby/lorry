-- Posting is an ownership capability, not a reason to change account role.
-- Keep existing route validation, edit ownership, trip and payment guards.
do $$
declare source text;
  old_guard text := $guard$if profile.role<>'shipper' then raise exception 'Only shippers may publish loads.'; end if;$guard$;
  new_guard text := $guard$if profile.role not in ('shipper','driver') then raise exception 'Only customers and drivers may publish loads.'; end if;$guard$;
  old_market text := $guard$else ld.status='open' end$guard$;
  new_market text := $guard$else ld.status='open' and ld.shipper_id<>uid end$guard$;
  old_bookings text := $guard$where (bk.driver_id=uid or ld.shipper_id=uid)$guard$;
  new_bookings text := $guard$where (case
    when coalesce((payload->>'incoming')::boolean,false) then ld.shipper_id=uid
    when profile.role='driver' then bk.driver_id=uid
    else ld.shipper_id=uid end)$guard$;
begin
  select pg_get_functiondef('private.lorry_api_before_workflow(text,jsonb)'::regprocedure) into source;
  if position(old_guard in source)=0 or position(old_market in source)=0
     or position(old_bookings in source)=0 then
    raise exception 'Unexpected logistics API definition; review driver posting migration.';
  end if;
  source := replace(source,old_guard,new_guard);
  source := replace(source,old_market,new_market);
  source := replace(source,old_bookings,new_bookings);
  -- Driver home counts should agree with the marketplace excluding own freight.
  source := replace(source,
    '(select count(*) from public.loads where status=''open'')',
    '(select count(*) from public.loads where status=''open'' and shipper_id<>uid)');
  execute source;
end $$;

-- Replacing the private implementation preserves its non-public ACL.
revoke all on function private.lorry_api_before_workflow(text,jsonb) from public,anon,authenticated;
