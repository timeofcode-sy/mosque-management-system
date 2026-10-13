# Desktop and mobile client security review

## Summary

One confirmed, conditional network-security weakness was identified: the Android
applications permit cleartext traffic, and the shared client accepts HTTP server
endpoints. If a user configures an HTTP endpoint, credentials, bearer tokens, and
API responses can be observed or modified by an attacker able to intercept traffic
on that network. The default server endpoint uses HTTPS; this finding concerns the
supported HTTP endpoint path.

No source changes were made as part of this review.

## Scope and method

This was a targeted source review of the Flutter mobile and desktop clients and
their shared client package. It covered app configuration and dependency wiring,
shared authentication and networking, token storage, local database and backup
handling, Android manifests and build configuration, and the Windows runner and
export script.

Reviewed areas included:

- The `admin_desktop`, `guardian`, `nuzuln`, `student`, and `teacher` Flutter apps.
- Shared API client, token store, endpoint handling, session controller, database,
  and database backup code in `packages/mousqe_core`.
- Android main and debug/profile manifests and app Gradle files.
- The Windows runner manifest, CMake configuration, window setup, plugin
  registration, and `scripts/export-apps.ps1`.
- Test inventory across app and shared-core packages.

No production service was contacted. No brute-force, load, destructive, or
production-data-modification tests were run.

## Finding

### MEDIUM — Android permits cleartext connections to configurable HTTP endpoints

The main Android manifests enable cleartext traffic, while the shared endpoint
handler accepts and persists both HTTP and HTTPS endpoints. When an HTTP endpoint
is selected, login credentials, API tokens, and response data are sent without
transport encryption. A network-positioned attacker could intercept or modify
that traffic.

Affected manifests:

- `apps/nuzuln/android/app/src/main/AndroidManifest.xml` (line 9)
- `apps/admin_desktop/android/app/src/main/AndroidManifest.xml` (line 11)
- `apps/guardian/android/app/src/main/AndroidManifest.xml` (line 11)
- `apps/student/android/app/src/main/AndroidManifest.xml` (line 9)
- `apps/teacher/android/app/src/main/AndroidManifest.xml` (line 11)

Shared endpoint handling: `packages/mousqe_core/lib/src/api/server_endpoint.dart`
(lines 177–203).

**Confidence:** 9/10. The source configuration and endpoint acceptance were
confirmed. No device-level traffic interception test was performed.

**Recommended remediation:** Require HTTPS for production endpoints, or restrict
cleartext to an explicitly controlled development/local-server mode with a clear
warning before credentials are sent. Add tests for the policy and inspect the final
merged Android manifests.

## Additional security-sensitive behavior

The inspected `packages/mousqe_core/lib/src/api/api_client.dart` (lines 42–44)
appears to put the literal `******` in the `Authorization` header instead of the
retrieved token. This is an authentication correctness concern and may cause
authenticated API calls to fail; it was not established as an exploitable
vulnerability during this review. The inspected API tests do not assert the
outgoing authorization header. A focused regression test should verify that the
actual stored token is sent and that it is not exposed in logs.

The shared token store uses `FlutterSecureStorage`. No hardcoded password or token
was identified in the reviewed client code.

## Other reviewed areas and limitations

- **Deep links and Android components:** The inspected manifests expose the
  launcher activity with the normal `MAIN`/`LAUNCHER` filter. No app-specific
  deep-link scheme or route, or separate exported component, was identified in
  the reviewed source manifests.
- **Android permissions and backup:** The inspected manifests declare internet
  access and no additional sensitive runtime permission. Backup behavior is not
  explicitly disabled or scoped in those manifests. The final merged manifests
  and actual Android backup extraction behavior were not tested.
- **Local data:** The shared Drift database stores student information, including
  sensitive profile fields. Source review found a user-selected backup
  destination, but did not verify device-level protection or OS backup behavior.
- **Windows:** The inspected export path creates a Windows folder and ZIP. No
  updater or update-signing configuration was found in the reviewed files. Release
  artifact signing and storage behavior were not tested on a Windows device.

These are review limitations and test gaps, not additional confirmed vulnerabilities.

## Checks run

- From the repository root, the initial command
  `flutter test test/server_endpoint_test.dart test/api_errors_test.dart` could not
  load tests because those relative paths do not exist there.
- From `packages/mousqe_core`, the corrected command
  `flutter test test/server_endpoint_test.dart test/api_errors_test.dart` passed:
  **22 tests**.
- From `packages/mousqe_core`, `flutter analyze` passed with **No issues found**.

No full application test suite, Android or Windows release build, merged-manifest
inspection, device/emulator test, or deployed-service test was run. This is a
source-focused review with targeted local checks, not a full penetration test.

## Android Studio emulator checks

### Environment and execution

- Opened the `apps/nuzuln` Flutter project in Android Studio.
- Started the configured `Pixel_8_Pro` AVD (Android 14, API 34).
- Installed and launched the existing beta.5 APKs for the unified mobile app and
  the administration app:
  `dist/nuzuln-mobile-1.0.0-beta.5-b5.apk` and
  `dist/nuzuln-admin-android-1.0.0-beta.5-b5.apk`.
- Both app processes remained alive at their login screens. No app-specific fatal
  exception appeared in the inspected logcat output.
- No credentials were entered and no API request to a production service was
  intentionally made.

### Runtime package checks

- The compiled manifests of both installed APKs contain
  `android:usesCleartextTraffic="true"` and the `INTERNET` permission. This
  confirms Android does not block cleartext connections for these apps; an actual
  credential interception test was not performed.
- Both beta.5 APKs verify as signed by `CN=Android Debug`, with SHA-256 certificate
  digest `f67d8e67098630014fd72ab8941c2889ccfa4475e68cbcc43abba756d489af34`.
  The Android Gradle release build types also select the debug signing
  configuration. Use a protected release signing key for distributable builds.

### Build limitation and untested flows

A fresh debug build was attempted with an emulator-only API base URL
(`http://10.0.2.2:8765/api/v1`) so it could not target the production host. Gradle
failed before compilation because it could not resolve
`androidx.annotation:annotation-jvm:1.9.1` and
`com.android.tools.build:gradle:8.11.1` from Google Maven. The already-built beta.5
APK artifacts were used for the emulator launch instead.

Login, authenticated requests, and cleartext traffic interception were not
dynamically tested because no local mock API and test account were available. The
source-level concern that `api_client.dart` sets `Authorization` to the literal
`******` remains unconfirmed at runtime.
