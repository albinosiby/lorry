# LORRY LINK - Flutter app build plan

Prepared: 12 October 2026

Source: `C:/Users/albin/Downloads/LORRY_LINK_Product_Requirements_Document (2).pdf`, all three supplied PDF pages (printed pages 2-4).

This plan expands the supplied requirements into screens, workflows, implementation tasks, and acceptance checks. Items marked **Proposed** are implementation choices or additions, not requirements stated in the PDF. The workspace was empty when reviewed; there is no existing Flutter application to extend. This deliverable is a plan only.

## 1. Product and first-release scope

Build one Flutter mobile app with a role selected during account setup:

- **Shipper:** publish and manage loads, review requests, accept or decline bookings, view shipment progress, and mark delivery complete.
- **Transporter / Driver:** discover available loads, filter results, request bookings, view decisions, and update accepted trips.
- **Broker:** optional in the PRD. **Proposed:** defer until its permissions and relationship to the other roles are defined; no commission management in the core release.

The first release includes email/password and Google sign-in, password recovery, profiles, load publishing/discovery, booking coordination, manual shipment status updates, and in-app notifications.

Live GPS tracking, payments, bidding, commissions, chat, ratings, fleet management, document verification, and an admin portal are not specified in the supplied core scope. Treat these as separate future requirements. Push notifications are also optional; in-app notifications satisfy the PRD.

**Proposed delivery target:** Android first, using platform-safe Flutter code suitable for an iOS release after iOS build/signing and real-device testing. Tablet layouts should remain usable; web/desktop publication is a separate deliverable.

## 2. Navigation and screen inventory

Shipper bottom navigation: **Home | Post Load | My Loads | Profile**.

Transporter/driver bottom navigation: **Home | Find Loads | My Trips | Profile**.

Notifications open from a bell in the main app bar. Load and booking details open as child routes. Incoming shipper requests live inside My Loads and individual load details. Profile editing reuses the Profile screen.

There are **13 core screen types** in the PRD. Role-specific Home and Load Details layouts reuse shared components. Filters, confirmations, and request forms can be sheets/dialogs rather than additional full screens. Optional introductory slides and the password-reset landing experience depend on the chosen authentication service.

| ID | Screen / access | Main content and functions | Validation and important states |
| --- | --- | --- | --- |
| S01 | Splash / Welcome - everyone | Brand display; resolve session; route to sign-in, unfinished profile/role setup, or the correct Home. Welcome explains posting and finding loads. | Startup/loading; recoverable initialization error; never flash a protected screen before session resolution. |
| S02 | Sign In - signed-out users | Email, password, show/hide password, Sign In, Continue with Google, Create Account, Forgot Password. | Required and valid email; required password; submitting; failed credentials/network; Google cancellation; unfinished Google profile goes to setup. |
| S03 | Create Account / Complete Setup - new users | Name, email, password, and primary role. Google users complete missing profile/role fields without entering a new password. | Required fields; authentication-service password rules; duplicate-account error; retain entered non-sensitive values after failure. **Proposed:** password confirmation. |
| S04 | Forgot Password - signed-out users | Email input; request reset link; confirmation and return to sign-in. | Valid email; sending/error states; neutral success message; provider-supported reset-link handling. |
| S05 | Profile - authenticated users | View and edit basic profile details; show selected role; sign out. **Proposed:** optional phone/contact details only if contact functionality is enabled. | Save/cancel changes; save failure; email change follows auth-provider verification. **Proposed:** primary role stays fixed in MVP. |
| S06 | Notifications / Status Updates - authenticated users | Booking requests, accepted/declined decisions, shipment updates; tap to open the associated load or booking. **Proposed:** unread indicator and mark as read. | Loading, empty, retry, pagination; restricted or removed target; notifications only for the recipient. |
| S07 | Home - role-specific | Greeting and shortcuts. Shipper: Post Load action, recent own loads, pending request summary. Driver: Find Loads action, available loads and current trips. | Loading, no activity, retry; refresh after posting or status changes. Summary counts are proposed convenience features. |
| S08 | Post / Edit Load - shipper | Pickup, destination, cargo description, required vehicle type, pickup date; optional expected price and contact preference; validate and publish/save. | Required fields; submitting; save error; prevent repeat publish. **Proposed:** future/current pickup date, nonnegative price with explicit currency, warn before discarding changes. Edit reuses this form. |
| S09 | Find Loads - transporter/driver | Available load cards: origin, destination, pickup date, vehicle type, optional price. Filter by location and vehicle type; open details; refresh and load more. | Loading, no matches with Clear Filters, network retry; preserve filters on return. **Proposed:** pickup/destination filtering to support finding return loads manually. |
| S10 | Load Details - permitted viewers | Full route/cargo/vehicle/date/price information. Owner: edit/cancel and open requests. Driver: request booking; contact owner only where enabled. | Load closed/cancelled/missing; request already exists; booking submission in progress; stale availability. Confirm requesting with a small summary sheet. |
| S11 | My Loads / Requests - shipper | Own listings with statuses; open a listing and its incoming requests; inspect requester details; accept/decline; open resulting booking. | Empty listings/requests; refresh; acceptance conflict; confirmation for cancellation or consequential decisions. Status tabs/filtering are proposed presentation choices. |
| S12 | My Bookings / Trips - transporter/driver | Own requested, accepted, in-transit, completed, and cancelled bookings; include declined requests in history; open booking details. | Empty per status; loading/retry; list updates after decisions and trip actions. **Proposed:** withdraw a pending request, subject to final cancellation rules. |
| S13 | Booking Details - booking parties | Load summary, other party's basic permitted contact details, current status; shipper delivery-completion action; transporter accepted-trip status actions. **Proposed:** timestamped status timeline. | Role/status-specific action visibility; confirm sensitive actions; refresh on conflict; loading/missing/unauthorized states. |

