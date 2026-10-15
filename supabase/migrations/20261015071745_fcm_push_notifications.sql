create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema private to service_role;

create table public.push_tokens (
  token text primary key check(length(token) between 20 and 4096),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index push_tokens_profile_idx on public.push_tokens(profile_id);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;
grant all on public.push_tokens to service_role;

create table public.push_jobs (
  notification_id uuid primary key references public.notifications(id) on delete cascade,
  state text not null default 'pending' check(state in ('pending','sending','sent','failed')),
  attempts integer not null default 0,
  updated_at timestamptz not null default now(),
  last_error text
);
alter table public.push_jobs enable row level security;
revoke all on public.push_jobs from anon, authenticated;
grant all on public.push_jobs to service_role;
create index push_jobs_pending_idx on public.push_jobs(state, updated_at) where state <> 'sent';

-- Only this server-side hook and the service-role dispatcher can read the key.
select vault.create_secret(gen_random_uuid()::text || gen_random_uuid()::text, 'fcm_webhook_secret');

create function private.register_push_token(device_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  if device_token is null or length(device_token) not between 20 and 4096 then
    raise exception 'Invalid device token.';
  end if;
  insert into public.push_tokens(token,profile_id) values(device_token,auth.uid())
  on conflict(token) do update set profile_id=auth.uid(),updated_at=now();
end $$;
revoke all on function private.register_push_token(text) from public,anon,authenticated;
grant execute on function private.register_push_token(text) to authenticated;
create function public.register_push_token(device_token text) returns void
language sql security invoker set search_path='' as $$ select private.register_push_token(device_token); $$;
revoke all on function public.register_push_token(text) from public,anon;
grant execute on function public.register_push_token(text) to authenticated;

create function private.remove_push_token(device_token text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  delete from public.push_tokens where token=device_token and profile_id=auth.uid();
end $$;
revoke all on function private.remove_push_token(text) from public,anon,authenticated;
grant execute on function private.remove_push_token(text) to authenticated;
create function public.remove_push_token(device_token text) returns void
language sql security invoker set search_path='' as $$ select private.remove_push_token(device_token); $$;
revoke all on function public.remove_push_token(text) from public,anon;
grant execute on function public.remove_push_token(text) to authenticated;

create function private.claim_push_job(job_id uuid, webhook_secret text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job public.push_jobs; result jsonb;
begin
  if webhook_secret is null or webhook_secret is distinct from
    (select decrypted_secret from vault.decrypted_secrets where name='fcm_webhook_secret' limit 1)
    then raise exception 'Unauthorized push request.'; end if;
  select * into job from public.push_jobs where notification_id=job_id for update;
  if job.notification_id is null or job.state='sent' or job.attempts>=5
    or (job.state='sending' and job.updated_at>now()-interval '3 minutes') then return null; end if;
  update public.push_jobs set state='sending',attempts=attempts+1,updated_at=now()
    where notification_id=job_id;
  select to_jsonb(n) || jsonb_build_object('tokens',
    (select coalesce(jsonb_agg(t.token),'[]') from public.push_tokens t where t.profile_id=n.recipient_id))
    into result from public.notifications n where n.id=job_id;
  return result;
end $$;
revoke all on function private.claim_push_job(uuid,text) from public,anon,authenticated;
grant execute on function private.claim_push_job(uuid,text) to service_role;
create function public.claim_push_job(job_id uuid, webhook_secret text) returns jsonb
language sql security invoker set search_path='' as $$ select private.claim_push_job(job_id,webhook_secret); $$;
revoke all on function public.claim_push_job(uuid,text) from public,anon,authenticated;
grant execute on function public.claim_push_job(uuid,text) to service_role;

create function private.send_push_request(job_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform net.http_post(
    url := 'https://puupnlblrehwrhpaolxs.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type','application/json','x-push-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='fcm_webhook_secret' limit 1)),
    body := jsonb_build_object('notification_id',job_id), timeout_milliseconds := 10000);
end $$;
revoke all on function private.send_push_request(uuid) from public,anon,authenticated;

create function private.queue_notification_push() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.push_jobs(notification_id) values(new.id);
  perform private.send_push_request(new.id);
  return new;
end $$;
revoke all on function private.queue_notification_push() from public,anon,authenticated;
create trigger notification_push after insert on public.notifications
for each row execute function private.queue_notification_push();

create function private.retry_push_jobs() returns void
language plpgsql security definer set search_path='' as $$
declare job record;
begin
  for job in select notification_id from public.push_jobs
    where state<>'sent' and attempts<5 and updated_at<now()-interval '3 minutes'
    order by updated_at limit 20 loop
    perform private.send_push_request(job.notification_id);
  end loop;
end $$;
revoke all on function private.retry_push_jobs() from public,anon,authenticated;
select cron.schedule('retry-lorry-push','*/3 * * * *','select private.retry_push_jobs()');
