---
title: "SCENARIO75 — Red vs. Blue CTF Lab"
subtitle: "Cookies Reuse & MFA Bypass"
author: "Security Training Delivery"
date: "October 2026"
---

# 🛡️ SCENARIO75
## Red vs. Blue CTF Lab — Cookies Reuse & MFA Bypass

**Version:** 1.0  
**Date:** October 2026  
**Classification:** Training — Intentionally Vulnerable

---

# Presentation Slides (15–20 min)

## Slide 1 — Title
**SCENARIO75 — Cookies Reuse & MFA Bypass**  
Red vs. Blue CTF Lab  
[Your Name] · [Date]

## Slide 2 — Objectives
- Deploy a reproducible CTF lab on Proxmox
- Demonstrate WAF bypass via HTML5 parser differentials
- Chain XSS → cookie theft → MFA bypass
- Provide a Blue Team forensic story
- Deliver code + docs + live demo

## Slide 3 — Architecture
Nginx :80 → Node.js :3000 · SSH :22 · Shared log volume  
Exposed: :3075 (web) · :2275 (ssh)

## Slide 4 — Vulnerability Overview
1. WAF blocklist is naive — blocks `<script>` but not `<svg onload>`
2. Cookie is not `HttpOnly` — XSS can read it
3. Backend trusts `adm_sess_*` — MFA endpoint skipped

## Slide 5 — Red Team Demo (LIVE)
- Phase 1: Reconnaissance (Finding hidden endpoints)
- Phase 2: Defense Evasion (Bypassing WAF rules)
- Phase 3: Initial Access (Session Replay & MFA Bypass)
*(Exploit demonstration and payloads omitted from documentation for safety)*

## Slide 6 — Blue Team Demo (LIVE)
```bash
ssh analyst@localhost -p 2275
cat /opt/admin/logs/access.log
grep "10.10.14.50" /opt/admin/logs/access.log
grep -i CRITICAL /opt/admin/logs/error.log
echo 'UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0=' | base64 -d
# → PHANTOMGRID{BLUE_L0g_HUnt3r_M4st3r}
```

## Slide 7 — Attack Timeline
| Time | Event |
|------|-------|
| 18:50:12 | POST `<script>` → 403 |
| 18:50:15 | First WAF block logged |
| 18:50:40 | POST `<svg onload>` → 200 |
| 18:51:40 | Exfil via `/api/catch` |
| 18:51:55 | `/dashboard` → 200 (bypass) |
| 18:52:33 | Cookie reuse — CRITICAL |
| 18:53:10 | Auth bypass anomaly — CRITICAL |
| — | MFA endpoint never hit |

## Slide 8 — Lessons Learned
- A WAF is not a security boundary
- `HttpOnly` on every session cookie is non-negotiable
- MFA must be enforced at the privileged endpoint
- Detection requires application-layer logging
- Chained low-severity bugs = high-severity bypass

## Slide 9 — Deployment
```bash
git clone https://github.com/your-org/red-vs-blue-ctf.git
cd red-vs-blue-ctf
docker compose up -d --build
```

## Slide 10 — Q&A
**Thank you.** Questions?
