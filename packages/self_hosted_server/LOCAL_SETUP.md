# Self-Hosted Shorebird Code Push — Local Setup Guide

## Prerequisites

- **Docker** + **Docker Compose** (v2)
- **Shorebird CLI** installed (`curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash`)

---

## 1. Start the Services

```bash
cd packages/self_hosted_server

# Create .env from the template
cp .env.example .env

# (Optional) Generate a secure JWT secret
# openssl rand -base64 32
# Then put it in .env as JWT_SECRET=...

# Build and start everything
docker compose up --build -d
```

This starts **5 containers**:

| Service      | Port  | Description                      |
|-------------|-------|----------------------------------|
| postgres     | 5432  | PostgreSQL 16 database           |
| minio        | 9000  | S3-compatible artifact storage   |
| minio (ui)   | 9001  | MinIO admin console              |
| server       | 8080  | Shorebird API (Dart Frog)        |
| console      | 3000  | Admin web console (Flutter)      |

The **minio-init** container runs once to create the `artifacts` bucket, then exits.

**Database migrations** run automatically on first server start.

### Verify

```bash
# Check all services are healthy
docker compose ps

# Test the API
curl http://localhost:8080/api/v1/apps
# Should return 401 (not authenticated) — that's correct
```

---

## 2. Create Your First Account

Open the console at **http://localhost:3000** and register a new account.

Or via API:

```bash
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "YourPassword123", "name": "Admin"}'
```

---

## 3. Configure the Shorebird CLI

The CLI needs three environment variables to point at your self-hosted server:

```bash
# The API server URL (where CLI sends API requests)
export SHOREBIRD_HOSTED_URL=http://localhost:8080

# The auth service URL (where CLI authenticates — JWT issuer must match)
export AUTH_SERVICE_URL=http://localhost:8080/auth

# JWT issuer — must match AUTH_ISSUER in .env (required for token refresh)
export SHOREBIRD_JWT_ISSUER=http://localhost:8080/auth
```

**Windows (PowerShell):**

```powershell
$env:SHOREBIRD_HOSTED_URL = "http://localhost:8080"
$env:AUTH_SERVICE_URL = "http://localhost:8080/auth"
$env:SHOREBIRD_JWT_ISSUER = "http://localhost:8080/auth"
```

**Windows (CMD):**

```cmd
set SHOREBIRD_HOSTED_URL=http://localhost:8080
set AUTH_SERVICE_URL=http://localhost:8080/auth
set SHOREBIRD_JWT_ISSUER=http://localhost:8080/auth
```

> **Tip:** Add these to your shell profile (`~/.bashrc`, `~/.zshrc`,
> PowerShell `$PROFILE`) so they persist across sessions.

### Alternative: `shorebird.yaml`

Instead of environment variables, you can add `base_url` to your
project's `shorebird.yaml`:

```yaml
app_id: your-app-id
base_url: http://localhost:8080
```

Note: `AUTH_SERVICE_URL` still needs to be set as an env var since
there's no `shorebird.yaml` equivalent for it.

---

## 4. Login with the CLI

```bash
shorebird login
```

This opens your browser to the self-hosted login page
(`http://localhost:8080/auth/login`). Enter the credentials you created
in step 2. After login, the browser shows "Authentication complete" and
the CLI stores your tokens locally.

Verify:

```bash
shorebird account
```

---

## 5. Standard Shorebird Workflow

Everything works exactly like the official Shorebird — just against your
own server.

```bash
# Initialize a Flutter project with Shorebird
cd your_flutter_app
shorebird init

# Create a release
shorebird release android   # or: shorebird release ios

# After making changes, push a patch
shorebird patch android     # or: shorebird patch ios
```

---

## Architecture Overview

```
┌────────────┐       ┌────────────────┐       ┌──────────────┐
│  Shorebird  │──────▶│  API Server    │──────▶│  PostgreSQL  │
│    CLI      │ :8080 │  (Dart Frog)   │       │  :5432       │
└────────────┘       └───────┬────────┘       └──────────────┘
                             │
┌────────────┐               │                 ┌──────────────┐
│  Console   │───────────────┤────────────────▶│  MinIO (S3)  │
│  :3000     │  nginx proxy  │                 │  :9000       │
└────────────┘               │                 └──────────────┘
                             │
                    ┌────────┴────────┐
                    │ /auth/* → :8080 │
                    │ /api/*  → :8080 │
                    │   /*    → SPA   │
                    └─────────────────┘
```

- **Console** (port 3000): Flutter web app served by nginx. All
  `/auth/*` and `/api/*` requests are proxied to the server container
  (same-origin, no CORS issues).
- **Server** (port 8080): Dart Frog API. Handles CLI requests directly
  and console requests via the nginx proxy.
- **CLI**: Connects directly to port 8080 for API and auth.

---

## Environment Variables Reference

| Variable               | Default                      | Description                              |
|------------------------|------------------------------|------------------------------------------|
| `POSTGRES_USER`        | `shorebird`                  | Database user                            |
| `POSTGRES_PASSWORD`    | `shorebird_secret`           | Database password                        |
| `POSTGRES_DB`          | `shorebird`                  | Database name                            |
| `DATABASE_URL`         | (composed from above)        | Full connection string                   |
| `JWT_SECRET`           | —                            | **Change this!** At least 32 chars       |
| `SERVER_URL`           | `http://localhost:8080`      | Server's own URL                         |
| `AUTH_ISSUER`          | `http://localhost:8080/auth` | JWT issuer (must match `AUTH_SERVICE_URL`)|
| `PORT`                 | `8080`                       | API server port                          |
| `CORS_ORIGINS`         | `*`                          | Allowed CORS origins (comma-separated)   |
| `MINIO_ROOT_USER`      | `minio_admin`                | MinIO root user                          |
| `MINIO_ROOT_PASSWORD`  | `minio_secret`               | MinIO root password                      |
| `MINIO_ENDPOINT`       | `http://minio:9000`          | MinIO endpoint (Docker internal)         |
| `MINIO_ACCESS_KEY`     | same as root user             | S3 access key                            |
| `MINIO_SECRET_KEY`     | same as root password         | S3 secret key                            |
| `MINIO_BUCKET`         | `artifacts`                  | S3 bucket name                           |
| `MINIO_PUBLIC_ENDPOINT`| `http://localhost:9000`      | Public-facing MinIO URL for downloads    |

---

## Common Commands

```bash
# Start all services
docker compose up -d

# Rebuild after code changes
docker compose up --build -d

# View logs
docker compose logs -f server
docker compose logs -f console

# Stop everything
docker compose down

# Stop and wipe all data (fresh start)
docker compose down -v

# Connect to database
docker compose exec postgres psql -U shorebird
```

---

## Troubleshooting

### "Connection refused" from CLI

Make sure the server is running and reachable:
```bash
curl http://localhost:8080/auth/login
# Should return the HTML login page
```

### JWT validation error in CLI

The JWT `issuer` must match `AUTH_SERVICE_URL`. Verify:
- `.env` has `AUTH_ISSUER=http://localhost:8080/auth`
- Shell has `AUTH_SERVICE_URL=http://localhost:8080/auth`

### MinIO "bucket not found"

The `minio-init` container creates the bucket on first start. If it
failed, create manually:
```bash
docker compose run --rm minio-init
```

### Console shows API errors

Check that the server container is running:
```bash
docker compose ps server
docker compose logs server
```

The console nginx proxies `/api/*` and `/auth/*` to the server container.
If the server is down, these requests will fail.
