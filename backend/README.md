# HôpitalConnect API

Minimal Express 5 and MongoDB API for staff accounts, services, shifts, operational handovers, and hospital resources. Do not enter real patient data or identifiable medical information.

## Requirements and setup

- Node.js 20+
- MongoDB (local or hosted)

From `backend/`:

```sh
npm install
```

Create `.env` from `.env.example` (`Copy-Item .env.example .env` in
PowerShell), then set `MONGODB_URI`, `JWT_SECRET` (a randomly generated value
of at least 32 characters), and optionally `PORT` / `JWT_EXPIRES_IN`. Never
use the example JWT placeholder in a deployed environment.

### MongoDB Atlas (hosted MongoDB)

1. In MongoDB Atlas, create a project and a free/shared cluster.
2. Under **Database Access**, create a database user for this app. Grant it
   `readWrite` on the `hopital_connect` database only; this is separate from
   your MongoDB Atlas website login and does not need the `atlasAdmin` role.
3. Under **Network Access**, add the current public IP addresses of each
   teammate who will run the backend. Add a new entry if a teammate's address
   changes. Avoid `0.0.0.0/0`; it allows connections from anywhere.
4. Open **Connect** on the cluster, choose **Drivers**, and copy the MongoDB
   connection string. Replace `<db_password>` with the database user's
   password and append the database name `hopital_connect`, for example:

   ```text
   mongodb+srv://appuser:<db_password>@cluster0.xxxxx.mongodb.net/hopital_connect?retryWrites=true&w=majority
   ```

5. Put that full URI in `MONGODB_URI` in `backend/.env`. If the password
   contains characters such as `@`, `:`, `/`, `?`, or `#`, URL-encode the
   password before putting it in the URI. Do not send the URI or password in
   chat or commit `.env` to Git.

### Sharing setup with a team

The app connects to a teammate's locally running API; only that API connects
to Atlas. Flutter does not connect directly to Atlas. All teammates may use
the same Atlas cluster, app database, and dedicated `readWrite` database user.
After cloning, each teammate runs
`Copy-Item .env.example .env` (PowerShell) and puts the Atlas URI in their
local `backend/.env` and generates a local JWT secret. Alternatively, share
the configured `.env` through an
approved private secrets channel, never through Git, a public chat, or a
screenshot. The `.env` file is Git-ignored. Each teammate must also have their
current public IP in the Atlas IP Access List. Run the initial-admin bootstrap
only once for the shared database; the other teammates use the admin account
created there or create individual accounts from the app.

If a database password or URI is exposed in a chat, screenshot, or repository,
rotate that database user's password in Atlas before continuing.

In PowerShell, generate a JWT signing secret locally (copy the printed value
into `JWT_SECRET=` in `.env`):

```powershell
$bytes = New-Object byte[] 48
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
[Convert]::ToBase64String($bytes)
$rng.Dispose()
```

Save `.env` and start the API:

```sh
npm run dev
```

The API listens on `http://localhost:3000` by default; `GET /health` checks that the process is responding. Production startup uses `npm start`.

## Initial administrator

There is no public admin-registration endpoint. Once MongoDB is available and `.env` is configured, set the bootstrap password in the environment (do not put it in shell command arguments/history) and invoke the one-time CLI:

PowerShell:

```powershell
$secure = Read-Host "Initial admin password" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $env:BOOTSTRAP_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  npm run bootstrap:admin -- admin admin@example.test
} finally {
  Remove-Item Env:BOOTSTRAP_ADMIN_PASSWORD -ErrorAction SilentlyContinue
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}
```

POSIX shell:

```sh
read -s BOOTSTRAP_ADMIN_PASSWORD
export BOOTSTRAP_ADMIN_PASSWORD
npm run bootstrap:admin -- admin admin@example.test
unset BOOTSTRAP_ADMIN_PASSWORD
```

Passwords must be at least 10 characters and at most 72 UTF-8 bytes. The bootstrap user is protected by a unique database key; a second bootstrap attempt will fail. Use the resulting login token to create additional administrators.

