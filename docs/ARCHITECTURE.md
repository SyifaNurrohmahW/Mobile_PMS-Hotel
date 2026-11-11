# Architecture

## Product Boundary

This is an independently deployable Flutter repository for front-office staff. It does not contain, copy, or modify the web application or Express API. The mobile scope is operational reservations: room availability and packages, guest lookup/creation, booking, check-in, in-house operations, and checkout.

## Runtime Structure

- `lib/main.dart` initializes Flutter and starts the Riverpod `ProviderScope`.
- `lib/app` owns app initialization, Material configuration, and GoRouter navigation.
- `lib/core/config` reads compile-time flavor and API URL values.
- `lib/core/network` owns the Dio client, timestamp/auth/branch headers, response errors, and one-time token refresh/retry.
- `lib/core/storage` owns secure persistence of credentials and session context.
- `lib/features` groups presentation and feature data/domain code by business capability.

Riverpod providers are the dependency injection boundary. Presentation widgets consume providers; repositories call the shared API client. Feature logic should not access Dio or secure storage directly from screens.

## Session Lifecycle

1. Login posts `username`, `password`, and string `remember_me` (`1` or `0`) to `/auth/login`.
2. The access token, refresh token, user code, remember-me choice, and active branch code are stored with `flutter_secure_storage`.
3. Splash validates an existing token through `/auth/me`. On a `401`, the API client posts the refresh credentials to `/auth/refresh-token`, stores rotated tokens, and retries the original request once.
4. If restoration fails, secure session storage is cleared and the user is sent to login. Logout clears all secure storage.

The refresh retry is bounded to one attempt per request. A refresh endpoint failure clears the local session; the UI should treat resulting authentication failures as a request to log in again.

## Branch Scope

The active branch is sent as `X-Branch-Code`. The backend validates this value against the branch scope embedded in the access token. Branch switching is a dedicated authenticated endpoint that returns replacement tokens; changing only the local header is not a valid branch switch. The initial UI does not yet expose branch switching.

## Environments

`APP_ENV` supports `dev`, `staging`, and `production`; `API_BASE_URL` points to the matching `/api/v1` root. Values are supplied at build/run time with `--dart-define`, not committed as secrets. Android emulator access to a host machine's localhost uses `10.0.2.2`.

## Operational Feature Status

The navigation shell and auth flow are wired. Room package lookup, guest search, single-room booking, arrivals/check-in, in-house lists, and checkout lists call the API. Operational lists expose loading, error, empty, and populated states. Guest creation, multi-room booking, deposit/payment capture, full folio detail, inspection request workflow, and checkout settlement UI remain follow-up work. See [API_CONTRACT.md](API_CONTRACT.md) for verified endpoints and payload shapes before extending those flows.

## Validation

Run `flutter analyze` and `flutter test` from the repository root. Tests for token refresh, branch headers, and critical booking/check-in/checkout state transitions should be added alongside their feature implementations.