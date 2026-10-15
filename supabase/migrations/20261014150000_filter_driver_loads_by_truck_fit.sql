-- Let drivers narrow the marketplace to loads that fit their available truck.
do $$
declare
  function_definition text;
  old_filters constant text := $sql$and (nullif(payload->>'vehicle','') is null or ld.vehicle=payload->>'vehicle')
       and (nullif(payload->>'status','') is null or ld.status=payload->>'status')$sql$;
  new_filters constant text := $sql$and (nullif(payload->>'vehicle','') is null or ld.vehicle=payload->>'vehicle')
       and (nullif(payload->>'max_weight_tonnes','') is null
         or ld.weight_tonnes <= (payload->>'max_weight_tonnes')::numeric)
       and (nullif(payload->>'min_vehicle_length_ft','') is null
         or coalesce(ld.required_vehicle_length_ft, 0) <= (payload->>'min_vehicle_length_ft')::numeric)
       and (nullif(payload->>'status','') is null or ld.status=payload->>'status')$sql$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, chr(13), '');
  if position(old_filters in function_definition) = 0 then
    raise exception 'Could not upgrade lorry_api load-fit filters.';
  end if;
  function_definition := replace(function_definition, old_filters, new_filters);
  execute function_definition;
end;
$$;