## Authentication and response format

Login with `POST /auth/login` and then send `Authorization: Bearer <token>` on every other endpoint, including `GET /auth/me`. User responses expose only `_id`, `username`, `email`, `role`, `roles`, `serviceId`, and `active`; password hashes are never serialized.

Successful responses use the resource keys shown below (login is `{ "token": "...", "user": {...} }`, and `/auth/me` is `{ "user": {...} }`). Errors use `{ "error": { "message": "..." } }`.

Roles are `admin`, `doctor`, `nurse`, `secretary`, `service_head`, and `patient`. Only
admins can assign roles; service heads can read hospital resources and publish
handover notes. Secretaries have read-only access to hospital resources, their
own shifts, and handovers for their assigned service. An account may have more
than one role. `POST /auth/login` returns a short-lived `selectionToken` instead
of an access token when several roles are assigned; send that token and one
assigned role to `POST /auth/select-role` to receive the access token for that
role. Public registration
always creates a patient account; the requested role is never accepted from
the client. Only admins may list or manage all user accounts. API permissions
use only the role selected for the current access token; a multi-role account
does not combine permissions in one session. Only admins may create, update,
or delete hospital resources, services, and shifts. Handover authors are
derived from the authenticated account, never accepted from request data.

## Endpoint contract

All JSON request bodies reject unrecognized fields. MongoDB identifiers are ObjectId hex strings. Collections are bounded (200 users/services/hospitals/rooms/operating rooms; 500 shifts/handovers/beds/interventions/equipment).

