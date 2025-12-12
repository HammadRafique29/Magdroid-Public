# Magdroid - ADB & Cloudflared Management Dashboard

Magdroid is a full-stack application designed to manage Android devices using ADB, ws-scrcpy, and Cloudflare Tunnels. It consists of a Next.js frontend and a Python Flask backend, orchestrated with Docker Compose for simple local deployment.

## Features

- **Clerk Authentication:** Secure login and protected backend endpoints.
- **ADB Automation:** Programmatically run ADB commands like `devices`, `mdns services`, and `connect`.
- **ws-scrcpy Management:** Start and stop the ws-scrcpy server process.
- **Cloudflare Tunnel Control:** Start and stop Cloudflare Tunnels to expose the ws-scrcpy service publicly.
- **Simplified Docker Setup:** Fully containerized services that are easy to run and configure.

---

## Project Structure

The project has been simplified to remove the Nginx proxy, making local development more straightforward.

```
.
├── backend/
│   ├── app.py             # Main Flask application
│   ├── .env               # Backend-specific environment variables
│   └── Dockerfile.backend # Dockerfile for the backend
├── frontend/
│   ├── pages/             # Next.js pages
│   ├── .env               # Frontend-specific environment variables
│   └── Dockerfile.frontend# Dockerfile for the frontend
├── ws-scrcpy/             # Cloned ws-scrcpy repository
├── docker-compose.yml     # Orchestrates the frontend and backend services
├── .gitignore             # Files to ignore for version control
└── .dockerignore          # Files to exclude from Docker builds
```

---

## Getting Started

### Prerequisites

- Docker and Docker Compose installed.
- A Clerk.dev account and application set up.
- A Cloudflare account (optional, for tunnels).

### 1. Configuration

This project now uses service-specific `.env` files located in the `frontend/` and `backend/` directories. There are no `.env` files at the root of the project.

**A) Configure the Frontend**

Create a `.env` file inside the `frontend/` directory:
```bash
touch frontend/.env
```

Open `frontend/.env` and add the following, filling in your specific values. You can run multiple instances of the project by using a different `FRONTEND_PORT`.

```ini
# frontend/.env

# The public-facing port for the frontend application.
FRONTEND_PORT=3000

# Your Clerk application's Publishable Key.
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
# Your Clerk application's Secret Key.
CLERK_SECRET_KEY=sk_test_...

# The full, absolute URL to the backend API.
# The backend runs on the host network, so this URL should be correct as is.
NEXT_PUBLIC_BACKEND_API_URL=http://localhost:5000
```

**B) Configure the Backend**

Create a `.env` file inside the `backend/` directory:
```bash
touch backend/.env
```

Open `backend/.env` and add the following, filling in your specific values. The `CORS_ORIGINS` must match the URL of your frontend.

```ini
# backend/.env

# Your Clerk application's Issuer URL (from the Clerk dashboard).
CLERK_ISSUER=https://your-clerk-issuer.clerk.accounts.dev
# The JWKS URL corresponding to your issuer.
CLERK_JWKS_URL=https://your-clerk-issuer.clerk.accounts.dev/.well-known/jwks.json

# A comma-separated list of allowed origins.
# This MUST include the address of your running frontend.
CORS_ORIGINS=http://localhost:3000

# (Optional) Cloudflare Tunnel token.
CLOUDFLARED_TUNNEL_TOKEN=...
```

### 2. Running the Application

With Docker running, simply execute the following command from the root of the project:

```bash
docker-compose up --build
```

This will:
1. Build the frontend and backend Docker images.
2. Read the variables from `frontend/.env` and `backend/.env`.
3. Start the frontend and backend containers.

The application will be available at the URL you configured for the frontend (e.g., **http://localhost:3000**).

<br>

## Architectural Notes

### Networking

- **Backend (`host` mode):** The backend container runs in `network_mode: "host"`. This is **essential** for it to see and interact with devices on your local network for ADB and mDNS discovery. It runs on port 5000 by default.
- **Frontend (`bridge` mode):** The frontend runs in a standard Docker container and exposes its port directly to the host machine.
- **Communication:** The frontend now communicates with the backend directly via its full URL (`http://localhost:5000`). Make sure your `CORS_ORIGINS` in the backend configuration correctly lists the frontend's address.