#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  SIMULATED ATTACK LOG INJECTION SCRIPT
#  ─────────────────────────────────────────────────────────────────
#  This script injects a realistic, pre-crafted attack sequence
#  into the server logs upon deployment. The Blue Team must analyze
#  these logs to reconstruct the full attack chain.
#
#  Attack Timeline (simulated):
#  18:45:00 - Admin baseline activity begins
#  18:48:00 - Attacker (10.10.14.50) begins reconnaissance
#  18:50:15 - First WAF block (<script> attempt)
#  18:50:45 - Successful XSS via <svg> bypass
#  18:51:00 - Admin views poisoned feedback
#  18:51:20 - Cookie exfiltration via XSS callback
#  18:51:55 - Attacker replays stolen cookie → dashboard access
#  18:53:10 - Authentication bypass anomaly logged
# ═══════════════════════════════════════════════════════════════════

LOG_DIR="/opt/admin/logs"
mkdir -p "$LOG_DIR"

# Prevent duplicate injection on container restart
if [ -f "$LOG_DIR/.logs_initialized" ]; then
    echo "[*] Simulated logs already injected, skipping..."
    exit 0
fi

echo "[*] Injecting simulated attack sequence into logs..."

# ─── ACCESS LOG (Nginx-style combined + X-Forwarded-For) ──────────
# Format: $remote_addr - $remote_user [$time_local] "$request"
#         $status $body_bytes_sent "$http_referer"
#         "$http_user_agent" "$http_x_forwarded_for"
#
# FLAGS embedded in this log:
#   SCENARIO75{10.10.14.50}       - Attacker IP
#   SCENARIO75{Mozilla/5.0}       - Attacker User-Agent
#   SCENARIO75{200}               - Dashboard access status
#   SCENARIO75{18:51:55}          - Dashboard access timestamp
#   SCENARIO75{192.168.1.100}     - Legitimate admin IP
#   SCENARIO75{UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}} - Base64 in X-Forwarded-For
# ──────────────────────────────────────────────────────────────────

cat > "$LOG_DIR/access.log" << 'ACCESSEOF'
192.168.1.100 - admin [09/Oct/2026:18:45:00 +0000] "GET /dashboard HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - admin [09/Oct/2026:18:45:30 +0000] "GET /api/feedback HTTP/1.1" 200 1250 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - - [09/Oct/2026:18:46:00 +0000] "GET /public/css/style.css HTTP/1.1" 200 3840 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - admin [09/Oct/2026:18:47:00 +0000] "GET /dashboard HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - admin [09/Oct/2026:18:47:30 +0000] "POST /api/verify-mfa HTTP/1.1" 200 185 "http://feedback.admin.local/mfa" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
10.10.14.50 - - [09/Oct/2026:18:48:00 +0000] "GET / HTTP/1.1" 200 6234 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:48:15 +0000] "GET /robots.txt HTTP/1.1" 200 45 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:48:45 +0000] "GET /login HTTP/1.1" 200 3150 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:49:00 +0000] "GET /dashboard HTTP/1.1" 302 0 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:49:30 +0000] "GET /login HTTP/1.1" 200 3150 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:50:15 +0000] "POST /api/feedback HTTP/1.1" 403 89 "http://feedback.admin.local/" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:50:45 +0000] "POST /api/feedback HTTP/1.1" 200 52 "http://feedback.admin.local/" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
192.168.1.100 - admin [09/Oct/2026:18:51:00 +0000] "GET /dashboard HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - admin [09/Oct/2026:18:51:10 +0000] "GET /api/feedback HTTP/1.1" 200 2340 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - - [09/Oct/2026:18:51:20 +0000] "GET /api/catch?data=adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e HTTP/1.1" 200 0 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0}"
10.10.14.50 - - [09/Oct/2026:18:51:55 +0000] "GET /dashboard HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
10.10.14.50 - - [09/Oct/2026:18:52:00 +0000] "GET /api/feedback HTTP/1.1" 200 2340 "http://feedback.admin.local/dashboard" "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0" "-"
192.168.1.100 - admin [09/Oct/2026:18:55:00 +0000] "GET /dashboard HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
192.168.1.100 - admin [09/Oct/2026:18:57:00 +0000] "POST /api/verify-mfa HTTP/1.1" 200 185 "http://feedback.admin.local/mfa" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36" "-"
ACCESSEOF

