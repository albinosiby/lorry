# LORRY LINK — Driver Experience PRD

## 1. Purpose

LORRY LINK helps a driver avoid an empty return trip. Instead of travelling to a booking office, the driver can find a suitable load near the current location or along a preferred return route, request it, complete the trip, and manage essential on-road work from the same app.

This document defines the driver-side product requirements. It complements the approved customer-side load-posting flow.

## 2. Product principles

- Make the next action obvious: find a load, post availability, start a trip, or find roadside help.
- Keep the driver workflow usable with one hand, large touch targets, and low reading effort.
- A driver posts **truck availability**, not a freight load.
- A driver may also use the app as a customer; do not permanently lock an account to one role.
- Location sharing is opt-in and limited to an assigned, active trip.

## 3. Driver journey

```text
Create account and verify driver/truck
  -> mark truck available
  -> find nearby or return-route loads
  -> request a load (or receive a customer invitation)
  -> customer assigns the driver
  -> share contact details
  -> start trip and location sharing
  -> report delivery
  -> customer confirms delivery
  -> review earnings and expenses
```

## 4. Navigation

The driver app has five primary sections.

| Section | Purpose | Key actions |
| --- | --- | --- |
| Home | Immediate working state | Change availability, see recommended loads, active trip, quick actions |
| Find Loads | Marketplace discovery | Filter, inspect, request a load |
| My Trips | Booking and delivery work | View requests, start a trip, report delivery, history |
| Nearby Services | On-road driver utilities | Location-aware searchable list of fuel, lay-bys, weighbridges, hospitals, service and tyre support |
| Profile | Driver, truck, documents and settings | Maintain truck details, upload documents, language, support |

Finance is a prominent shortcut on Home and a section of trip details and Profile; it does not need a sixth bottom-navigation item.

## 5. Feature requirements

### 5.1 Driver registration and verification

Required during onboarding:

- Mobile-number login and OTP verification.
- Preferred language: Malayalam, English, or Hindi.
- Name, profile photo, phone number and address.
- Identity document: Aadhaar or an approved alternative.
- Driving licence.
- Truck information: registration number, truck/body type, length in feet, maximum capacity in tonnes.
- Truck documents: RC, insurance, permit and pollution certificate where applicable.

Document states are `pending`, `verified`, `rejected`, or `expired`. A driver may browse the app while pending, but cannot accept or start a paid trip until the required verification is complete.

### 5.2 Driver Home

Home must answer: “What should I do next?”

- Availability toggle: `Available`, `On trip`, or `Offline`.
- Current truck location from GPS, with a manual-location alternative.
- Primary actions: **Find Loads**, **Post Truck Availability**, **Nearby Services**, **Finance**.
- Active-trip card when a booking is assigned or in transit.
- Recommended loads ranked by pickup proximity, truck fit, capacity, preferred route, and pickup time.
- Notification badge for customer invitations, booking decisions, cancellations, and trip updates.

### 5.3 Find Loads

Drivers see only open loads compatible with their selected truck or a truck they choose from their profile.

Every load card displays:

- Pickup and destination.
- Distance from the driver to pickup.
- Weight in tonnes, including decimal values such as 1.5 or 4.5.
- Required truck type and minimum/required body length in feet.
- Customer’s offered price or `Negotiable`.
- Pickup date/time and urgent flag.
- Optional handling note.

Filters:

- Pickup radius/current location.
- Destination or preferred return route.
- Weight/capacity.
- Truck type and length.
- Price, pickup date/time, and urgent loads.

Actions:

- **Request Load** creates one pending request; it does not assign the load automatically.
- **Withdraw Request** is available while the request is pending.
- A driver cannot request a load that exceeds the selected vehicle capacity or does not fit the required truck body/type.

### 5.4 Post Truck Availability

The driver creates an availability post so customers can locate a suitable truck.

Fields:

- Current/manual location.
- Available now or availability date/time.
- Selected truck, type, length in feet, and capacity in tonnes.
- Preferred destination or return route.
- Optional note.

Customers can send a **Driver Invitation** from a suitable truck card. The driver can accept or decline the invitation. On acceptance, one booking becomes assigned.

### 5.5 My Trips

My Trips contains these tabs:

- Requested
- Accepted
- In Transit
- Completed
- Declined / Cancelled

Booking detail requirements:

- Customer name, profile photo, verification indicator, and contact button after assignment.
- Pickup and delivery details, load details, price, special notes and status timeline.
- **Start Trip** only for the assigned driver after acceptance.
- **Report Delivery** only after the trip begins.
- Customer confirms the delivery to close the booking.
- Display a clear timeline of request, assignment, trip start, delivery report, and completion.

