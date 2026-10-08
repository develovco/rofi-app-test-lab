#!/usr/bin/env python3
import os
import time

LOG_DIR = "/opt/admin/logs"
ACCESS_LOG = os.path.join(LOG_DIR, "access.log")
ERROR_LOG = os.path.join(LOG_DIR, "error.log")

def inject_logs():
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Check if already injected
    if os.path.exists(ACCESS_LOG) and "10.10.14.50" in open(ACCESS_LOG).read():
        print("Logs already injected, skipping.")
        return

    print("Injecting forensic telemetry...")

    access_log_data = """192.168.1.100 - - [09/Oct/2026:18:45:10 +0000] "GET / HTTP/1.1" 200 2145 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
10.10.14.50 - - [09/Oct/2026:18:50:12 +0000] "POST /api/feedback HTTP/1.1" 403 145 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0"
10.10.14.50 - - [09/Oct/2026:18:50:40 +0000] "POST /api/feedback HTTP/1.1" 200 85 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0"
10.10.14.50 - - [09/Oct/2026:18:51:40 +0000] "GET /api/catch?data=pre_mfa_session=pending_mfa_verification HTTP/1.1" 404 120 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "UEhBTlRPTUdSSUR7QkxVRV9MMGdfSHVudDNyX000c3Qzcn0="
10.10.14.50 - - [09/Oct/2026:18:51:55 +0000] "GET /dashboard HTTP/1.1" 200 3450 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0"
"""

    error_log_data = """[2026-10-09 18:50:15] [WARNING] WAF_BLOCK: Blocked payload from 10.10.14.50 - Reason: Contains <script> tags
[2026-10-09 18:52:33] [CRITICAL] Cookie reuse detected: pre_mfa_session accessed outside expected flow from 10.10.14.50
[2026-10-09 18:53:10] [CRITICAL] Authentication bypass anomaly: Dashboard accessed with valid adm_sess token but no MFA verification log exists for IP 10.10.14.50
"""

    with open(ACCESS_LOG, "w") as f:
        f.write(access_log_data)
        
    with open(ERROR_LOG, "w") as f:
        f.write(error_log_data)
        
    print("Log injection complete.")

if __name__ == "__main__":
    inject_logs()
