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

Login with `POST /auth/login` and then send `Authorization: Bearer <token>` on every other endpoint, including `GET /auth/me`. User responses expose only `_id`, `username`, `email`, `role`, `serviceId`, and `active`; password hashes are never serialized.

Successful responses use the resource keys shown below (login is `{ "token": "...", "user": {...} }`, and `/auth/me` is `{ "user": {...} }`). Errors use `{ "error": { "message": "..." } }`.

Roles are `admin`, `doctor`, `nurse`, and `patient`. Public registration
always creates a patient account; the requested role is never accepted from
the client. Only admins may list or manage all user accounts. Patients cannot
read staff services, shifts, or handovers. Only admins, doctors, and nurses
may read those staff resources; only admins may create/update services and
shifts. Staff roles may create handovers. Handover authors are derived from
the authenticated account, never accepted from request data.

## Endpoint contract

All JSON request bodies reject unrecognized fields. MongoDB identifiers are ObjectId hex strings. Collections are bounded (200 users/services; 500 shifts/handovers).

| Method and path | Access | Request / query | Success response |
|---|---|---|---|
| `POST /auth/login` | Public | `{ "email", "password" }` | `{ "token", "user" }` |
| `POST /auth/register` | Public | `{ "username", "email", "password" }` | `{ "token", "user" }` (201; role always `patient`) |
| `GET /auth/me` | Authenticated | — | `{ "user" }` |
| `GET /users` | Admin | — | `{ "users": [...] }` |
| `POST /users` | Admin | `{ "username", "email", "password", "role", "serviceId"?, "active"? }` | `{ "user" }` (201) |
| `PUT /users/:id` | Admin | Any subset of user fields above; `password` changes credentials | `{ "user" }` |
| `GET /services` | Admin, doctor, nurse | — | `{ "services": [...] }` |
| `POST /services` | Admin | `{ "name", "location"?, "description"?, "active"? }` | `{ "service" }` (201) |
| `PUT /services/:id` | Admin | Any subset of service fields | `{ "service" }` |
| `GET /shifts` | Admin, doctor, nurse | Optional `userId` and/or `date=YYYY-MM-DD` (UTC day, by shift start) | `{ "shifts": [...] }` |
| `POST /shifts` | Admin | `{ "userId", "serviceId", "start", "end", "role" }` (ISO dates) | `{ "shift" }` (201) |
| `PUT /shifts/:id` | Admin | Any subset of shift fields | `{ "shift" }` |
| `GET /handovers` | Admin, doctor, nurse | Optional `serviceId` | `{ "handovers": [...] }` |
| `POST /handovers` | Admin, doctor, nurse | `{ "serviceId", "title", "content", "important"? }` | `{ "handover" }` (201) |

Service JSON fields include `name`, `location`, `description`, and `active`.
Shift JSON includes `userId`, `serviceId`, ISO-serialized `start`/`end`, `role`,
`userName`, and `serviceName`. Handover JSON includes `serviceId`,
server-assigned `authorId`/`authorName`/`createdAt`, `title`, `content`, and
`important`. User and service IDs in Flutter are MongoDB ObjectId hex strings.

## Testing

Run `npm test`. The focused Node test suite covers validation, password-free
user serialization, JWT signing, health, and unauthenticated access; it does
not require MongoDB. Full persistence/login/authorization integration testing
requires a MongoDB instance.

## Postman

Import `postman_collection.json`, set `baseUrl`, and set the `token` collection variable after logging in. Authenticated requests automatically use that bearer token.
