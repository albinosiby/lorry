-- The actual service-account JSON is provisioned directly into encrypted
-- Vault storage. Never include it in a migration or client configuration.
create function private.fcm_service_account() returns jsonb
language sql security definer set search_path='' as $$
  select decrypted_secret::jsonb from vault.decrypted_secrets
    where name='fcm_service_account' limit 1;
$$;
revoke all on function private.fcm_service_account() from public,anon,authenticated;
grant execute on function private.fcm_service_account() to service_role;
create function public.fcm_service_account() returns jsonb
language sql security invoker set search_path='' as $$
  select private.fcm_service_account();
$$;
revoke all on function public.fcm_service_account() from public,anon,authenticated;
grant execute on function public.fcm_service_account() to service_role;
