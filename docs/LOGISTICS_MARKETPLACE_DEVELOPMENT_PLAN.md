# LORRY LINK logistics marketplace development plan

This is the delivery plan for the two-sided logistics marketplace: customers post freight, drivers post trucks/availability and request suitable loads, and both parties coordinate the accepted trip.

## Product rules

- One account can use **customer** and **driver** capabilities. A primary role remains for onboarding compatibility, but it must not prevent a customer from registering a truck later.
- Contact details stay private until a load is assigned. The exception is an explicit, opt-in pre-booking contact preference on a load.
- Load matching considers pickup area, destination/return direction, vehicle body, capacity in tonnes, and required vehicle length.
- A driver can withdraw a pending request. Either side can cancel an accepted trip with a reason. In-transit cancellation must go through support.
- The driver reports delivery; the customer confirms final completion.

## Screen, model and repository map

| Area | Screen | Main model | Repository / protected command |
| --- | --- | --- | --- |
| Shared | Welcome, language, OTP/mobile login | `ProfileModel`, `LanguageModel` | Auth / profile repository |
| Shared | Profile & verification | `ProfileModel`, `DriverDocumentModel` | `profile.details.save`, documents upload/list |
| Customer | Customer home | `CustomerHomeModel` | customer dashboard repository |
| Customer | Post / edit load | `LoadDraft`, `LoadModel` | `loads.create`, `loads.edit` |
| Customer | My loads | `LoadsScreenModel` | `loads.list(mine: true)` |
| Customer | Suitable trucks | `TruckAvailabilityModel` | `availability.list` plus matching filters |
| Customer | Requests / select driver | `BookingModel` | booking request/transition commands |
| Shared | Booking / active trip | `BookingModel`, `TripLocationModel` | bookings + tracking repository |
| Driver | Driver home | `DriverDashboardModel` | driver dashboard repository |
| Driver | Find loads | `LoadsScreenModel`, `LoadFilter` | `loads.list` with route/vehicle filters |
| Driver | Load details / request | `LoadDetailsModel` | `loads.get`, `bookings.request` |
| Driver | My trucks | `VehicleModel`, `VehicleDraft` | `vehicles.list`, `vehicles.save` |
| Driver | Post availability | `TruckAvailabilityModel`, `AvailabilityDraft` | `availability.list/save/close` |
| Driver | My trips | `BookingModel` | bookings repository |
| Driver | Nearby services | `NearbyServiceModel` | protected `nearby-services` Edge Function |
| Driver | Finance tracker | `FinanceEntryModel` | `finance.list/save` |
| Shared | Notifications / settings / support / terms | `NotificationModel`, `SettingsModel` | notification and settings repositories |

Every screen follows the existing app direction: **screen → Cubit → repository interface → implementation → Supabase service**. Mobile uses a bottom bar; tablet and web use the existing rail/drawer layout.

## Customer journey

1. Verify mobile number, choose Malayalam, English, or Hindi, complete a profile with photo, identity document and company/address information.
2. Post a load with pickup/destination, cargo, flexible tonne weight, body type, required length, pickup date/time, offered or negotiable rate, and optional handling note.
3. See matching available trucks and incoming driver requests; inspect vehicle/verification information.
4. Select one driver. Both sides then see contact details and the active trip.
5. Follow the driver location, receive status notifications, and confirm delivery.

## Driver journey

1. Verify profile, upload licence/vehicle documents, and register one or more trucks with capacity and length.
2. Find loads that fit truck capacity, truck length, body type and return-route needs; request a load.
3. Post current vehicle availability so customers can invite a suitable truck.
4. Start an accepted trip, share only the active-trip GPS point, report delivery, and record freight/fuel/toll/maintenance in finance.
5. Open Nearby Services to find fuel, lay-bys, weighbridges, workshops, tyre work and hospitals.

## Maps, location and places architecture

### Driver nearby services

This is intentionally a **list/search page**, not an embedded map:

1. Ask for foreground location permission. If GPS/location is off, show an enable-state card.
2. Show actual current coordinates (or a reverse-geocoded locality once available), a search field, category chips and 5/10/25/50 km radii.
3. Call a Supabase Edge Function named `nearby-services`. It holds the Google Places API key in function secrets, applies rate limits/cache, and returns only the cards required by the app.
4. Each card displays name, category, distance, optional rating/open state, and **Navigate**.
5. Navigate opens `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG&travelmode=driving` outside the app.

Google Places is the recommended source because it is stronger for Indian businesses, fuel stations, hospitals and workshops. Weighbridges need a text query fallback because they do not have a dedicated universal place type. Never place a Google key in Flutter.

### Customer live tracking

Use a `flutter_map`/MapLibre visual with a commercial or self-hosted OpenStreetMap tile provider. Do not use public OSM tiles or public Nominatim for production live tracking. The map is only the renderer:

`driver phone GPS → authenticated tracking endpoint → active_trip_locations → Supabase Realtime → customer marker`

Location collection must run only during an accepted/in-transit trip, visibly indicate background tracking, and be throttled (for example, 30–60 seconds or a meaningful movement threshold). Android requires a foreground-service notification; iOS requires the appropriate background-location entitlement and clear user disclosure. The application never sends a Supabase service-role key to a driver device.

## Delivery sequence

1. **Foundation — in progress**: responsive shell, language/capability settings, expanded load fields, secure migration, vehicle data model.
2. **Customer load flow — in progress**: upgraded post-load form, matching truck list, request and selection experience.
3. **Driver vehicle and availability — in progress**: truck registration, availability post/edit/close, matching filters.
4. **Documents and verification**: Storage bucket/RLS, upload flow, reviewer status, profile photo and identity photo.
5. **Booking lifecycle and notifications**: both booking paths, cancellation policy, real-time notification refresh and deep links.
6. **Active-trip tracking**: background driver location, tracked-trip screen, RLS and Realtime tests.
7. **Driver utilities**: Nearby Services Edge Function, finance tracker, support and terms/settings.
8. **Release hardening**: Malayalam/Hindi strings, accessibility, phone/tablet/web testing, rate limits, error analytics, privacy/retention review and device tests.

## Database security boundary

`20261013133000_logistics_marketplace_foundation.sql` adds vehicle, document, availability, finance, nearby-service-cache and active-trip-location tables. RLS is enabled on all new tables. App clients receive only the allowed safe read models; changes run through `lorry_next_api` or protected Edge Functions. Apply this migration before enabling the new screens in any shared environment.

## Current implementation status

- Complete now: mandatory phone validation, upgraded freight form, nearby-service UI and GPS permission states, external Google Maps navigation, truck registration, availability posting/closing, finance tracking, responsive routing, protected-function client contracts, and the additive security migration.
- Remaining implementation: mobile OTP, dual-capability profile UI, document upload/review, customer truck-matching/invitation UI, Edge Functions, tracking worker/map, translations and production deployment configuration.
