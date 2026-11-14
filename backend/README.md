# HôpitalConnect API

Minimal Express 5 and MongoDB API for staff accounts, services, shifts, and operational handovers. Do not enter real patient data or identifiable medical information.

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

Login with `POST /auth/login` and then send `Authorization: Bearer <token>` on every other endpoint, including `GET /auth/me`. User responses contain profile fields, role and service assignment IDs, doctor specialty/photo URL, and active state; password hashes and bootstrap keys are never serialized.

Successful responses use the resource keys shown below (login is `{ "token": "...", "user": {...} }`, and `/auth/me` is `{ "user": {...} }`). Errors use `{ "error": { "message": "..." } }`.

Roles are `admin`, `doctor`, `nurse`, `secretary`, and `patient`. Public
registration always creates a patient account; the requested role is never
accepted from the client. An administrator assigns secretaries to one or more
services and assigns doctors to a service. Doctors may have a specialty and a
photo URL for the patient booking flow. Only admins may list or manage all user
accounts. Patients may read active services and only their own appointments.
Secretaries may read appointments and doctors only for their assigned services.
Admins, doctors, and nurses may read staff services, shifts, or handovers;
doctors and nurses are restricted to their assigned service. Only admins may
create/update services and shifts. Admins, doctors, and nurses may create
handovers for their service. Handover authors are derived from the
authenticated account, never accepted from request data. Each user has a
separate read state for handovers.

Appointment availability is derived from the selected doctor's shifts.
Appointments occupy 30-minute slots, rounded up to the next half-hour in UTC.
A request must match an available slot and starts as `pending`. Secretaries
must claim a pending request before deciding it; the claim expires after
15 minutes and is acquired atomically. They can accept, reject with a reason,
or propose another available slot. Patients may accept or refuse a proposed
slot. Pending requests older than 24 hours are marked `isOverdue` in responses
so the secretary workspace can alert on them. Appointment status changes are
stored as in-app notifications for the patient; this API does not send push or
email notifications.

## Endpoint contract

All JSON request bodies reject unrecognized fields. MongoDB identifiers are ObjectId hex strings. Collections are bounded (200 users/services/doctors; 500 shifts/handovers/appointments).