### Load form and reusable components

Use a route section for pickup and destination, a cargo section for cargo description and vehicle type, and a schedule/details section for pickup date, optional expected price, and contact preference. Keep the primary Publish/Save action visible without obstructing keyboard or scrolling.

Shared components: load card, route summary, vehicle selector, location picker, status badge with text, booking-request card, notification row, primary button with progress, form field, loading/empty/error panels, and confirmation dialog.

**Proposed visual direction:** use the document's deep green as a starting brand color, light surfaces, readable type, and strong action contrast. Show locations, dates, vehicle type, and status prominently. Establish a 390 x 844 logical-pixel phone design baseline before UI work; allow smaller screens, larger text, safe areas, and keyboard insets.

## 3. Main user flows

### First use and returning users

Welcome -> Sign In or Create Account -> select/complete primary role -> role-specific Home.

Returning users with a valid session go directly to their Home. Password-reset links use the selected auth service's supported flow. Protected deep links resume after successful sign-in when the user has permission.

### Shipper

Home -> Post Load -> validate -> publish -> My Loads -> Load Details -> incoming requests -> accept one or decline -> Booking Details -> view shipment updates -> mark delivery complete.

### Transporter / driver

Home -> Find Loads -> location/vehicle filters -> Load Details -> request booking -> My Trips (Requested) -> receive decision -> Booking Details (Accepted) -> start trip (In Transit) -> completion flow.

### Return-load discovery

After arranging an outbound journey, search for loads with a pickup near its destination and a destination toward the driver's return area. **Proposed MVP:** reuse manual location filters; do not assume automated matching, GPS proximity, route optimization, or saved vehicle locations.

## 4. Status model and business rules

The PRD names Open, Requested, Accepted, In Transit, Completed, and Declined/Cancelled. Implement load availability separately from individual booking requests so several requests do not incorrectly close an available listing.

**Proposed load lifecycle:** Open -> Assigned -> In Transit -> Completed, with Cancelled as a terminal path where permitted. Assigned is an internal/UI load state introduced by this plan when a booking is accepted.

**Booking lifecycle:** Requested -> Accepted -> In Transit -> Completed. Requested can become Declined; cancellation transitions require the agreed policy. Declined and Cancelled should be distinct stored values even if grouped in history.

| Action | Actor | Required condition / result |
| --- | --- | --- |
| Publish load | Authenticated shipper | Required data valid; create an Open listing owned by the caller. |
| Edit/cancel listing | Its shipper owner | Ownership enforced server-side. **Proposed:** normal edits only while Open; cancellation after acceptance uses the booking cancellation flow. |
| Request booking | Authenticated transporter/driver | Listing Open; caller is not its owner. **Proposed:** one active request per driver per load. |
| Accept/decline request | Load's shipper owner | Request still Requested. **Proposed:** accept exactly one booking per load; atomically assign it and close remaining pending requests with a clear reason. |
| Start trip | Assigned transporter/driver | Booking Accepted; move booking and load to In Transit together. |
| Complete shipment | Authorized booking party under agreed policy | Booking was accepted and is not cancelled/declined/completed; preserve actor and timestamp. |
| Cancel/withdraw | Eligible party under agreed policy | Confirm action, record reason/actor, notify the other party; server rejects disallowed transitions. |

**Completion ambiguity:** the PRD gives shippers a delivery-completion action and also describes drivers marking trips complete. **Proposed resolution:** driver reports delivery via a `deliveryReportedAt` event, and shipper confirms final Completed status. This adds a confirmation step that needs product agreement; do not silently remove either role's intended action. Decide whether direct Accepted -> Completed is allowed for a missed start update, since the PRD permits accepted bookings to move to Completed.

