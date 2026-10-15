# Driver essentials

The screen uses the driver's current GPS position, a Near me button, category
shortcuts and keyword search. Each category has a horizontally scrolling row.
Categories load independently with two concurrent requests. Sparse categories
expand automatically from 10 to 25 to at most 50 km; three results stop expansion.
There are no manual range pills. Results show approximate straight-line distance;
Navigate opens Google Maps externally. Phone and opening hours are displayed only
when supplied by the provider. Truck parking is not a guarantee of truck access.

## Providers

The authenticated `nearby-services` Edge Function calls Google Places (New) when
the server secret `GOOGLE_PLACES_API_KEY` is configured. Enable Places API (New),
billing, and appropriate server-key restrictions. Do not put this secret in Flutter,
and do not reuse the Firebase configuration API key.

Without that secret, or if Google fails, the function queries OpenStreetMap through
Overpass. `OVERPASS_API_URL` can select a hosted/private Overpass interpreter.
Community endpoints have no availability guarantee and may time out or rate-limit.
OSM coverage, phone numbers, hours and weighbridges vary by location in India.
Use Google Places or a managed Overpass service before production rollout.

OSM results have a short in-memory cache. Google results are fetched live. The UI
shows source attribution, retains its controls on provider failure, and supports
retry. Location permissions and disabled GPS have separate prompts.

## Verification

Run `flutter test test/nearby_services_test.dart` and
`npx deno test --allow-env supabase/functions/nearby-services/providers_test.ts`.
Provider tests use fixtures; they do not establish live provider availability.
During implementation, live public Overpass requests failed with timeouts/server
errors. Verify live results on a signed-in device after configuring the provider.
