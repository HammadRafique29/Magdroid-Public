# Magdroid - ADB & Cloudflared Management Dashboard

Magdroid is a application designed to manage Android devices using ADB, ws-scrcpy, and Cloudflare Tunnels. It consists of a Next.js frontend and a Python Flask backend, orchestrated with Docker Compose for simple local deployment.

## Features

- **~~[Clerk Authentication:](https://clerk.com/)~~** ~~Secure login and protected backend endpoints.~~ 
- **ADB Automation:** Programmatically run ADB commands like `devices`, `mdns services`, and `connect`.
- **ws-scrcpy Management:** Start and stop the ws-scrcpy server process.
- **[Cloudflare Tunnel Control:](https://one.dash.cloudflare.com/)** Start and stop Cloudflare Tunnels to expose the ws-scrcpy service publicly.
- **Simplified Docker Setup:** Fully containerized services that are easy to run and configure.

<br>


## Display:

<img width="1170" height="909" alt="image" src="https://github.com/user-attachments/assets/5f291eea-a565-43b4-a2a4-e49cc70a2463" />

## WS-Scrcpy
https://github.com/user-attachments/assets/8effe952-1c70-4d60-b41e-98a9fe0c6e28



## Getting Started

### Prerequisites

- Docker and Docker Compose installed.
- ~~A Clerk.dev account and application set up.~~
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

FRONTEND_PORT=9785

# -- API CONFIGURATION --
VITE_BACKEND_API_URL=http://localhost:9784
VITE_BACKEND_HOST=http://0.0.0.0
VITE_API_BASE_URL=/api




# -------------------------
# Backend Environment
# -------------------------

# -- FLASK SERVER CONFIGURATION --
FLASK_RUN_PORT=9784
BACKEND_PORT=9784

ADB_SERVER_PORT=5039

# -- CORS CONFIGURATION --
CORS_ORIGINS=http://localhost:9785

# -- CLOUDFLARE TUNNELS --
# (Optional) A persistent Cloudflare Tunnel token for the "Start Named Tunnel" feature.
CLOUDFLARED_TUNNEL_TOKEN=eyJhIjoiNzQ3NDJl...

# The relative path for the API. This is prefixed to all API calls.
NEXT_PUBLIC_API_BASE_URL=/api

DEVICES_RANGE="192.168.1.46-192.168.1.47"


DOCKER_GID=983
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
