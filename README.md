# Magdroid - ADB & Cloudflared Management Dashboard

Magdroid is a application designed to manage Android devices using ADB, ws-scrcpy, and Cloudflare Tunnels. It consists of a Next.js frontend and a Python Flask backend, orchestrated with Docker Compose for simple local deployment.

## Features

- **[Clerk Authentication:](https://clerk.com/)** Secure login and protected backend endpoints. 
- **ADB Automation:** Programmatically run ADB commands like `devices`, `mdns services`, and `connect`.
- **ws-scrcpy Management:** Start and stop the ws-scrcpy server process.
- **[Cloudflare Tunnel Control:](https://one.dash.cloudflare.com/)** Start and stop Cloudflare Tunnels to expose the ws-scrcpy service publicly.
- **Simplified Docker Setup:** Fully containerized services that are easy to run and configure.

<br>

## Display:

<img width="1573" height="775" alt="image" src="https://github.com/user-attachments/assets/2e9133d7-3335-41e9-89a0-ed947343c53f" />

## WS-Scrcpy
https://github.com/user-attachments/assets/8effe952-1c70-4d60-b41e-98a9fe0c6e28



## Getting Started

### Prerequisites

- Docker and Docker Compose installed.
- A Clerk.dev account and application set up.
- A Cloudflare account (optional, for tunnels).

### 1. Enviroments Configuration


Create a `.env` file inside the root directory:
```bash
touch .env
```

```ini
# -------------------------
# Frontend Environment
# -------------------------

# -- SERVER CONFIGURATION --
FRONTEND_PORT=3000

# -- CLERK AUTHENTICATION --
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_XYyt...
CLERK_SECRET_KEY=sk_test_XYyt

# -- API CONFIGURATION --
NEXT_PUBLIC_BACKEND_API_URL=http://localhost:5000
NEXT_PUBLIC_API_BASE_URL=/api



# -------------------------
# Backend Environment
# -------------------------

# -- FLASK SERVER CONFIGURATION --
BACKEND_PORT=5000

# -- CLERK AUTHENTICATION --
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_XYyt...
CLERK_SECRET_KEY=sk_test_XYyt...

CLERK_ISSUER=https://your-domain.clerk.accounts.dev
CLERK_JWKS_URL=https://your-domain.accounts.dev/.well-known/jwks.json

# -- CORS CONFIGURATION --
CORS_ORIGINS=http://localhost:3000

# -- CLOUDFLARE TUNNELS --
# (Optional) A persistent Cloudflare Tunnel token for the "Start Named Tunnel" feature.
CLOUDFLARED_TUNNEL_TOKEN=eyJhIjoiNzQ3NDJlZGY2...
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