# ─── ERROR LOG (Application-level) ──────────────────────────────
# FORMAT: [timestamp] [LEVEL] [CONTEXT] message
#
# FLAGS embedded in this log:
#   SCENARIO75{/opt/admin/logs}                    - Log location
#   SCENARIO75{/opt/admin/logs/error.log}          - Error log path
#   SCENARIO75{<script>}                           - WAF blocked tag
#   SCENARIO75{18:50:15}                           - First WAF block timestamp
#   SCENARIO75{No}                                 - Attacker never reached MFA endpoint
#   SCENARIO75{CRITICAL}                           - Cookie reuse log level
#   SCENARIO75{18:53:10}                           - Bypass anomaly timestamp
#   SCENARIO75{Authentication bypass anomaly}      - Security warning string
#   SCENARIO75{Base64}                             - Encoding method
#   SCENARIO75{44}                                 - Encoded string length
#   SCENARIO75{10.10.14.0/24}                      - Attacker subnet
# ──────────────────────────────────────────────────────────────────

cat > "$LOG_DIR/error.log" << 'ERROREOF'
[2026-10-09T18:45:00.000Z] [INFO] Admin Feedback System started on port 3000
[2026-10-09T18:45:01.000Z] [INFO] Pre-created admin session: adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e
[2026-10-09T18:45:02.000Z] [INFO] WAF engine initialized - Rules: block <script>, block document.cookie
[2026-10-09T18:45:03.000Z] [INFO] Session handler configured with prefix: adm_sess
[2026-10-09T18:47:30.000Z] [INFO] MFA verification successful for admin from 192.168.1.100
[2026-10-09T18:48:00.000Z] [INFO] New visitor from 10.10.14.50 - pre_mfa_session cookie issued
[2026-10-09T18:48:15.000Z] [INFO] robots.txt accessed from 10.10.14.50
[2026-10-09T18:48:45.000Z] [INFO] Login page accessed from 10.10.14.50
[2026-10-09T18:49:00.000Z] [WARNING] Unauthorized dashboard access attempt from 10.10.14.50 - redirected to /login
[2026-10-09T18:50:15.000Z] [WARNING] [SECURITY] WAF_BLOCK: Blocked payload from 10.10.14.50 - Reason: <script> tag detected
[2026-10-09T18:50:45.000Z] [INFO] Feedback submitted from 10.10.14.50
[2026-10-09T18:51:00.000Z] [INFO] Admin dashboard accessed from 192.168.1.100
[2026-10-09T18:51:10.000Z] [INFO] Feedback API accessed by admin from 192.168.1.100
[2026-10-09T18:51:20.000Z] [CRITICAL] [SECURITY] Exfiltration attempt captured: adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e from 192.168.1.100
[2026-10-09T18:51:55.000Z] [CRITICAL] [SECURITY] Cookie replay detected for session: adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e from 10.10.14.50
[2026-10-09T18:52:00.000Z] [WARNING] [SECURITY] Suspicious session usage - adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e accessed from new IP 10.10.14.50 (original: 192.168.1.100)
[2026-10-09T18:53:10.000Z] [CRITICAL] [SECURITY] Authentication bypass anomaly - Session adm_sess_7f3c2d1a8b4e9f6c5d2a1b0e used without MFA verification from 10.10.14.50
[2026-10-09T18:55:00.000Z] [INFO] Admin dashboard accessed from 192.168.1.100
[2026-10-09T18:57:00.000Z] [INFO] MFA verification successful for admin from 192.168.1.100
ERROREOF

# Set proper permissions so Blue Team analyst can read
chmod 644 "$LOG_DIR/access.log" "$LOG_DIR/error.log"

# Mark as initialized to prevent duplicate injection
touch "$LOG_DIR/.logs_initialized"

echo "[+] ✓ Attack simulation logs injected successfully"
echo "[+] ✓ access.log: $(wc -l < "$LOG_DIR/access.log") entries"
echo "[+] ✓ error.log:  $(wc -l < "$LOG_DIR/error.log") entries"
echo "[+] ✓ Log files available at $LOG_DIR"