| Method and path | Access | Request / query | Success response |
|---|---|---|---|
| `POST /auth/login` | Public | `{ "email", "password" }` | `{ "token", "user" }` |
| `POST /auth/register` | Public | `{ "username", "email", "password" }` | `{ "token", "user" }` (201; role always `patient`) |
| `GET /auth/me` | Authenticated | — | `{ "user" }` |
| `PUT /auth/me` | Authenticated | Profile fields: `firstName`, `lastName`, `email`, `birthDate`, `phone`, `address`, `emergencyContact`, `insurance`, `language`, `notificationPreferences`; password change requires `currentPassword` and `newPassword` | `{ "user" }` |
| `GET /users` | Admin | — | `{ "users": [...] }` |
| `GET /users/service/:serviceId` | Admin, doctor, nurse | — (non-admins: own service only) | `{ "users": [...] }` (active colleagues; no email/profile data) |
| `POST /users` | Admin | `{ "username", "email", "password", "role", "serviceId"?, "serviceIds"?, "specialty"?, "photoUrl"?, "active"? }` | `{ "user" }` (201) |
| `PUT /users/:id` | Admin | Any subset of user fields above; `password` changes credentials | `{ "user" }` |
| `GET /services` | Admin, doctor, nurse, secretary, patient | Patients receive active services; secretaries receive assigned services | `{ "services": [...] }` |
| `POST /services` | Admin | `{ "name", "location"?, "description"?, "active"? }` | `{ "service" }` (201) |
| `PUT /services/:id` | Admin | Any subset of service fields | `{ "service" }` |
| `GET /shifts` | Admin, doctor, nurse | Optional `userId` and/or `date=YYYY-MM-DD` (UTC day, by shift start) | `{ "shifts": [...] }` |
| `POST /shifts` | Admin | `{ "userId", "serviceId", "start", "end", "role" }` (ISO dates) | `{ "shift" }` (201) |
| `PUT /shifts/:id` | Admin | Any subset of shift fields | `{ "shift" }` |
| `GET /handovers` | Admin, doctor, nurse | Optional `serviceId` (doctors/nurses: own service only) | `{ "handovers": [...] }` (includes caller-specific `isRead`) |
| `POST /handovers` | Admin, doctor, nurse | `{ "serviceId", "title", "content", "important"? }` (doctors/nurses: own service only) | `{ "handover" }` (201) |
| `POST /handovers/:id/read` | Admin, doctor, nurse | — (doctors/nurses: own service only) | `{ "handover" }` |
| `GET /appointments/doctors` | Patient, secretary, admin | Optional `serviceId` | `{ "doctors": [{ "_id", "username", "specialty", "photoUrl", "serviceId" }] }` |
| `GET /appointments/availability` | Patient, secretary, admin | `doctorId` and `date=YYYY-MM-DD` (UTC) | `{ "durationMinutes": 30, "slots": [...] }` |
| `GET /appointments` | Patient (own only), secretary (assigned services only), doctor (own only), admin | — | `{ "appointments": [...] }` |
| `POST /appointments` | Patient | `{ "doctorId", "startAt", "reason"? }` (ISO date-time) | `{ "appointment" }` (201; status `pending`) |
| `PUT /appointments/:id` | Owner patient, secretary, admin | Patient: any subset of `doctorId`, `startAt`, `reason`, or `status: "cancelled"` for a future RDV; secretary/admin may update appointment fields | `{ "appointment" }` |
| `POST /appointments/:id/claim` | Secretary, admin | — | `{ "appointment" }`; secretary must be assigned to the appointment's service |
| `POST /appointments/:id/release` | Secretary, admin | — | `{ "appointment" }` |
| `POST /appointments/:id/decision` | Secretary, admin | `{ "action": "accept" }`, `{ "action": "reject", "reason" }`, or `{ "action": "propose", "proposedStartAt", "reason"? }` | `{ "appointment" }` |
| `POST /appointments/:id/proposal-response` | Owner patient | `{ "action": "accept" \| "reject" }` | `{ "appointment" }` |
| `GET /notifications` | Authenticated | — | `{ "notifications": [...] }` (only recipient's notifications) |
| `PUT /notifications/:id/read` | Authenticated recipient | — | `{ "notification" }` |
| `PUT /notifications/read-all` | Authenticated | — | `{ "updated": true }` |

Service JSON fields include `name`, `location`, `description`, `active`,
`serviceType`, `building`, `floor`, `capacity`, `phone`, `email`, `headName`,
`openingHours`, and `notes`.
Shift JSON includes `userId`, `serviceId`, ISO-serialized `start`/`end`, `role`,
`userName`, and `serviceName`. Handover JSON includes `serviceId`,
server-assigned `authorId`/`authorName`/`createdAt`, `title`, `content`, and
`important`. User and service IDs in Flutter are MongoDB ObjectId hex strings.

## Testing

Appointment responses include patient and doctor display data, doctor
specialty/photo, service/contact fields, `startAt`, optional `reason`,
`status` (`pending`, `accepted`, `in_progress`, `proposed`, `rejected`, or
`cancelled`), proposal/refusal details, claim metadata, and `isOverdue`.
Doctors must be active and assigned to an active service; availability must
match a future half-hour slot within a recorded shift. Notifications are
persisted in MongoDB for in-app delivery. The appointment history itself is
the source for current status; no SMS, email, or push provider is configured.

Run `npm test`. The focused Node test suite covers validation, password-free
user serialization, JWT signing, health, and unauthenticated access; it does
not require MongoDB. Full persistence/login/authorization integration testing
requires a MongoDB instance.

## Postman

Import `postman_collection.json`, set `baseUrl`, and set the `token` collection variable after logging in. Authenticated requests automatically use that bearer token.