### 5.6 Cancellation rules

| State | Driver action | Result |
| --- | --- | --- |
| Pending request | Withdraw request | No reason required; load remains open |
| Accepted, before trip start | Cancel booking with reason | Customer is notified; load can return to open status |
| In transit | No simple cancel button | Driver sees support/emergency workflow; preserve trip history |
| Completed/declined/cancelled | No cancellation | Terminal state |

The backend must enforce these rules. Repeated driver cancellations should be recorded for a later reliability policy but must not silently block a user in the first release.

### 5.7 Live trip tracking

- GPS sharing starts only after the driver taps **Start Trip** for an assigned booking.
- The customer sees the driver/truck position, last update time, pickup and destination while the trip is active.
- GPS sharing stops when delivery is confirmed, the trip is cancelled, or the driver manually stops it where policy allows.
- The driver must see an explicit tracking indicator and be able to understand when location is being shared.
- Poor connectivity must show the last known location and timestamp rather than pretending tracking is live.
- The customer tracking page uses an OpenStreetMap-based map; it does not require an embedded Google Map.

Technical flow:

```text
Driver device GPS
  -> active-trip location service
  -> protected trip_locations record in Supabase
  -> Supabase Realtime subscription
  -> customer tracking page updates the truck marker on an OSM-based map
```

Only the assigned customer and driver may read an active trip's location. The app stores the latest location and timestamp, not an unrestricted public driver-location feed. Send an update when the truck has moved meaningfully or after a bounded interval; stop updates outside an active trip.

### 5.8 Nearby Services — searchable list, no embedded map

This page is a fast service finder, not a map screen. It must work as follows:

1. **Location header**
   - If GPS is enabled and permission is granted, show the current locality and a “Location updated just now” timestamp.
   - If GPS is turned off, show **Turn on GPS** and open device location settings on tap.
   - If permission is denied, explain why location is needed, offer **Allow location**, and offer a manual city/location search as the fallback.
2. **Search**
   - A search field accepts plain-language searches such as “fuel pump”, “hospital”, “tyre workshop”, “weighbridge”, or “truck parking”.
   - Quick category chips: Fuel, Truck Stop/Lay-by, Weighbridge, Tyre, Workshop, Hospital.
   - The driver selects a search radius: 5 km, 10 km, 25 km, or 50 km.
3. **Result cards**
   - Show category icon, place name, address/locality, distance, and available open/close or phone information.
   - Show a prominent **Navigate** button and, when available, a Call button.
   - Results are ordered by distance; an empty result states that no matching service was found within the selected radius.
4. **Navigation hand-off**
   - Navigate opens the Google Maps app/browser with the service location as the destination. LORRY LINK does not need to display a Google map on this page.

#### Service-search implementation

- Use the device location only after permission. The Flutter location service resolves GPS coordinates to a display locality.
- The Flutter client calls a protected backend endpoint/Edge Function with the selected category, search text, radius, and coordinates.
- The backend calls Google Places API (New) and returns a small normalized result: place ID, name, category, latitude/longitude, address, phone/opening data when requested, and distance.
- Use Nearby Search for well-defined categories such as `gas_station`, `rest_stop`, `truck_stop`, `car_repair`, `tire_shop`, and `hospital`.
- Use Text Search for `weighbridge`, because it is not a dedicated Google Places filter type. Maintain a curated/verified weighbridge list as a later supplement; OpenStreetMap also has a weighbridge tag but should not be the only source of truth.
- Do not put a Google Places server key in the mobile application. Keep it in the Edge Function/backend and apply rate limits, result limits, and budget alerts.
- Run a nearby search only when the page opens, the user changes the category/radius, or presses Search—not continuously while the driver moves.
- The Navigate button launches a Google Maps directions URL with the driver as origin and the selected service as destination.

### 5.9 Mapping choice

Use a hybrid approach:

| Requirement | Chosen technology | Reason |
| --- | --- | --- |
| Driver nearby-service list | Google Places API, called from backend | Strong place search for pumps, hospitals, parking/rest stops and workshops; no embedded map UI required |
| Driver navigation | Google Maps app via directions URL | Familiar turn-by-turn navigation; LORRY LINK only hands off the destination |
| Customer live tracking screen | OpenStreetMap-based map with a production tile provider | Sufficient to display pickup, destination, and the live truck marker without Google Maps UI/API cost |
| Live location updates | Driver GPS + Supabase Realtime | The map provider does not create tracking; it only displays coordinates received from the driver app |

