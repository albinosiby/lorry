-- A load may be delivered in parts before reaching its final destination.
alter table public.loads
  add column if not exists unload_stops jsonb not null default '[]'::jsonb,
  add constraint loads_unload_stops_array
    check (jsonb_typeof(unload_stops) = 'array');

do $$
declare
  function_definition text;
  validation constant text := $sql$ if action in ('loads.create','loads.edit') then
   if jsonb_typeof(coalesce(payload->'unload_stops', '[]'::jsonb)) <> 'array'
      or jsonb_array_length(coalesce(payload->'unload_stops', '[]'::jsonb)) > 10 then
     raise exception 'Add up to 10 valid unloading stops.';
   end if;
   if exists (
     select 1
     from jsonb_array_elements(coalesce(payload->'unload_stops', '[]'::jsonb)) as stop
     where jsonb_typeof(stop) <> 'object'
        or length(trim(coalesce(stop->>'location', ''))) < 2
   ) then
     raise exception 'Each unloading stop needs a location.';
   end if;
 end if;
$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position('if action in (''loads.create'',''loads.edit'') then' in function_definition) = 0
      or position(',pickup_at,special_note)' in function_definition) = 0
      or position('coalesce(trim(payload->>''special_note''),'''')) returning * into l;' in function_definition) = 0
      or position('special_note=coalesce(trim(payload->>''special_note''),''''),updated_at=now()' in function_definition) = 0 then
    raise exception 'Could not upgrade LORRY LINK load commands for unloading stops.';
  end if;
  function_definition := replace(
    function_definition,
    'if action in (''loads.create'',''loads.edit'') then',
    validation || ' if action in (''loads.create'',''loads.edit'') then'
  );
  function_definition := replace(
    function_definition,
    ',pickup_at,special_note)',
    ',pickup_at,special_note,unload_stops)'
  );
  function_definition := replace(
    function_definition,
    'coalesce(trim(payload->>''special_note''),'''')) returning * into l;',
    'coalesce(trim(payload->>''special_note''),''''),coalesce(payload->''unload_stops'',''[]''::jsonb)) returning * into l;'
  );
  function_definition := replace(
    function_definition,
    'special_note=coalesce(trim(payload->>''special_note''),''''),updated_at=now()',
    'special_note=coalesce(trim(payload->>''special_note''),''''),unload_stops=coalesce(payload->''unload_stops'',''[]''::jsonb),updated_at=now()'
  );
  execute function_definition;
end;
$$;
