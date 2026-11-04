# PMS Hotel Mobile

Flutter application for hotel front-office staff. This repository is separate from the web and API repositories and is scoped to operational reservations.

## Requirements

- Flutter 3.44 or newer and Dart 3.12 or newer
- Android Studio/Xcode for the respective mobile platform
- Access to the Express PMS API

## Setup

```powershell
flutter pub get
flutter analyze
flutter test
```

Run against a locally hosted API on the Android emulator:

```powershell
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

For a physical device, use a reachable development host address instead of `10.0.2.2`. Do not use production credentials or secrets in build arguments.

## Environments

Environment values are compile-time `--dart-define` values; there is no checked-in `.env` containing secrets.

```powershell
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://dev-api.example.test/api/v1
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging-api.example.test/api/v1
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.example.test/api/v1
```

Replace example hosts with environment-specific values supplied by the deployment owner. Production must use HTTPS. `APP_ENV` controls the displayed flavor label; `API_BASE_URL` selects the backend.

## Current Scope

- App shell, flavor configuration, secure token storage, API client, login, session restore, and logout are implemented.
- Room package lookup, guest search, and a single-room booking flow are wired to the backend. Arrivals/check-in, in-house, and checkout lists use the real API and expose loading, error, empty, and populated states.
- Guest creation, multi-room booking, deposit/payment capture, richer folio detail, inspection request workflow, and checkout settlement UI remain follow-up work. Their backend routes and payload contracts are recorded in [docs/API_CONTRACT.md](docs/API_CONTRACT.md).
- The mobile client sends an ISO-8601 UTC `X-Timestamp` on each API request. Authenticated requests attach the stored bearer token and active `X-Branch-Code`.

## Project Docs

- [Architecture](docs/ARCHITECTURE.md)
- [API contract](docs/API_CONTRACT.md)