**Cancellation proposal:** drivers may withdraw Requested bookings; either party may cancel an Accepted booking with a reason; disallow self-service cancellation once In Transit until an operational policy is defined. Do not automatically reopen a cancelled assigned load; let its owner explicitly republish it after validation. These are proposed policies, not confirmed PRD rules.

Enforce ownership, role permissions, valid transitions, and single acceptance on the backend, not only through hidden UI buttons. Reject conflicting/stale updates and show the refreshed record. Repeated taps or network retries must not create duplicate loads, requests, or state transitions.

## 5. Flutter implementation structure

Follow the existing personal Flutter blueprint with:

- `flutter_bloc`: Cubit for forms, filters, profile and straightforward fetches; BLoC for auth/session and coordinated booking transitions where useful.
- `go_router`: guarded routes and role-specific navigation shells; retain each tab's navigation stack.
- `get_it`: manual dependency registration; factory-owned BLoCs/Cubits and shared repositories/services.
- `flutter_screenutil`: design-based sizing plus constraint-based layout; mobile below 600, tablet 600-1199, desktop 1200+ logical pixels.
- Material 3 design system; accessible text scaling, status labels, large tap targets, and bounded wide-screen forms.
- Repository interfaces separating UI/state from backend implementations. **Planning default:** REST through Dio; final backend/auth choice remains open.
- Secure storage for REST session credentials, ordinary preferences in shared preferences; backend-managed session storage when using an auth SDK instead.

Do not pin dependency versions until the Flutter project and its SDK version exist. Do not implement multiple backends unless required.

```text
lib/
  main.dart
  config/
    app_config.dart
    routes/routes.dart
    routes/routes_config.dart
  constants/
    app_constants.dart
    api_path.dart
    assest_path.dart
  design_system/
    design_system.dart
    tokens/
    components/
    layouts/
    feedback/
  core/
    settings/
    walk_through/       # only if introductory slides are selected
  di/injection.dart
  modules/
    auth/
    home/
    profile/
    loads/
    bookings/
    notifications/
  utils/
    exceptions/app_exception.dart
    services/
    helpers/
    mixins/
```

Each feature contains its models, repositories, screens, necessary `bloc/` or `cubit/`, and feature-specific widgets. Use the direction `screen -> BLoC/Cubit -> repository interface -> implementation -> service`.

Suggested routes: `/welcome`, `/sign-in`, `/sign-up`, `/forgot-password`, `/complete-profile`, `/home`, `/loads/new`, `/loads/find`, `/loads/mine`, `/loads/:loadId`, `/loads/:loadId/edit`, `/loads/:loadId/requests`, `/trips`, `/bookings/:bookingId`, `/notifications`, `/profile`. The requests route can share the My Loads/request-detail UI. Validate IDs, enforce role redirects, and handle unknown/missing records.

## 6. Backend and data requirements

| Entity | Main fields |
| --- | --- |
| User profile | Auth user ID, name, email, primary role, optional permitted contact fields, created/updated timestamps. Passwords belong to the auth service, never profile records. |
| Load | ID, shipper ID, pickup/destination IDs and display labels, cargo description, vehicle type, pickup date, optional expected price/currency, contact preference, availability status, accepted booking ID, timestamps/version. |
| Booking | ID, load ID, driver ID, booking status, requested/accepted/started/completed timestamps, delivery-reported timestamp if adopted, cancellation/decline reason where needed, updated version. |
| Status event | ID, booking ID, previous/new status or event type, actor ID, timestamp, optional reason. Proposed for reliable history and conflict diagnosis. |
| Notification | ID, recipient ID, event type, load/booking ID, display summary, created/read timestamps. |
| Reference data | Supported vehicle types and normalized locations. Exact choices are a product decision. |

Backend capabilities: account authentication and Google sign-in, password reset, profile read/update, paginated load discovery with filters, own listings, create/edit/cancel load, booking request and decisions, permitted status transitions, own bookings, notifications and read state.

Acceptance and competing requests require an atomic backend operation. Send notification records after successful changes, with retry/deduplication so a notification failure does not roll back a successful booking or duplicate messages.

**Proposed location approach:** searchable normalized city/locality selection for MVP. Store stable location IDs; display readable names. No device-location permission is required for manual search. Radius search or map/geocoding integration requires a separate provider and agreed accuracy/cost expectations.

**Proposed refresh behavior:** pull to refresh, refresh on app resume and after mutations, plus modest foreground polling while viewing active bookings/notifications if the backend has no realtime mechanism. Show last-updated information for stale shipment data. Do not call this live GPS tracking.

