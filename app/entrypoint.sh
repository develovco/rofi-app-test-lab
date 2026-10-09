#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  CTF Lab Entrypoint Script
#  Initializes logs and starts the Node.js application
# ═══════════════════════════════════════════════════════════

set -e

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   Admin Feedback System - CTF Lab Initializing...     ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# (Optional) Inject simulated attack logs
# /app/init-logs.sh

# Step 2: Start the Node.js application
echo ""
echo "[*] Phase 2: Starting Admin Feedback System..."
echo "[*] Application will be available on port 3000 (internal)"
echo ""

exec node /app/server.js
