# End-to-end booking workflow

## Lifecycle and UI

Requested → accepted → items collected → in transit → delivery reported →
delivery confirmed. Declined and cancelled are separate outcomes.

Database status codes remain compatible with previous records: collection is
`accepted` plus `item_collected_at`, delivery reported is `in_transit` plus
`delivery_reported_at`, and delivery confirmed is `completed`. Consumers must use
the derived display stage and must not infer GPS activity from status alone.

Drivers select a compatible owned truck when requesting a load. New acceptance,
collection and trip-start operations lock the driver profile and validate that
the driver/truck has no other accepted or physically active trip. Historical
conflicts are preserved, not silently cancelled. Older accepted bookings without
a truck prompt the driver to select one before starting.

Every configured intermediate unloading stop must be confirmed before reporting
final delivery. The customer receives updates and can report a delivery issue.
Confirming receipt explicitly resolves the issue; its event history remains.

## Payment

Reporting delivery creates no new income. The assigned driver separately records
the money actually received after delivery, before or after receipt confirmation.
The booking shows agreed freight, collected total and outstanding balance.
Partial payments are supported. This records collection; it is not an online
payment gateway or a customer-confirmed bank settlement.

Each collection has a client-generated UUID used as the finance entry primary
key. Pending UUIDs persist in secure device storage for uncertain network retries.
The database locks the booking, validates the driver and remaining balance, and
rejects reuse of a UUID for a different collection. Confirmed legacy freight
income is included in totals and is never recreated by the migration.

Successful writes with failed reloads show “Saved—refresh pending” and block
further booking mutations until a successful refresh. Failed writes retain the
payment request ID. Manual Finance entries cannot bypass booking freight checks.

## Availability and GPS

After reporting delivery, the driver is no longer physically busy even while
receipt/payment is pending. Existing open/matched broadcasts close when reporting
new deliveries; the driver must post fresh availability at the new location.
Pending customer confirmation does not block that new availability.

Starting a trip requires GPS and writes its first position transactionally.
The Android foreground position stream feeds the upload process, with approximately
two-minute uploads and periodic retry/status checks. GPS-off retains the last
point; stale connectivity is not labelled GPS-off. All location-update endpoints
reject updates after delivery reporting. Historical tracking pages explicitly
show the last trip location rather than claiming a live broadcast.

Background behaviour with screen lock, battery restrictions and force-stop still
requires a real two-device field test. Exact upload timing is not guaranteed by
Android. No location flow can continue after the user force-stops the application.

## Synchronization

Authenticated, recipient-scoped notification events invalidate visible workflow
screens. Local successful mutations also invalidate them. Screens reload through
repositories, with debounce, reconnect/resume refresh and polling as fallback.
Tracking separately polls positions and booking status every 15 seconds.

RPC-only tables retain RLS and deny direct data access. The Supabase advisor's
informational “RLS enabled with no policy” entries for those tables are intentional.
The existing leaked-password-protection warning is account configuration, not
changed by this migration. Enable it when supported by the project plan:
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Driver-posted loads

Drivers can post freight from Home or Profile without changing account role.
Driver posting opens as a standalone page (`/driver/post-load`), not a customer
or Find Loads tab. Both Home shortcuts establish Profile as the return page;
Profile links push the posting/listing pages normally. `/driver/posted-loads`
holds owner listings; Track opens that load's assigned booking location. Legacy
`/loads/new` and `/loads/mine` driver links redirect to these standalone routes.
My Posted Loads uses the same owner workflow as customer listings: edit/cancel,
review requests, accept/decline, track the assigned carrier and confirm receipt.
Find Loads excludes the signed-in user's own freight before pagination; self-booking
is also rejected on the server. My Trips and driver Home trip actions only contain
bookings the user is transporting. Incoming requests explicitly pass `incoming: true`
and are scoped to owned loads. Tracking controls depend on the assigned driver ID,
not the account role, so a driver acting as load owner cannot publish their own GPS
over the carrier's position. Freight income belongs to the transporting driver.

`supabase/tests/driver_load_posting.sql` verifies publication, editing, self-booking
and outsider restrictions, request separation, acceptance, tracking, delivery,
payment ownership and cancellation inside a rolled-back transaction.

## General verification

## Ordered unloading navigation

Home, live tracking and the active booking's unloading controls share the same
Google Maps directions builder. Before collection it targets pickup only. After
collection it passes pending unloading locations in posting order, followed by
the final destination; completed original stop indices are excluded. Coordinates
are preferred, with place-name fallback for older loads. Maps does not mark stops
unloaded: drivers confirm each stop inside Booking details as before.

Google Maps URLs support only three intermediate waypoints in mobile browsers
(nine on other supported clients). To preserve the browser fallback without
silently losing stops, links use at most three waypoints plus a section endpoint.
Longer routes show a confirmation explaining the section endpoint and remaining
destinations. After unloading and marking stops complete, reopen directions for
the next section. https://developers.google.com/maps/documentation/urls/get-started

## Test coverage

`flutter test` covers state, routing, payment retries, UI actions and responsive
layouts. The opt-in hosted test is updated but not automatically run against
saved accounts. `supabase/tests/booking_workflow.sql`, executed inside BEGIN /
ROLLBACK, checks the database lifecycle, partial-payment deduplication, ownership,
truck fit/conflicts, intermediate stops, GPS-off, re-requesting declined bookings,
availability release and customer truck invitations. Test fixtures and queued
notifications roll back.
