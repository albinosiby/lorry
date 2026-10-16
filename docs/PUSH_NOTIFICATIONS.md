# Android push notifications

Firebase project: `lorry-link-e2906`. Android package: `com.newlorrylink.app`.
The renamed Android app uses a newly registered Firebase Android client in the
same project. Existing server service-account credentials remain unchanged.

The Android client uses `android/app/google-services.json`. The Firebase service-account private key must never be copied into the app or committed to Git.

## Server credentials

The downloaded service account is stored in encrypted Supabase Vault as `fcm_service_account`. Only the service-role dispatcher can call the retrieval RPC; authenticated app users and anonymous callers cannot execute it. The private key is absent from application assets and source control.

Alternatively, in the Supabase project dashboard, Edge Functions → Secrets, add:

- Name: `FCM_SERVICE_ACCOUNT`
- Value: the complete JSON contents of the downloaded Firebase service-account file.

The current CLI identity cannot manage Edge Function environment secrets, so this installation uses Vault instead. `FCM_SERVICE_ACCOUNT`, when present, takes precedence. Neither method requires a new app build when rotating the server credential.

Each insert into the existing notifications table queues a push job and calls the dispatcher through pg_net after commit. The dispatcher authenticates with a secret generated in Vault, reads the real notification/recipient from the database, sends through FCM HTTP v1, removes expired device tokens and records delivery status. Failed/stale jobs retry every three minutes, up to five attempts. Android notification tags replace repeated deliveries for the same event. Delivery is at least once; interruptions around the send/status-save boundary may repeat an alert.

The app requests notification permission after login, registers and refreshes device tokens, and shows foreground notifications locally. Existing Realtime foreground alerts remain available during server setup; matching notification IDs update the same local alert. Android displays FCM background notification payloads. Tapping opens the booking after the intended recipient is signed in. Signing out invalidates this installation's FCM token and removes its registration.

Only Android is configured. iOS needs an Apple Firebase app, plist and APNs configuration. Web push is not enabled.

## Verify on a device

1. Install the configured APK, sign in and allow notification permission.
2. Verify a row exists in `push_tokens` for that account (do not publish token values).
3. Place the app in the background. Have the other booking party request/accept/start/report delivery.
4. Confirm Android displays the notification, and tapping it opens the booking.
5. Check `push_jobs` for `sent`; a missing server secret is recorded as `FCM_SERVICE_ACCOUNT_NOT_CONFIGURED`.
6. Sign out and confirm this phone no longer receives alerts for that account.

Android force-stop in system settings blocks messages until the app is opened again. Notification permission, Google Play services, network connectivity and Android battery restrictions also affect delivery.