| Method and path | Access | Request / query | Success response |
|---|---|---|---|
| `POST /auth/login` | Public | `{ "email", "password" }` | `{ "token", "user" }` for one role; `{ "selectionToken", "user" }` for multiple roles |
| `POST /auth/select-role` | Public, short-lived selection token | `{ "selectionToken", "role" }` | `{ "token", "user" }` |
| `POST /auth/register` | Public | `{ "username", "email", "password" }` | `{ "token", "user" }` (201; role always `patient`) |
| `GET /auth/me` | Authenticated | — | `{ "user" }` |
| `GET /users` | Admin | — | `{ "users": [...] }` |
| `POST /users` | Admin | `{ "username", "email", "password", "roles", "serviceId"?, "active"? }` (`role` remains accepted for older clients) | `{ "user" }` (201) |
| `PUT /users/:id` | Admin | Any subset of user fields above; `password` changes credentials | `{ "user" }` |
| `GET /services` | Admin, doctor, nurse, secretary, service head | — | `{ "services": [...] }` |
| `POST /services` | Admin | `{ "name", "location"?, "description"?, "active"? }` | `{ "service" }` (201) |
| `PUT /services/:id` | Admin | Any subset of service fields | `{ "service" }` |
| `GET /shifts` | Admin, doctor, nurse, secretary, service head | Optional `userId` and/or `date=YYYY-MM-DD` (UTC day, by shift start); secretary/service head limited to own shifts | `{ "shifts": [...] }` |
| `POST /shifts` | Admin | `{ "userId", "serviceId", "start", "end", "role" }` (ISO dates) | `{ "shift" }` (201) |
| `PUT /shifts/:id` | Admin | Any subset of shift fields | `{ "shift" }` |
| `GET /handovers` | Admin, doctor, nurse, secretary, service head | Optional `serviceId`; secretary/service head limited to assigned service | `{ "handovers": [...] }` |
| `POST /handovers` | Admin, doctor, nurse, service head | `{ "serviceId", "title", "content", "important"? }` | `{ "handover" }` (201) |
| `GET /hospitals` | Admin, doctor, nurse, secretary, service head | — | `{ "hospitals": [...] }` |
| `POST /hospitals` | Admin | `{ "name", "address"?, "phone"?, "active"?, "serviceIds"? }` | `{ "hospital" }` (201) |
| `PUT /hospitals/:id` | Admin | Any subset of hospital fields | `{ "hospital" }` |
| `DELETE /hospitals/:id` | Admin | — (hospital must have no rooms, operating rooms, or equipment) | `{ "hospital" }` |
| `GET /rooms` | Admin, doctor, nurse, secretary, service head | Optional `hospitalId` | `{ "rooms": [...] }` (includes occupied/available bed counts) |
| `POST /rooms` | Admin | `{ "hospitalId", "serviceId", "number", "floor"?, "type"?, "capacity"?, "status"? }` | `{ "room" }` (201) |
| `PUT /rooms/:id` | Admin | Any subset of room fields | `{ "room" }` |
| `DELETE /rooms/:id` | Admin | — (room must have no beds) | `{ "room" }` |
| `GET /rooms/:id/occupancy` | Admin, doctor, nurse, secretary, service head | — | `{ "occupancy": { "roomId", "capacity", "occupiedBeds", "availableBeds" } }` |
| `GET /beds` | Admin, doctor, nurse, secretary, service head | Optional `roomId` and/or `status` | `{ "beds": [...] }` |
| `POST /beds` | Admin | `{ "roomId", "number", "status"? }` (`free`, `reserved`, `cleaning`) | `{ "bed" }` (201) |
| `PUT /beds/:id` | Admin | Any subset of `roomId`, `number`, `status` (cannot assign `occupied`) | `{ "bed" }` |
| `DELETE /beds/:id` | Admin | — (bed must be unassigned) | `{ "bed" }` |
| `PUT /beds/:id/assignment` | Admin | `{ "patientId" }` (active User account with role `patient`) | `{ "bed" }` |
| `DELETE /beds/:id/assignment` | Admin | — (release; clears patient and sets status `free`) | `{ "bed" }` |
| `GET /operating-rooms` | Admin, doctor, nurse, secretary, service head | Optional `hospitalId` | `{ "operatingRooms": [...] }` |
| `POST /operating-rooms` | Admin | `{ "hospitalId", "name", "number"?, "serviceId"?, "status"? }` (`free` or `sterilization`) | `{ "operatingRoom" }` (201) |
| `PUT /operating-rooms/:id` | Admin | Any subset of operating-room fields | `{ "operatingRoom" }` |
| `DELETE /operating-rooms/:id` | Admin | — (room must have no interventions) | `{ "operatingRoom" }` |
| `GET /interventions` | Admin, doctor, nurse, secretary, service head | Optional `surgeonId`, `patientId`, `operatingRoomId`, and/or `status` | `{ "interventions": [...] }` |
| `POST /interventions` | Admin | `{ "surgeonId", "patientId", "operatingRoomId", "title", "start", "end", "equipmentIds"?, "status"? }` (ISO dates) | `{ "intervention" }` (201) |
| `PUT /interventions/:id` | Admin | Any subset of `surgeonId`, `patientId`, `equipmentIds`, `title`, `start`, `end`, `status` | `{ "intervention" }` |
| `DELETE /interventions/:id` | Admin | — | `{ "intervention" }` |
| `GET /equipment` | Admin, doctor, nurse, secretary, service head | Optional `hospitalId` and/or `status` | `{ "equipment": [...] }` |
| `POST /equipment` | Admin | `{ "hospitalId", "name", "type", "serialNumber", "serviceId" XOR "operatingRoomId", "status"?, "lastMaintenanceAt"?, "maintenanceDueAt"? }` | `{ "equipment" }` (201) |
| `PUT /equipment/:id` | Admin | Any subset of equipment fields | `{ "equipment" }` |
| `PUT /equipment/:id/maintenance` | Admin | Any subset of `status`, `lastMaintenanceAt`, `maintenanceDueAt` (`null` clears a date) | `{ "equipment" }` |
| `DELETE /equipment/:id` | Admin | — | `{ "equipment" }` |

