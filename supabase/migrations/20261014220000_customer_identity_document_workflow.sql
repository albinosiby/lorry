-- Customers submit one identity document of their choice and can safely
-- replace or remove it from their profile.
alter table public.profile_documents
  drop constraint if exists profile_documents_document_type_check;
alter table public.profile_documents
  add constraint profile_documents_document_type_check
  check (document_type in ('identity', 'aadhaar', 'pan', 'driving_licence'));

drop policy if exists profile_documents_delete_own on storage.objects;
create policy profile_documents_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-documents'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

do $$
declare
  function_definition text;
  old_declaration constant text := $sql$  booking public.bookings;
  result jsonb;$sql$;
  new_declaration constant text := $sql$  booking public.bookings;
  profile_document public.profile_documents;
  result jsonb;$sql$;
  old_list constant text := $sql$  if action = 'profile.documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at desc), '[]'::jsonb)
      into result from public.profile_documents d where d.profile_id = uid;
    return result;
  end if;$sql$;
  new_list constant text := $sql$  if action = 'profile.documents.list' then
    select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
      into result from (
        select * from public.profile_documents
        where profile_id = uid
        order by created_at desc
        limit 1
      ) d;
    return result;
  end if;$sql$;
  old_register constant text := $sql$  if action = 'profile.documents.register' then
    if payload->>'document_type' <> 'identity' then
      raise exception 'Choose a supported identity document.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    insert into public.profile_documents(profile_id, document_type, storage_path)
    values (uid, 'identity', payload->>'storage_path')
    returning to_jsonb(profile_documents.*) into result;
    update public.profiles set verification_status = 'submitted', updated_at = now()
      where id = uid and verification_status = 'pending';
    return result;
  end if;$sql$;
  new_register constant text := $sql$  if action = 'profile.documents.register' then
    if coalesce(payload->>'document_type', '') not in ('aadhaar', 'pan', 'driving_licence') then
      raise exception 'Choose Aadhaar, PAN or driving licence.';
    end if;
    if payload->>'storage_path' !~ ('^' || uid::text || '/[^/]+$') then
      raise exception 'Invalid document upload path.';
    end if;
    select * into profile_document from public.profile_documents
      where profile_id = uid order by created_at desc limit 1 for update;
    if profile_document.id is null then
      insert into public.profile_documents(profile_id, document_type, storage_path)
      values (uid, payload->>'document_type', payload->>'storage_path')
      returning to_jsonb(profile_documents.*) into result;
    else
      update public.profile_documents
      set document_type = payload->>'document_type',
          storage_path = payload->>'storage_path',
          status = 'submitted',
          rejection_reason = null,
          reviewed_at = null,
          created_at = now()
      where id = profile_document.id
      returning to_jsonb(profile_documents.*) into result;
    end if;
    update public.profiles set verification_status = 'submitted', updated_at = now()
      where id = uid;
    return result;
  end if;

  if action = 'profile.documents.remove' then
    select * into profile_document from public.profile_documents
      where id = (payload->>'id')::uuid and profile_id = uid for update;
    if profile_document.id is null then
      raise exception 'This identity document is unavailable.';
    end if;
    delete from public.profile_documents where id = profile_document.id;
    if not exists (select 1 from public.profile_documents where profile_id = uid) then
      update public.profiles set verification_status = 'pending', updated_at = now()
        where id = uid;
    end if;
    return '{}'::jsonb;
  end if;$sql$;
begin
  select replace(pg_get_functiondef('private.lorry_customer_api(text,jsonb)'::regprocedure), chr(13), '')
    into function_definition;
  if position(old_declaration in function_definition) = 0
      or position(old_list in function_definition) = 0
      or position(old_register in function_definition) = 0 then
    raise exception 'Could not upgrade customer identity document commands.';
  end if;
  function_definition := replace(function_definition, old_declaration, new_declaration);
  function_definition := replace(function_definition, old_list, new_list);
  function_definition := replace(function_definition, old_register, new_register);
  execute function_definition;
end;
$$;
