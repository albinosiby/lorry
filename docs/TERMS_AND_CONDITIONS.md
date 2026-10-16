# Terms & Conditions UI

The sign-in and sign-up forms require an initially unchecked acceptance box.
Google sign-in, when enabled, uses the same gate. Password recovery and password
reset do not require it. The terms link pushes `/profile/terms`, which is readable
without an account; Back preserves entered form values and checkbox state.
Profile opens the same screen and shared content in
`lib/modules/account/models/terms_content.dart`.

The supplied content is an operational draft for app-owner/legal review before
public distribution. It is not a complete jurisdiction-specific legal agreement
or privacy policy. This change validates the checkbox in the UI only; it does not
store a versioned consent timestamp or enforce acceptance on the backend.
