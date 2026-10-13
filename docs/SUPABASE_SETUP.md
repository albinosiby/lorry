# Supabase setup and operations

## Connected project

- Name: lorry link
- Project ref: `puupnlblrehwrhpaolxs`
- Region: Singapore (`ap-southeast-1`), selected when the user created the project.
- Dashboard: https://supabase.com/dashboard/project/puupnlblrehwrhpaolxs
- Client endpoint: https://puupnlblrehwrhpaolxs.supabase.co
- Local client configuration: `config/supabase.local.json` (ignored by Git).

The two migrations in `supabase/migrations/` have already been applied to this project. Do not paste them again into the same database. For a fresh Supabase project, apply both in filename order using the Supabase CLI migration workflow or the SQL Editor. If using the CLI, authenticate and inspect current `--help` before linking and pushing to the intended project.

The API is `public.lorry_api(action text, payload jsonb)`. The public wrapper is SECURITY INVOKER. Its implementation is in the non-exposed `private` schema with a fixed empty search path and explicit actor/role/ownership checks in every command. Do not expose `private` through Data API settings. Client table mutations are not granted: state transitions must use the command API.

## Authentication

Email/password is enabled, with email confirmation required. Google remains disabled and hidden in this app release at the user's request.

The user confirmed these redirect URLs were saved in Authentication -> URL Configuration:

```text
com.lorrylink.app://login-callback/
http://localhost:8080/auth/callback
```

Native Android/iOS deep links are configured in their manifests. The app uses PKCE and handles the passwordRecovery auth event by routing to the password-update screen. Use the same browser/device for a PKCE confirmation or reset flow as the one that initiated it.

For a deployed web app, add its exact HTTPS `/auth/callback` URL to the allowlist and set Site URL to the intended public URL. Configure the host to serve `index.html` for unknown routes. Do not rely on a localhost redirect in a public release.

Supabase's built-in email sender is intended for development and imposes recipient/rate restrictions. Before onboarding external users, configure an SMTP provider in Supabase and test signup confirmation and password-reset delivery with your own mailbox. The app's password-reset screen does not expose whether an email address is registered. No real verification/reset emails were sent as part of automated testing.

The security advisor flags **leaked-password protection disabled** in the project. Consider enabling it where supported by the project plan before public release. The database-specific advisor warnings found during setup were fixed; no app-specific database access warnings remain.

## Enable Google later

1. Create/configure a Google OAuth client under your Google project.
2. In Supabase -> Authentication -> Sign In / Providers -> Google, set the Google client ID and secret. Never store the secret in the Flutter project.
3. Configure the Google authorized redirect URI using the value shown by Supabase.
4. Keep the mobile/web app callback URLs above allowlisted.
5. Add `"GOOGLE_SIGN_IN_ENABLED": "true"` to `config/supabase.local.json` and rebuild.
6. Test first-time role setup, returning sessions and user-cancelled OAuth.

## Database and security decisions

All exposed app tables have RLS. Direct SELECT is tightly scoped; profiles and notifications are private. Booking history is served only through the authenticated, party-scoped API. No client has direct INSERT, UPDATE or DELETE rights.

Role selection initializes `profiles.role` once, and the API never changes it afterward. User metadata contains only suggested setup fields and is not used for authorization. Booking decisions acquire a row lock on the load before touching any booking, and a partial unique index ensures only one accepted/in-transit/completed booking exists per load. Notifications and timeline events commit in the same transaction as the state change.

A contact phone is returned only to an accepted booking party, or when a shipper explicitly opts into pre-booking phone contact on the load. The app embeds only a public publishable API key; all sensitive authorization happens on the server.

## Before a public release

- Configure and verify SMTP delivery, public web callback/Site URL if applicable, and the intended password policies.
- Set up signing and build a release APK/AAB (Android); configure an Apple team and test on iOS hardware for iOS delivery.
- Establish privacy policy, support/contact details, account deletion/data retention, and operational handling of in-transit problems.
- The current supported-city list and vehicle types live in `load_model.dart` and the database API validation; change them together with a migration.
- No push notifications, payments, live GPS, broker commissions, fleet management or chat are included in this core scope.