Keep provider secrets on the backend, restrict contact details to the agreed audience, and scope all private queries to the authenticated user. Define account deletion/data-retention behavior during release preparation with the selected stores and backend.

## 7. Build order and acceptance gates

Effort ranges below are rough planning estimates in working days, assuming one experienced Flutter developer, timely product decisions, and a supported backend/auth service. They are not delivery commitments; unfamiliar infrastructure or added scope can increase them.

| Phase | Work | Exit condition | Estimate |
| --- | --- | --- | --- |
| 1. Product decisions and wireframes | Confirm role scope, backend, location/vehicle lists, completion/cancellation/contact policies; sketch all 13 screen types and both journeys. | Agreed screen map, fields, role/action matrix and status transitions. | 2-3 days |
| 2. Flutter foundation and design system | Create project; themes/components; ScreenUtil; routing; DI; repository interfaces; representative mock records. | Both role shells navigate; shared states/forms work on phone and tablet. | 2-3 days |
| 3. Authentication and profile | Splash/session restoration, email/Google sign-in, signup/role completion, reset password, profile, sign-out. | New and returning users reach the correct Home; unauthorized routes blocked. | 3-4 days |
| 4. Load publishing and discovery | Role Home, post/edit load, My Loads, Find Loads with filters, Load Details; backend permissions. | Shipper publishes; another permitted account finds matching loads; invalid edits rejected. | 4-6 days |
| 5. Booking and trip lifecycle | Request, review, accept/decline, My Trips, Booking Details, agreed delivery/cancellation rules; atomic acceptance. | Two-account journey works through completion; competing acceptance is prevented. | 4-6 days |
| 6. Notifications and resilience | In-app updates, notification links, refresh, retry, stale-data handling, duplicate-action protection. | Both parties see reliable updates and recover from network failures. | 2-3 days |
| 7. QA and release preparation | Automated checks, real-device testing, accessibility, signing/configuration, store assets and release build. | Agreed acceptance checklist passes; release candidate built and reviewed. | 3-5 days |

Total indicative effort: **20-30 working days (roughly 4-6 weeks)** under those assumptions. A custom backend is a separate workstream and may extend the schedule. Store review time and iOS-specific setup are not included.

Develop a complete vertical slice early: **shipper publishes -> driver discovers -> driver requests -> shipper accepts -> driver starts -> delivery completes**. Connect each feature to the real backend as it is built, rather than leaving all integration until the end. Label any mock-only prototype clearly.

## 8. Testing and release acceptance

- Auth: signup/login/reset, Google cancellation and incomplete profiles, session restoration/expiry, sign-out, role redirects and protected deep links.
- Forms and discovery: invalid required data, optional price, date boundaries, normalized-location and vehicle filters, pagination, empty results, edit permissions.
- Bookings: duplicate requests, simultaneous shipper acceptance attempts, request/accept against a closed load, forbidden status transitions, cancellation and agreed completion policy.
- Access: one user cannot edit another's listing, accept another shipper's request, view private bookings/notifications, or invoke forbidden actions directly through APIs.
- Resilience: failed publish, timeout after server success, repeated taps, notification retries, stale views, and network loss during status updates. Preserve unsent form input in memory; persistent offline drafts are optional scope.
- UI: representative small/large phones, tablet, breakpoint edges, increased text size, keyboard, long addresses, back navigation, preserved tab state, clear status labels.
- Automation: targeted repository/state tests, router and important form widget tests, backend permission/concurrency tests, and an end-to-end journey using two separate accounts.
- Delivery checks: format, `flutter analyze`, relevant tests, selected-platform release build, and a real-device smoke test. Add iOS checks when included in the release target.

The MVP is ready when two real users can complete the published-load-to-delivery journey, every role/action rule is enforced server-side, in-app updates reach the correct account, and no critical issue remains in authentication, booking correctness, access control, or core screen usability.

## 9. Decisions to settle before implementing dependent features

1. Backend/auth provider, existing infrastructure, and ownership of backend development.
2. Android-only launch or Android plus iOS; supported locales and currency.
3. Broker inclusion and permissions; whether primary roles may change or users may hold multiple roles.
4. One accepted booking per load (proposed) versus split-capacity/multiple-driver bookings.
5. Driver delivery reporting and shipper confirmation versus either party completing independently; whether skipping In Transit is allowed.
6. Cancellation rights before/after acceptance, in-transit exceptions, reopening policy, and retry after a declined/withdrawn request.
7. Required contact fields, visibility before/after acceptance, and which contact actions are enabled.
8. Supported vehicle types and location granularity; whether city filters are sufficient for return loads.

These decisions do not prevent initial wireframes, design-system work, or a clearly labelled mock prototype. Confirm them before locking the related backend contracts and production workflows.
