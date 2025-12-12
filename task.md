# **FRONTEND REQUIREMENTS – Next.js + Clerk**

I want you to generate a full **Node.js (Next.js) frontend** and **Python Flask backend**, with **Clerk authentication**, **ADB automation**, **ws-scrcpy controls**, and **Cloudflared tunnel creation**.
The backend must be fully protected so only the frontend can access it.

<br>

## **1. Authentication (Clerk)**

* Use Clerk for login authentication.
* Environment variable:

  ```
  NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_ZXZpZGVu...hY2NvdW50cy5kZXYk
  ```
* Only authenticated users may access the dashboard.
* After login → redirect to **/dashboard**
* Create a **modern, beautiful, responsive login UI**.

<br>
<br>

## **2. Dashboard UI**

Create a **single-page responsive dashboard** containing buttons for each backend API endpoint:

### **ADB & Device Buttons**

| UI Button                          | Backend Endpoint              |
| ---------------------------------- | ----------------------------- |
| Assign TCP/IP                      | `/assign_tcpip`               |
| Get ADB Devices                    | `/get_adb_devices`            |
| Get mDNS Services                  | `/get_mdns_services`          |
| Connect All IP Devices             | `/connect_ip_devices`         |
| Connect a Device (input device-id) | `/connect_device/<device-id>` |

---

### **ws-scrcpy Controls**

| UI Button      | Backend Endpoint  |
| -------------- | ----------------- |
| Run ws-scrcpy  | `/run_ws_scrcpy`  |
| Stop ws-scrcpy | `/stop_ws_scrcpy` |

---

### **Cloudflared Tunnel Controls**

| UI Button              | Backend Endpoint       |
| ---------------------- | ---------------------- |
| Start ws-scrcpy Tunnel | `/start_scrcpy_tunnel` |
| Stop ws-scrcpy Tunnel  | `/stop_scrcpy_tunnel`  |

---

### **3. Dashboard Behavior**

* Frontend must send Clerk session token in every API call:

  ```
  Authorization: Bearer <CLERK_JWT>
  ```
* Each button displays response text in a log panel (`<pre>` output).
* Show public Cloudflare tunnel URL in dashboard.
* Automatically disable buttons while operations run.

<br>
<br>


## **BACKEND REQUIREMENTS – Python Flask**


### **1. Main API Endpoints**

Implement these endpoints:

```
/assign_tcpip
/get_adb_devices
/get_mdns_services
/connect_ip_devices
/connect_device/<device-id>
/run_ws_scrcpy
/stop_ws_scrcpy
/start_scrcpy_tunnel
/stop_scrcpy_tunnel
```

---

### **2. Shell Script Execution**

* `assign_tcpip` → run `assign_tcpip.sh`
* `connect_ip_devices` → run `connect_ip_devices.sh`
* Return text output of the scripts.

---

### **3. ADB Commands**

* `get_adb_devices` → run `adb devices`
* `get_mdns_services` → run `adb mdns services`
* `connect_device/<device-id>` →

  * run `adb connect <device-id>`
  * then return updated `adb devices` list

All commands must be executed using Python `subprocess.Popen` with captured stdout/stderr.


<br>
<br>

## **ws-scrcpy MANAGEMENT**

* ws-scrcpy lives in:

  ```
  /ws-scrcpy
  ```
* Running command:

  ```
  cd ws-scrcpy && npm start
  ```
* Must run in a **non-blocking background process**.

### **/run_ws_scrcpy**

* Starts the ws-scrcpy process
* Must prevent duplicate instances

### **/stop_ws_scrcpy**

* Kill running ws-scrcpy process safely


<br>
<br>

## **CLOUDFLARED TUNNEL INTEGRATION**


### **Environment Variable**

```
CLOUDFLARED_TUNNEL_TOKEN=eyJhIjoiNzQ3...
```

### **Goal**

Expose ws-scrcpy running on:

```
localhost:9786
```

through a temporary public Cloudflare URL using:

```
cloudflared tunnel run --token <token>
```

---

### **/start_scrcpy_tunnel** Behavior**

This endpoint must:

1. Start ws-scrcpy (if not already running).
2. Start Cloudflared tunnel:

   ```
   cloudflared tunnel run --token <token>
   ```
3. Run Cloudflared **as its own subprocess**, non-blocking.
4. Listen to Cloudflared output logs to detect the generated public URL.
   Typical line:

   ```
   INFO Connected! Tunnel URL: https://random-subdomain.trycloudflare.com
   ```
5. Return JSON:

   ```json
   {
     "status": "success",
     "public_url": "https://random-subdomain.trycloudflare.com",
     "local_url": "ws://localhost:9786"
   }
   ```

---

### **/stop_scrcpy_tunnel**

* Kill Cloudflared subprocess
* Stop ws-scrcpy if needed
* Return:

  ```json
  { "status": "success", "message": "Tunnel closed" }
  ```


<br>
<br>


## **SECURITY REQUIREMENTS**


### **1. Authentication**

Backend must verify Clerk JWT for every endpoint:

* Validate via Clerk JWKS
* Reject missing or invalid tokens (`401 Unauthorized`)

---

### **2. CORS Restrictions**

Allow only:

```
http://localhost:3000
https://your-frontend-domain.com
```

---

### **3. No Direct Access**

API must block:

* Curl requests without Clerk token
* Postman access without token
* External unauthorized scripts

Return:

```
401 Unauthorized: Invalid or missing Clerk token
```

---

### **4. One Tunnel Limit**

* Only one ws-scrcpy process at a time
* Only one Cloudflare tunnel at a time
* If running → return existing URL


<br>
<br>

## **BACKEND RESPONSE FORMAT**

Always return JSON:

```json
{
  "status": "success | error",
  "output": "<command output>",
  "public_url": "<tunnel url if applicable>",
  "details": "<logs or explanation>"
}
```


<br>
<br>

## **PROJECT STRUCTURE (REQUIRED)**

### **Frontend**

```
/frontend
  /pages
    login.jsx
    dashboard.jsx
  /components
    ButtonGroup.jsx
    LogOutput.jsx
  /utils
    apiClient.js
  .env.example
```

### **Backend**

```
/backend
  app.py
  auth_middleware.py
  process_manager.py
  /scripts
      assign_tcpip.sh
      connect_ip_devices.sh
  /ws-scrcpy
      (repo cloned here)
  .env.example
```

<br>
<br>

# **EXTRA REQUIREMENTS**


* Provide **full code** for:

  * Frontend (Next.js)
  * Backend (Flask)
  * Script execution
  * Cloudflared subprocess
  * ws-scrcpy process management
  * Clerk JWT verification
* Include:

  * Dockerfile for both frontend & backend
  * docker-compose.yml
  * Setup instructions
* Make UI clean and responsive.