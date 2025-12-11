# rso-platform

Repository for **local development and integration** of the _eUčilnica+_ microservices.

It is an orchestration layer that:

- pulls all backend and frontend services in as **Git submodules**
- wires them together with a single **Docker Compose** file
- provides shared local infrastructure (PostgreSQL, Keycloak...)
- mirrors the production architecture that will later run on **Azure**

---

## 1. Architecture

High‑level view of the local stack managed by this repo:

```text
+---------------------+        +-----------------+
| rso-frontend (Nuxt) | <----> |  svc-gateway    |  (API Gateway / BFF)
+---------------------+        +-----------------+
                                      |
        +-----------------------------+---------------------------+
        |                             |                           |
        v                             v                           v
+-----------------+       +-----------------+           +-----------------+
|  svc-courses    |       |   svc-notes     |           |   svc-users     |
| Courses +       |       | Notes per       |           | User profiles   |
| lectures        |       | lecture         |           | + roles         |
+-----------------+       +-----------------+           +-----------------+

+-----------------+      +-----------------+      +-----------------+
| Postgres (db)   |      |   Keycloak      |      |    pgAdmin      |
+-----------------+      +-----------------+      +-----------------+
```

Microservices live in **their own repositories** and are pulled in here as submodules:

- [`svc-courses`](https://github.com/Trije-bingusi/svc-courses)
- [`svc-notes`](https://github.com/Trije-bingusi/svc-notes)
- [`svc-users`](https://github.com/Trije-bingusi/svc-users)
- [`svc-gateway`](https://github.com/Trije-bingusi/svc-gateway)
- [`rso-frontend`](https://github.com/Trije-bingusi/rso-frontend)

Infrastructure for Azure (AKS, PostgreSQL Flex, ACR, Key Vault, etc.) is provisioned from the separate [`shared-infrastructure`](https://github.com/Trije-bingusi/shared-infrastructure) repo with Terraform.

---

## 2. Repository layout

```text
rso-platform/
  docker-compose.yml        # local integration compose for the whole system
  .env.example              # baseline env vars for local dev
  .env                      # your local overrides
  db/
    init.sql                # creates initial databases (courses, notes, users)
  scripts/
    dev-up.sh               # build + start all containers
    dev-down.sh             # stop stack
  svc-courses/              # git submodule
  svc-notes/                # git submodule
  svc-users/                # git submodule
  svc-gateway/              # git submodule
  rso-frontend/             # git submodule
```

We **develop code** inside the submodule folders, but **run the system** from this repo.

---

## 3. Getting started

### 3.1 Cloning with submodules (first time)

```bash
git clone --recurse-submodules https://github.com/Trije-bingusi/rso-platform.git
cd rso-platform

# create your local env file
cp .env.example .env
```

If you forgot `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### 3.2 Working with Git submodules

Each submodule is a **real Git repo** pinned to a specific commit.  
`rso-platform` stores *which commit* of each service should be used.

#### A) You change a service **inside** rso-platform

Example for `svc-gateway`:

```bash
# 1) Work inside the submodule
cd svc-gateway
# ...edit code...
git status
git add .
git commit -m "Improve logging"
git push origin main
cd ..

# 2) Commit updated pointer in rso-platform
git status                # shows "modified: svc-gateway (new commits)"
git add svc-gateway
git commit -m "Bump svc-gateway to latest main"
git push origin dev
```

Now `rso-platform` remembers which `svc-gateway` commit it depends on.

#### B) Someone else updated a service and you want the latest

Example for `svc-courses`:

```bash
cd svc-courses
git fetch
git checkout main
git pull
cd ..

git add svc-courses
git commit -m "Update svc-courses submodule"
git push origin dev
```

#### C) Updating submodules after pulling rso-platform

On any dev machine:

```bash
git pull
git submodule update --init --recursive
```

This moves every submodule to the exact commit recorded in the latest `rso-platform` commit.

---

## 4. Local development workflow

### 4.1 Environment configuration

Copy the example env file:

```bash
cp .env.example .env
```

`.env` controls:

- Postgres user, password, default DB and port
- Keycloak admin credentials
- pgAdmin credentials
- Public ports for frontend, gateway, Keycloak, pgAdmin
- CORS origins for the gateway
- OIDC settings for `svc-users` and `svc-gateway`

The defaults are made for local use only.

### 4.2 Starting the whole platform

From the root of `rso-platform`:

```bash
./scripts/dev-up.sh
```

What this does in practice:

- builds images for all services from their subfolders
- starts the following containers:
  - `db` (PostgreSQL)
  - `pgadmin`
  - `keycloak-db`
  - `keycloak`
  - `svc-courses`
  - `svc-notes`
  - `svc-users`
  - `svc-gateway`
  - `rso-frontend`

Check that everything is running:

```bash
docker ps
```

### 4.3 Stopping and cleaning up

To stop without removing volumes:

```bash
docker compose down
```

To also drop DB data and other volumes:

```bash
docker compose down -v
```

(`scripts/dev-down.sh` is just a small wrapper.)

### 4.4 Useful URLs

Once `./scripts/dev-up.sh` finishes:

- **Frontend (Nuxt)** – http://localhost:3003
- **API Gateway** – http://localhost:8081
- **Keycloak** – http://localhost:8080
- **pgAdmin** – http://localhost:5050

Internally, containers talk to each other by **service name**:

- `db:5432`
- `keycloak:8080`
- `svc-courses:3000`
- `svc-notes:3000`
- `svc-users:3000`
- `svc-gateway:3000`

---

## 5. Keycloak configuration for local development

Keycloak is used as the IAM/OIDC provider for the project.  
The frontend uses **OIDC code flow + PKCE**, and backend services validate access tokens per request.

### 5.1 Log in to Keycloak

1. Open http://localhost:8080
2. Log in to the admin console:
   - username: `admin`
   - password: `admin`  
   (defined by env vars in `docker-compose.yml`)

### 5.2 Create realm `rso`

1. In the top‑left realm dropdown, click **Create realm**.
2. Name it **`rso`** and save.

Make sure you are now **inside** the `rso` realm (not `master`).

### 5.3 Create client `rso-frontend`

1. Go to **Clients → Create client**.
2. Client type: **OpenID Connect**
3. Client ID: **`rso-frontend`**
4. Click **Next**.

On the **Capabilities config** step:

- Turn **ON**:
  - _Standard flow_
  - _Direct access grants_ (useful for testing)
- **PKCE method**: `S256`
- Click **Save**.

On the **Access settings** tab:

- **Valid redirect URIs**:

  ```text
  http://localhost:3003/*
  ```

- **Web origins**:

  ```text
  http://localhost:3003
  ```

### 5.4 Realm roles

1. Go to **Realm roles → Create role**.
2. Create roles:

   - `student`
   - `professor`

These map to app‑level roles and are later used by `svc-users` and `svc-gateway`.

### 5.5 Users

Create at least two test users.

For each user:

1. **Users → Add user**
   - Username: e.g. `test.student` / `test.professor`
   - Email: something random
   - Turn **Email verified** ON.
   - Save.
2. Go to **Credentials** tab:
   - Set a password.
   - Turn **Temporary** OFF.
3. Go to **Role mapping** tab:
   - Pick either `student` or `professor`.
   - Click **Add**.

### 5.6 Allow self‑registratiom

Enable users to be able to register themselves:

1. Go to **Realm settings → Login**.
2. Enable **User registration**.

### 5.7 OIDC config used by services

In this setup, backend services use the same Keycloak realm and client as the frontend. They read three environment variables:

- `OIDC_ISSUER` – issuer URL of the realm, e.g.

  ```text
  http://keycloak:8080/realms/rso
  ```

- `OIDC_JWKS_URI` – URL of JWKS endpoint for token validation:

  ```text
  http://keycloak:8080/realms/rso/protocol/openid-connect/certs
  ```

- `OIDC_AUDIENCE` – the expected audience / client id:

  ```text
  rso-frontend
  ```

These values are already wired via `.env` and `docker-compose.yml`.

---

## 6. Microservices overview

All backend services are built with:

- **Node.js + Express**
- **Prisma** as DB ORM
- **PostgreSQL** as storage
- **prom-client** for Prometheus metrics
- **pino-http** for structured logging
- **Scalar / OpenAPI** for API documentation
- Standard **health** and **readiness** endpoints: `/healthz` and `/readyz`

### 6.1 `svc-courses` – Courses & lectures

Manages the **course catalog** and associated **lectures** (metadata + HLS manifest URL for videos).

**Tech**

- Express + Prisma, PostgreSQL
- OpenAPI docs via `openapi.yaml` + `@scalar/express-api-reference`
- Metrics via `prom-client`
- Logs via `pino-http`

**Domain model (Prisma)**

```prisma
model Course {
  id         String   @id @default(uuid()) @db.Uuid
  name       String
  created_at DateTime @default(now())
  lectures   Lecture[]
}

model Lecture {
  id           String   @id @default(uuid()) @db.Uuid
  course_id    String   @db.Uuid
  title        String
  manifest_url String?  @db.Text
  created_at   DateTime @default(now())
  course       Course   @relation(fields: [course_id], references: [id], onDelete: Cascade)
}
```

**Key endpoints**

- `GET /healthz` – liveness probe.
- `GET /readyz` – readiness probe; verifies DB connectivity (`SELECT 1`).
- `GET /metrics` – Prometheus metrics, including:
  - `svc_courses_course_created_total`
- `GET /docs` – API docs UI.
- `GET /openapi.json` – raw OpenAPI spec.

**Courses**

- `GET /api/courses`  
  Returns list of courses ordered by `created_at`.

- `POST /api/courses`  
  Creates a new course. Body:

  ```json
  { "name": "Racunalniske storitve v oblaku" }
  ```

  Increments `svc_courses_course_created_total`.

**Lectures**

- `GET /api/courses/:courseId/lectures`  
  List lectures for a given course.

- `POST /api/courses/:courseId/lectures`  
  Create new lecture for a course:

  ```json
  {
    "title": "Lecture 1 – Introduction",
    "manifest_url": "https://example.com/hls/intro.m3u8"
  }
  ```

### 6.2 `svc-notes` – Lecture notes

Stores **personal notes** for a lecture, tied to a specific `lecture_id` and optional `user_id`. Used from the lecture view in the frontend.

**Tech**

- Express + Prisma, PostgreSQL
- Prometheus metrics
- Scalar + OpenAPI

**Domain model**

```prisma
model Note {
  id         String   @id @default(uuid()) @db.Uuid
  lecture_id String   @db.Uuid
  user_id    String?  @db.Uuid
  content    String
  created_at DateTime @default(now()) @db.Timestamptz(6)
}
```

**Endpoints**

- `GET /healthz`
- `GET /readyz`
- `GET /metrics` – includes `svc_notes_note_created_total`.
- `GET /docs`, `GET /openapi.json`

**Notes**

- `GET /api/lectures/:lectureId/notes`  
  Returns all notes for the given lecture.

- `POST /api/lectures/:lectureId/notes`  
  Creates a new note. Body:

  ```json
  {
    "user_id": "optional-uuid",
    "content": "Important remark about slide 5…"
  }
  ```

  `content` is required; increments `svc_notes_note_created_total`.

### 6.3 `svc-users` – User profiles & roles

Maps OIDC identities from Keycloak to **application profiles** stored in PostgreSQL.  
Keeps email and role in sync with Keycloak realm roles.

**Tech**

- Express + Prisma, PostgreSQL
- `jose` for JWT & JWK validation
- Prometheus / Scalar / pino-http

**Auth**

Middleware in `auth.js`:

- `requireAuth()`:
  - Expects `Authorization: Bearer <token>`.
  - Validates token against Keycloak using JWKS (`OIDC_JWKS_URI`).
  - Checks:
    - `iss` matches `OIDC_ISSUER`
    - `aud` / `azp` contains `OIDC_AUDIENCE`
  - On success, sets `req.user` to the token payload.

- `getRealmRoles(user)`:
  - Helper returning `user.realm_access.roles` from token.

**Domain model**

```prisma
model UserProfile {
  id          String   @id @default(uuid()) @db.Uuid
  oidc_sub    String   @unique
  email       String?  @unique
  display_name String?
  role        String?  // "student" or "professor"
  created_at  DateTime @default(now())
  updated_at  DateTime @updatedAt
}
```

**Endpoints**

- `GET /healthz`
- `GET /readyz`
- `GET /metrics` – includes:
  - `svc_users_profile_created_total`
  - `svc_users_profile_updated_total`
- `GET /docs`, `GET /openapi.json`

**User profile**

All endpoints require a valid access token (`requireAuth()`).

- `GET /api/users/me`  
  - Extracts `sub`, `email`, and realm roles from the token.
  - If no profile exists for this `sub`, creates one:
    - `display_name` from `preferred_username` / `name`
    - `role` from roles: `professor` > `student` > `null`
  - If profile exists and email or role changed, it updates them.
  - Returns the profile as JSON.

- `PUT /api/users/me`  
  - Updates `display_name`. Body:

    ```json
    { "display_name": "Janez Novak" }
    ```

  - Increments `svc_users_profile_updated_total`.

### 6.4 `svc-gateway` – API Gateway / Backend-for-Frontend

Acts as the single **entry point** for the frontend:

- Validates JWT on every API request.
- Enforces **role-based access control** (RBAC) for write operations.
- Routes requests to the appropriate microservice.
- Adds CORS headers for browser access.
- Exposes metrics and docs.

**Tech**

- Express + `http-proxy-middleware`
- `jose` for JWT validation (same as `svc-users`)
- `cors` for CORS
- Prometheus / Scalar / pino-http

**CORS**

Allowed origins are configured via `CORS_ORIGINS` env var, defaulting to:

```text
http://localhost:3003,http://localhost:3000
```

All API routes go through this gateway, so we only have to configure CORS **here**, not in each backend service.

**Auth**

Same `OIDC_ISSUER`, `OIDC_JWKS_URI`, `OIDC_AUDIENCE` pattern as `svc-users`.

- `requireAuth()` – validates the access token on incoming requests.
- `getRealmRoles()` – extracts realm roles from token.
- `requireRoleForWrite("professor")` – for write methods (`POST`, `PUT`, `PATCH`, `DELETE`), checks the user has the `professor` role; otherwise returns `403`.

**Metrics**

- `svc_gateway_proxied_requests_total{service,method}` – count of proxied requests per service and HTTP method.

**Endpoints**

- `GET /healthz`
- `GET /readyz`
- `GET /metrics`
- `GET /docs`, `GET /openapi.json`

**Proxy routing**

Helper `makeProxy(target, serviceName)` creates proxies and annotates proxied requests with `x-user-sub` header when available.

Mounted routes:

- `app.use("/api/courses", requireAuth(), requireRoleForWrite("professor"), coursesProxy)`  
  → forwards to `${COURSES_URL}`

- `app.use("/api/lectures", requireAuth(), notesProxy)`  
  → forwards to `${NOTES_URL}`

- `app.use("/api/users", requireAuth(), usersProxy)`  
  → forwards to `${USERS_URL}`

So, for example:

- `GET /api/courses` → `svc-courses`
- `POST /api/courses` → `svc-courses` (requires `professor`)
- `GET /api/lectures/:lectureId/notes` → `svc-notes`
- `POST /api/lectures/:lectureId/notes` → `svc-notes` (requires authenticated user)
- `GET /api/users/me` → `svc-users`

### 6.5 `rso-frontend` – Nuxt 4 SPA client

Browser client for _eUčilnica+_. It **never calls backend services directly** – all HTTP calls go through `svc-gateway`.

**How it talks to the backend**

- The base URL is injected via `NUXT_PUBLIC_API_BASE` (e.g. `http://localhost:8081`).
- A small composable (`useApi`) wraps `$fetch` and automatically:
  - adds the `Authorization: Bearer <access_token>` header if the user is logged in,
  - sends all requests to the gateway (`/api/courses`, `/api/lectures/:id/notes`, `/api/users/me`, …).

- auth is enforced centrally in `svc-gateway` (`requireAuth`, `requireRoleForWrite`),
- the frontend doesn’t know where individual microservices live – only the gateway URL.

**OIDC / Keycloak integration**

- A Nuxt plugin (`00-oidc.client.ts`) configures `oidc-client-ts` with values from runtime config:
  - `NUXT_PUBLIC_KC_URL` (Keycloak base),
  - `NUXT_PUBLIC_KC_REALM` (`rso`),
  - `NUXT_PUBLIC_KC_CLIENT_ID` (`rso-frontend`).
- Login flow:
  - `/login` page calls `$oidc.login()` → browser is redirected to Keycloak.
  - After successful login, Keycloak redirects back to `/callback`.
  - `/callback` calls `$oidc.handleCallback()` which:
    - reads the OIDC response,
    - stores the **access token** and **realm roles** in the Pinia `auth` store,
    - calls `/api/users/me` (through the gateway) to create/load the user profile.
- Logout calls `$oidc.logout()`, which clears local state and redirects through Keycloak’s logout endpoint.

**Authorization & roles in the UI**

- A global route middleware (`auth.global.ts`) protects all routes except `/login` and `/callback`:
  - on first navigation it calls `$oidc.restore()` to restore a session (if any),
  - if there is no access token, the user is redirected to `/login`.
- The `auth` store keeps:
  - `token` – access token sent to the gateway,
  - `roles` – realm roles from the token (`professor`, `student`),
  - `profile` – data returned by `svc-users` (`/api/users/me`).
- Convenience flags:
  - `auth.isProfessor` / `auth.isStudent` drive both **UI state** and **which API actions are allowed**.
    - Example: only professors see “Create course / Add lecture” forms; only students see the note-taking UI.
- The gateway enforces the same rules on the server side:
  - write operations on `/api/courses/**` require the `professor` role (`requireRoleForWrite("professor")`),

**Keycloak issues the token → frontend stores it and adds it to each request → the gateway validates it and forwards the call to the right microservice.**

### 6.6 `rso-platform` – this repo

- Single entry point for local dev and integration.
- Keeps all microservices and frontend in sync via submodules.
- Acts as a “mini‑production” setup.
- No application logic here.
- No Kubernetes manifests or Helm charts (those live in microservice repos and `shared-infrastructure`).

---

## 7. Troubleshooting

Some common issues and fixes.

### Containers fail to start due to name conflicts

If you previously ran the old per‑service `docker-compose.yml` files, there might be leftover containers.

Fix:

```bash
# See all containers
docker ps -a

# Remove old ones (example)
docker rm -f svc-notes svc-users svc-courses keycloak keycloak-db pgadmin rso-frontend 2>/dev/null || true
```

Then re‑run:

```bash
./scripts/dev-up.sh
```

### Submodules are empty or on the wrong commit

Run:

```bash
git submodule update --init --recursive
```

### Login page works but redirect callback fails with CORS

Check **Keycloak → Clients → rso-frontend → Access settings**:

- `Valid redirect URIs` = `http://localhost:3003/*`
- `Web origins` = `http://localhost:3003` or `+` (inherit from redirect URIs)

Then reload the frontend and log in again.

### Backend says `invalid_token` or `missing_token`

- Make sure frontend is sending requests through the gateway (URL starts with `http://localhost:8081`).
- Check the browser devtools → Network:
  - Every `/api/...` request should have an `Authorization: Bearer <token>` header.
- Verify that `OIDC_ISSUER`, `OIDC_JWKS_URI` and `OIDC_AUDIENCE` in `.env` match:
  - Issuer: `http://keycloak:8080/realms/rso`
  - Audience: `rso-frontend`

---

When adding new microservices later, the pattern should stay the same:

1. Create a new repo with Dockerfile, Helm chart, OpenAPI, metrics, health checks.
2. Add it here as a submodule.
3. Extend `docker-compose.yml` and wire it via `svc-gateway` if needed.
