-- Public profile photos are limited to the account owner's folder. Identity
-- files remain in the separate private profile-documents bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, 6291456, array['image/jpeg', 'image/png'])
on conflict (id) do update set public = true;

drop policy if exists profile_photos_upload_own on storage.objects;
create policy profile_photos_upload_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
drop policy if exists profile_photos_update_own on storage.objects;
create policy profile_photos_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  ) with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
