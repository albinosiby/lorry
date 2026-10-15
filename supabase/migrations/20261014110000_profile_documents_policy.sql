-- Defense in depth for the private document metadata table. Direct grants are
-- still revoked; this policy preserves the ownership rule if read access is
-- ever deliberately granted for a review feature.
create policy profile_documents_owner_read on public.profile_documents
  for select to authenticated
  using (profile_id = (select auth.uid()));
