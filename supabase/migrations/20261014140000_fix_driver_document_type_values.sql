-- Driver-document table constraints use snake-case values. Correct the
-- protected command introduced by the previous migration accordingly.
do $$
declare
  function_definition text;
begin
  select pg_get_functiondef('private.lorry_next_api(text,jsonb)'::regprocedure)
    into function_definition;
  function_definition := replace(function_definition, '''drivingLicense''', '''driving_license''');
  function_definition := replace(function_definition, '''vehicleRegistration''', '''vehicle_registration''');
  function_definition := replace(function_definition, '''fitnessCertificate''', '''fitness_certificate''');
  execute function_definition;
end;
$$;
