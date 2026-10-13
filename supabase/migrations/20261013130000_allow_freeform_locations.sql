-- Allow user-entered locations in databases that already applied the core migration.
do $$
declare
  function_definition text;
  old_validation constant text := $old$if not (payload->>'pickup'=any(city_list)) or not(payload->>'destination'=any(city_list)) or payload->>'pickup'=payload->>'destination' then raise exception 'Choose different supported pickup and destination cities.'; end if;$old$;
  new_validation constant text := $new$if length(trim(coalesce(payload->>'pickup',''))) < 2 or length(trim(coalesce(payload->>'destination',''))) < 2 or lower(trim(payload->>'pickup'))=lower(trim(payload->>'destination')) then raise exception 'Choose different pickup and destination places.'; end if;$new$;
begin
  select pg_get_functiondef('private.lorry_api(text,jsonb)'::regprocedure)
    into function_definition;
  if position(old_validation in function_definition) = 0 then
    return;
  end if;
  function_definition := replace(function_definition, ' city_list text[] := array[''Ahmedabad'',''Bengaluru'',''Chennai'',''Coimbatore'',''Delhi'',''Hyderabad'',''Jaipur'',''Kochi'',''Kolkata'',''Kozhikode'',''Madurai'',''Mumbai'',''Mysuru'',''Nagpur'',''Pune'',''Salem'',''Surat'',''Thiruvananthapuram'',''Thrissur'',''Vijayawada''];', '');
  function_definition := replace(function_definition, old_validation, new_validation);
  execute function_definition;
end
$$;