Service JSON fields include `name`, `location`, `description`, `active`, and
`serviceType`. Supported service categories are `medical`, `surgical`,
`emergency`, `intensive_care`, `maternity`, `medico_technical`,
`administrative`, and `other`.
Shift JSON includes `userId`, `serviceId`, ISO-serialized `start`/`end`, `role`,
`userName`, and `serviceName`. Handover JSON includes `serviceId`,
server-assigned `authorId`/`authorName`/`createdAt`, `title`, `content`, and
`important`. User and service IDs in Flutter are MongoDB ObjectId hex strings.

Hospital `serviceIds` must reference existing services. A room's required
`serviceId` and an operating room's optional `serviceId` must be linked to its
hospital. Equipment must be assigned to exactly one service or operating room.
Room occupancy counts assigned beds, and an
active patient account can occupy at most one bed. Bed responses include only
the account ID, never account or medical details. Use synthetic patient
accounts/identifiers for testing. Intervention `surgeonId` must refer to an
active `User` with role `doctor`; `patientId` must refer to an active `User`
with role `patient`. Interventions store and return only these account IDs,
never user names, clinical details, or other patient data. Existing
intervention records created before these fields were added may be missing the
links; update them with valid IDs before relying on those records. Overlapping
active interventions in the same operating room are rejected (adjacent time
ranges are allowed); cancelled/completed entries do not reserve a slot.
Interventions may include `equipmentIds`; each item must be functional,
assigned to that operating room or its service, and free from overlapping
active interventions for that time range. Equipment status is `functional`,
`broken`, or `maintenance`; intervention status is `scheduled`,
`in_progress`, `completed`, or `cancelled`.
Room `type` is `single`, `double`, or `intensive_care`; `floor` defaults to
`"0"`, type to `single`, and capacity to 1 (2 for `double`) when omitted.
Room status is `available`, `full`, or `maintenance`; occupancy updates room
status unless it is in maintenance. Bed status is `free`, `occupied`,
`reserved`, or `cleaning`; only assignment can set `occupied`, and release
clears `patientId` and sets `free`. Operating-room status is `free`,
`in_progress`, or `sterilization`; intervention progress manages
`in_progress`, and sterilization blocks scheduling. Equipment with active
intervention reservations cannot be changed to a non-functional status.
The maintenance endpoint does not implicitly change equipment status: pass
`"status": "functional"` explicitly to mark it functional. `lastMaintenanceAt`
and `maintenanceDueAt` may be sent together or separately; send `null` for
either date to clear it.

Resource response fields:

- Hospital: `_id`, `name`, `address`, `phone`, `active`, `serviceIds`.
- Room: `_id`, `hospitalId`, `serviceId`, `number`, `floor`, `type`, `status`,
  `capacity`,
  `occupancy` (`roomId`, `capacity`, `occupiedBeds`, `availableBeds`).
- Bed: `_id`, `roomId`, `number`, `status`, `patientId`, `assignedAt`.
- Operating room: `_id`, `hospitalId`, `serviceId`, `name`, `number`, `status`,
  `scheduledCount`.
- Intervention: `_id`, `surgeonId`, `patientId`, `operatingRoomId`,
  `operatingRoomName`, `equipmentIds`, `title`, `start`, `end`, `status`.
- Equipment: `_id`, `hospitalId`, `serviceId`, `operatingRoomId`, `name`,
  `type`, `serialNumber`, `status`, `lastMaintenanceAt`, `maintenanceDueAt`.

Dates in JSON responses are ISO-serialized. List and create/update/delete
responses use the wrapper keys shown in the endpoint table; assignment and
discharge both return `{ "bed": ... }`.

## Testing

Run `npm test`. The Node test suite covers validation, resource serialization
and schema invariants, schedule-conflict checks, JWT signing, health, and
unauthenticated access; it does not require MongoDB. Full persistence,
login/authorization, and schedule-reservation integration testing requires a
MongoDB instance.

## Postman

Import `postman_collection.json`, set `baseUrl`, and set the `token` collection variable after logging in. Authenticated requests automatically use that bearer token.