Do not use the public `tile.openstreetmap.org` or public Nominatim endpoint as production infrastructure. Use a commercial OSM tile provider or self-hosted tiles/geocoding, with visible OpenStreetMap attribution. The public OSM services have capacity, caching and usage restrictions.

#### Technical implementation checklist

**Nearby Services page**

- Flutter: location-permission service, current-location service, search Cubit, and `url_launcher` for external navigation.
- Supabase: an authenticated `nearby-services` Edge Function that holds the Google Places credential and validates category/radius limits.
- Google Places response fields: place ID, display name, formatted address, coordinates, primary type, phone/opening data only when needed, and route/distance summary when requested.
- App navigation URL: `https://www.google.com/maps/dir/?api=1&origin=<driver-lat>,<driver-lng>&destination=<place-lat>,<place-lng>&travelmode=driving`.

**Customer live tracking**

- Flutter driver: a foreground/background location service is enabled only for an active trip. Android needs an active foreground-service notification; iOS needs the background-location capability and user permission.
- Supabase: one `active_trip_locations` record per active booking, with `booking_id`, driver coordinates, accuracy, heading, speed and `recorded_at`.
- Server rule: only the assigned driver can update a location for an `in_transit` booking; only the assigned customer and driver can read it. Use a server-side command/function to validate this rule.
- Realtime: customer subscribes only to that booking's location record. The UI moves the truck marker and shows “last updated” time.
- Battery/data control: send a position after meaningful movement or a bounded interval (for example, 30–60 seconds while driving), not every GPS reading. Mark tracking as stale when no update arrives for the configured period.
- Map: render the pickup marker, destination marker and truck marker with `flutter_map`/MapLibre or equivalent using the chosen production OSM tile provider.

### 5.10 Finance tracker

Finance is driver-owned bookkeeping, not an in-app payment gateway in the first release.

Per-trip fields:

- Agreed freight amount.
- Advance received.
- Fuel, toll, parking, food, tyre/repair and other expenses.
- Outstanding balance.
- Net earnings.

Views:

- Current-trip balance.
- Daily, weekly and monthly income/expense totals.
- Completed-trip history.

## 6. Shared booking rules

There are two legitimate ways to form a booking:

```text
Customer posts a load -> Driver requests it -> Customer assigns one driver

Driver posts truck availability -> Customer sends invitation -> Driver accepts it
```

In both cases:

- Exactly one driver can be assigned to one load.
- Full contact details are revealed only after assignment.
- Both parties receive in-app notifications for request, invitation, acceptance, decline, trip start, delivery report and cancellation.
- The server, not only the mobile UI, validates identity, ownership, vehicle fit, state changes and duplicate actions.

## 7. Data required

| Entity | Required data |
| --- | --- |
| Driver profile | Name, phone, photo, language, address, verification state |
| Driver documents | Type, secure file reference, verification state, expiry date |
| Vehicle | Registration number, type, body length, capacity, document state |
| Truck availability | Vehicle, location, availability time, preferred destination/route, note, status |
| Load | Pickup/destination, weight, required type/feet, price, time, note, lifecycle status |
| Booking | Load, driver, assignment path, state, cancellation reason, timestamps |
| Trip location | Booking, latitude/longitude, recorded time, tracking state |
| Finance entry | Booking, category, amount, note, entry time |
| Roadside place | Category, map-provider identifier, location and contact/directions metadata |

## 8. MVP acceptance criteria

The driver-side MVP is complete when a verified driver can:

1. Set truck availability with vehicle capacity and body length.
2. Find a compatible nearby load and send a request.
3. Receive an assignment notification and contact the customer after assignment.
4. Start a trip, share location, report delivery, and see the completed trip.
5. Withdraw a pending request or cancel an accepted trip with the required policy.
6. Find fuel pumps, lay-bys, weighbridges, service centres and tyre support on a map.
7. Record income and expenses against a completed or active trip.
8. Use the main workflow in Malayalam, English and Hindi.

## 9. Delivery order

1. Driver profile, truck data, documents and verification status.
2. Vehicle availability, load filters, compatibility logic and request/invitation flows.
3. Booking lifecycle, notifications, contact visibility and cancellation rules.
4. Live trip tracking and customer tracking screen.
5. Nearby-services map.
6. Finance tracker, reporting, usability testing and release hardening.

## 10. Decisions to confirm before implementation

- Which document types are mandatory before a driver can accept a trip?
- Can one driver register multiple trucks in the first release?
- Is price fixed, negotiable, or can drivers submit a counter-offer?
- What exact cancellation/refund/penalty policy applies after a customer assigns a driver?
- Which map/place provider will supply tracking, directions and nearby services?
- Who verifies documents: automated checks, internal staff, or an external provider?
