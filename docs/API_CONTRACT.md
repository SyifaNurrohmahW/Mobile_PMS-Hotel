# API Contract

This document records the contract found in the Express API source, not a proposed mobile API. Base URL is the API root ending in `/api/v1`. The backend globally requires `X-Timestamp` in ISO-8601 format and rejects timestamps more than five minutes from server time. Responses generally use `{ status, message, datetime, data? }`; successful HTTP status does not guarantee a business success, so consumers should also inspect `status` and `message`.

Authenticated routes require `Authorization: Bearer <access_token>`. `X-Branch-Code` is an optional branch override; when present, the backend validates it against the allowed branch codes in the token. Send the active branch for branch-scoped operations. The backend CORS allow-list is primarily relevant to browser clients; native mobile requests are not subject to browser CORS enforcement.

## Authentication

| Method | Path | Auth | Contract |
| --- | --- | --- | --- |
| POST | `/auth/login` | No | Body: `username`, `password`, `remember_me` (`"1"` or `"0"`). Success returns `data.access_token`, `data.refresh_token`, and `data.user_info`, including `user_code` and active/allowed branch context. |
| POST | `/auth/refresh-token` | No | Body: `user_code`, `refresh_token`, `remember_me` (string, boolean, or number accepted). Success returns rotated `data.access_token` and `data.refresh_token`. |
| GET or POST | `/auth/me` | Yes | Returns user profile and active/default/allowed branch scope in `data`. |
| POST | `/auth/switch-branch` | Yes | Body accepts `target_kode_cabang` or `kode_cabang`, or `target_branch_id` / `branch_id`. Requires branch-switch permission. Success returns rotated tokens and `data.active_branch`. |

The route is mounted as `/auth/refresh-token` (hyphen), despite the source filename `refresh_token.js`.

## Guest

All paths below are under `/reservasi` and use POST. They require authentication.

| Path | Request | Result |
| --- | --- | --- |
| `/guest/guest-search` | `keyword` and `kode_cabang`; keyword matches guest ID number, phone, or guest code. | `data` is a guest object, or `null` with a not-found business status. |
| `/guest/guest-create` | `kode_cabang`, `full_name`, `id_type` (`ktp`, `passport`, `sim`, `other`), `id_number`, `phone`; optional `email`, `nationality`. | Created guest object in `data`; duplicate ID/phone produces validation error. |
| `/guest/guest-list` | See backend handler for supported filters. | Guest collection. |

## Room Catalog and Booking

All paths below are under `/reservasi` and use POST. They require authentication.

| Path | Request | Result |
| --- | --- | --- |
| `/kamar/room-packages` | `kode_cabang`, ISO `check_in_date`, ISO `check_out_date` (must be later). | `data` is room-type groups with availability, rooms, features, cover image, and rate `packages` including rate plan code and price per night/total. |
| `/kamar/availability` | See backend handler for selection and date fields. | Availability result. |
| `/kamar/availability-range` | See backend handler for supported date range fields. | Availability result. |
| `/booking/reservation-create` | Required `kode_cabang`, `kode_guest`, `check_in_date`, `check_out_date`, and either `rooms[]` (`kode_tipe_kamar`, `kode_rate_plan`, optional `kode_kamar`/`kode_season`) or legacy single-room type/rate fields. Optional deposit, payment, cashier shift, `special_request`, and `extra_facilities`. A positive deposit requires `payment_method` and `kode_cashier_shift`. | Creates reservation and reservation-room records transactionally; returns booking result under `data`. Server revalidates guest, blacklist, branch scope, room availability, and pricing. |
| `/booking/reservation-data` | See backend handler for supported reservation key. | Reservation detail result. |

The server calculates price and availability; the mobile app must not treat a client-displayed total as authoritative. Re-read the returned booking data and display server errors without discarding the user's form state.

## Check-in, In-house, and Checkout

| Method | Path | Request | Result |
| --- | --- | --- | --- |
| POST | `/reservasi/checkin/checkin-submit` | Required `kode_reservasi_room`; optional `kode_cashier_shift`, `payment_method`, `deposit_amount`, guest count, early-check-in flags/amount, and payment reference fields. | Processes check-in, room allocation, folio, and optional additional deposit. Server enforces arrival date, early-check-in rules, blacklist, and branch scope. |
| POST | `/reservasi/inhouse/inhouse-list` | Optional `kode_cabang`, `keyword`. | In-house folio/reservation groups with guest, room, billing balance, and housekeeping summary. |
| POST | `/reservasi/inhouse/folio-detail` | See backend handler for folio identifiers. | Folio detail. |
| POST | `/reservasi/checkout/checkout-search` | Optional `kode_cabang`, `keyword`. | Checked-in room/folio groups with balance, invoice, and inspection status; result is limited to 50 source rows. |
| POST | `/reservasi/checkout/request-inspection` | Required `kode_kamar`; optional reservation-room code, branch, priority, assignee, notes, checklist. | Creates or returns the active housekeeping inspection task. |
| POST | `/reservasi/checkout/checkout-submit` | One of `kode_reservasi_room`, `kode_reservasi_rooms[]`, or `kode_folio`; optional `payment[]` with required method/amount and cashier shift for cash. | Validates folio settlement and completes checkout transactionally. Returns checkout/invoice details in `data`. |

The in-house and checkout lists use POST even though they are reads. Check-in and checkout are state-changing, financial operations; show a confirmation step and prevent duplicate submissions in the client. A successful inspection request is not the same as a completed inspection; the checkout search response exposes task/inspection state.

## Contract Caveats

- The backend uses both HTTP error codes and business `status` values. Parse the response envelope and preserve the server's Indonesian validation message.
- `X-Timestamp` is mandatory at the global API middleware, including public login/refresh calls.
- The current client sends the timestamp in UTC and branch code from secure session state.
- Some read and write handlers accept additional fields beyond those listed above. Consult their Joi schemas before adding fields; do not infer payloads from UI labels.