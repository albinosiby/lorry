# Validation record

Verified on 13 October 2026 using Flutter 3.41.2 / Dart 3.11.0 on Windows.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 19 passed; hosted test skipped by default |
| `node tools/database-tests/test.mjs` | 36 database checks passed |
| Opt-in hosted Supabase test | Passed: real email/password Auth, profile/load repositories, competing acceptance, delivery completion, notifications, forbidden direct writes |
| Responsive widget checks | Widths 320, 599, 600, 1199, 1200 and 1440; increased text scale 1.8 |
| Visual inspection | Phone, tablet and desktop fixture previews; actual browser welcome and email sign-in |
| Android debug APK | Build succeeded; `build/app/outputs/flutter-apk/app-debug.apk` |
| Web release | Build succeeded; `build/web`; local browser preview on port 8080 |

Hosted QA accounts and their associated records were removed after testing. Their local credentials were deleted. Production code uses the hosted repositories; fake data is confined to tests.

## APK and UI review

The debug APK was installed through wireless ADB on a Motorola Edge 60 Fusion (Android 17, physical display 1220 x 2712). Version 1.0.0, build 1 is installed. After the phone was unlocked, follow-up checks verified signup validation, password-field keyboard visibility, scrolling to action buttons with the keyboard open, navigation to sign-in and password recovery, and a real rejected sign-in through the APK (`Email or password is incorrect.` using a nonexistent test address). Welcome, signup, keyboard/error states, sign-in and recovery layouts were visually inspected. The app stayed running, and inspected app logs contained no fatal exceptions, unhandled exceptions or RenderFlex overflow messages. Screenshots are saved in `artifacts/previews/qa-*.png`.

The installed APK and local build match by SHA-256: `b1703e5a7199c47818b4387a4ca31daef124122cc211f7ae747a20aaec891199`.

The follow-up automated run again passed 19 Flutter tests, 36 database checks and the analyzer. Expanded fixture previews under `artifacts/previews/qa-*.png` cover both roles: home, load discovery/management, load details, booking lists/details, notifications and profile, plus shipper load posting. These are Flutter widget renders with fake repositories, not proof of authenticated operation of each screen on the physical phone.

The hosted test previously verified real Auth and repositories through delivery completion. The full authenticated UI journey has not yet been driven on the phone. A claim that every APK function is fully verified would therefore exceed the evidence currently collected.

Email delivery and confirmation/reset links were not exercised with a real mailbox. The user confirmed saving the callback allowlist. SMTP configuration and a real-mailbox check remain necessary before external onboarding. Google sign-in is deferred by request. iOS compilation/device validation and store release signing were not performed on this Windows host.
