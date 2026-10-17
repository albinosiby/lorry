-- Driver and vehicle documents remain private; only the owner uploads files
-- and the protected command API records their review state.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'driver-documents', 'driver-documents', false, 8388608,
  array['image/jpeg', 'image/png', 'application/pdf']
)
on conflict (id) do update set public = false;

drop policy if exists driver_documents_upload_own on storage.objects;
create policy driver_documents_upload_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
drop policy if exists driver_documents_read_own on storage.objects;
create policy driver_documents_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

-- Insert the command before the stable tracking branch. This avoids coupling a
-- production bootstrap to whitespace emitted by pg_get_functiondef().
do $driver_documents_upgrade$
declare
  function_definition text;
  document_command constant text := $document_command$
  if action = 'documents.register' then
    if profile.role <> 'driver' and not profile.driver_enabled then
      raise exception 'Enable the driver profile to use this feature.';
    end if;
    if coalesce(payload->>'document_type', '') not in (
      'identity', 'driving_license', 'vehicle_registration', 'insurance', 'permit', 'fitness_certificate'
    ) then
      raise exception 'Choose a supported driver document.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    if nullif(payload->>'expires_on', '') is not null
       and (payload->>'expires_on')::date < current_date then
      raise exception 'Document expiry date cannot be in the past.';
    end if;
    if nullif(payload->>'vehicle_id', '') is not null then
      select * into vehicle from public.vehicles
        where id = (payload->>'vehicle_id')::uuid and owner_id = uid;
      if vehicle.id is null then
        raise exception 'Choose one of your registered trucks.';
      end if;
    end if;
    if coalesce(payload->>'document_type', '') in (
      'vehicle_registration', 'insurance', 'permit', 'fitness_certificate'
    ) and nullif(payload->>'vehicle_id', '') is null then
      raise exception 'Choose the truck this document belongs to.';
    end if;
    with inserted as (
      insert into public.driver_documents(driver_id, vehicle_id, document_type, storage_path, expires_on)
      values (
        uid, nullif(payload->>'vehicle_id', '')::uuid, payload->>'document_type',
        payload->>'storage_path', nullif(payload->>'expires_on', '')::date
      ) returning *
    )
    select to_jsonb(inserted) into result from inserted;
    if payload->>'document_type' = 'identity' then
      update public.profiles set verification_status = 'submitted', updated_at = now()
        where id = uid and verification_status = 'pending';
    end if;
    return result;
  end if;
$document_command$;
begin
  select replace(pg_get_functiondef('private.lorry_next_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position('if action = ''tracking.get'' then' in function_definition) = 0 then
    raise exception 'Could not find the lorry_next_api tracking command boundary.';
  end if;
  if position('if action = ''documents.register'' then' in function_definition) = 0 then
    function_definition := replace(
      function_definition,
      'if action = ''tracking.get'' then',
      document_command || E'\n  if action = ''tracking.get'' then'
    );
    execute function_definition;
  end if;
end;
$driver_documents_upgrade$;
