# Language selection

Login and sign-up contain a language picker. Profile → Settings offers the same
picker for customers and drivers. Options: English, Hindi, Malayalam, Tamil,
Telugu and Kannada, displayed in their native scripts.

The preference is device-local (`app_language` in SharedPreferences), survives
sign-out and normal restarts, and applies after a successful save. Storage errors
keep the previous selection. Reinstalling/clearing app data may reset it.

The choice updates Flutter's locale, built-in Material controls, date formatting
and application UI for both customer and driver sessions. Translations are
bundled offline under `lib/l10n`: navigation, authentication/onboarding, profile,
load forms/discovery/details, bookings/trips/tracking, vehicles/documents,
availability, customer truck discovery, finance, essentials, in-app notifications,
shared dialogs and validation, support and the shared operational Terms page.

`LocalizedText` is the UI boundary for stable app copy; `localize` handles String
APIs such as tooltips and navigation destinations. `localizedDecoration` handles
form labels/hints. Validation keeps its original English key and translates via
the field's `errorBuilder`, including errors already visible during a language
switch. Do not translate controller text, model values or API enum identifiers.
Raw `Text` is retained for names, addresses, cargo, notes and contact details.
Templates translate the surrounding UI while preserving routes, names and
amounts. Existing server language/profile fields are not changed.

English remains the fallback for unknown external content. Place/business names,
user-entered content, Google/OSM attribution and identifiers remain as supplied.
Android notifications delivered by the backend are not changed by this local
preference; localising closed-app push messages needs recipient language support
in the backend. Known in-app notification titles are translated for display.

Translations, especially legal terms, require native-speaker and app-owner/legal
review before public rollout. Concise UI equivalents are used for verbose
marketing text; this is not automatic translation of arbitrary user content.

Run `flutter test --concurrency=1 test/app_localizations_test.dart
test/language_picker_test.dart`. The separate `tool/localization` Dart package
contains AST-based migration/inventory utilities; it is not an app dependency.
