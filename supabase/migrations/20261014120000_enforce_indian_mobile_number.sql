-- Store operational contacts in one canonical Indian mobile-number format.
-- The previous expression matched a literal backslash and rejected +91 inputs.
create or replace function private.require_profile_phone()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  digits text := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
begin
  if digits ~ '^91[6-9][0-9]{9}$' then
    digits := substring(digits from 3);
  end if;
  if digits !~ '^[6-9][0-9]{9}$' then
    raise exception 'Enter a valid 10-digit Indian mobile number.';
  end if;
  new.phone := '+91' || digits;
  new.updated_at := now();
  return new;
end;
$$;

update public.profiles
set phone = '+91' || right(regexp_replace(phone, '[^0-9]', '', 'g'), 10)
where regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g')
  ~ '^(91)?[6-9][0-9]{9}$';
