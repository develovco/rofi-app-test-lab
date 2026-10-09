#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  PROXMOX VM PROVISIONING SCRIPT
#  Red vs. Blue CTF Lab — Cookies Reuse & MFA Bypass
#  ─────────────────────────────────────────────────────────────────
#  This script provisions a Linux VM (Debian/Ubuntu) on Proxmox
#  to host the CTF lab. Run as root on the target VM after
#  performing the base OS install.
#
#  Usage:
#    chmod +x provision-proxmox.sh
#    sudo ./provision-proxmox.sh
#
#  Prerequisites:
#    - Fresh Debian 12 / Ubuntu 22.04+ VM on Proxmox
#    - Root access
#    - Internet connectivity (for package downloads)
#    - VM placed in internal network zone (e.g., feedback.admin.local)
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ──────────────────────────────────────────────
#  CONFIGURATION
# ──────────────────────────────────────────────
HOSTNAME="feedback-admin-local"
LAB_DIR="/opt/ctf-lab"
REPO_URL="${1:-}"  # Optional: git clone URL as first argument
SSH_USER="analyst"
SSH_PASS="blue_team_rocks"

# ──────────────────────────────────────────────
#  BANNER
# ──────────────────────────────────────────────
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   SCENARIO75 — CTF Lab Provisioning Script                ║"
echo "║   Red vs. Blue: Cookies Reuse & MFA Bypass                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────
#  STEP 1: System Update & Dependencies
# ──────────────────────────────────────────────
echo "[*] Step 1/7: Updating system and installing dependencies..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    htop \
    vim \
    wget

# ──────────────────────────────────────────────
#  STEP 2: Install Docker Engine
# ──────────────────────────────────────────────
echo "[*] Step 2/7: Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    echo "[+] Docker installed successfully"
else
    echo "[+] Docker already installed"
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker
echo "[+] Docker service is running"

# ──────────────────────────────────────────────
#  STEP 3: Configure Hostname & Networking
# ──────────────────────────────────────────────
echo "[*] Step 3/7: Configuring hostname and networking..."
hostnamectl set-hostname "$HOSTNAME"

# Add local DNS entry for the lab
if ! grep -q "feedback.admin.local" /etc/hosts; then
    echo "127.0.0.1 feedback.admin.local" >> /etc/hosts
    echo "[+] Added feedback.admin.local to /etc/hosts"
fi

# ──────────────────────────────────────────────
#  STEP 4: Configure Firewall
# ──────────────────────────────────────────────
echo "[*] Step 4/7: Configuring firewall rules..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp comment 'SSH - Management & Blue Team'

# Allow HTTP for the web application
ufw allow 3075/tcp comment 'HTTP - CTF Web App'

ufw --force enable
echo "[+] Firewall configured: ports 22, 3075 open"

# ──────────────────────────────────────────────
#  STEP 5: Create Blue Team SSH User (Host-level)
# ──────────────────────────────────────────────
echo "[*] Step 5/7: Creating Blue Team analyst user..."
if id "${SSH_USER}" &>/dev/null; then
    echo "[+] User '${SSH_USER}' already exists"
else
    useradd -m -s /bin/bash "${SSH_USER}"
    echo "${SSH_USER}:${SSH_PASS}" | chpasswd
    echo "[+] User '${SSH_USER}' created (password: ${SSH_PASS})"
fi

# ──────────────────────────────────────────────
#  STEP 6: Deploy CTF Lab
# ──────────────────────────────────────────────
echo "[*] Step 6/7: Deploying CTF lab..."
mkdir -p "$LAB_DIR"

if [ -n "$REPO_URL" ]; then
    echo "[*] Cloning repository from: $REPO_URL"
    if [ -d "${LAB_DIR}/red-vs-blue-ctf" ]; then
        echo "[*] Existing deployment found, pulling latest..."
        cd "${LAB_DIR}/red-vs-blue-ctf"
        git pull
    else
        git clone "$REPO_URL" "${LAB_DIR}/red-vs-blue-ctf"
        cd "${LAB_DIR}/red-vs-blue-ctf"
    fi
else
    echo "[!] No repository URL provided."
    echo "[!] Please clone your repo to ${LAB_DIR}/red-vs-blue-ctf"
    echo "[!] Then run: cd ${LAB_DIR}/red-vs-blue-ctf && docker compose up -d --build"
    echo ""
fi

# Create the shared log directory on the host
mkdir -p /opt/admin/logs
chmod 755 /opt/admin/logs

# Build and start all containers
if [ -f "${LAB_DIR}/red-vs-blue-ctf/docker-compose.yml" ]; then
    cd "${LAB_DIR}/red-vs-blue-ctf"
    echo "[*] Building and starting containers..."
    docker compose up -d --build
    echo "[+] Containers started"

    # Wait for services to be healthy
    echo "[*] Waiting for services to become healthy..."
    sleep 10

    echo ""
    echo "[*] Service Status:"
    docker compose ps
fi

# ──────────────────────────────────────────────
#  STEP 7: Verification
# ──────────────────────────────────────────────
echo ""
echo "[*] Step 7/7: Running verification checks..."
echo ""

PASS=0
FAIL=0

# Check Docker
if systemctl is-active --quiet docker; then
    echo "  [✓] Docker is running"
    ((PASS++))
else
    echo "  [✗] Docker is NOT running"
    ((FAIL++))
fi

# Check web app port
if ss -tlnp | grep -q ":3075"; then
    echo "  [✓] Web app listening on port 3075"
    ((PASS++))
else
    echo "  [✗] Web app NOT listening on port 3075"
    ((FAIL++))
fi

# Check SSH port
if ss -tlnp | grep -q ":22 "; then
    echo "  [✓] SSH listening on port 22"
    ((PASS++))
else
    echo "  [✗] SSH NOT listening on port 22"
    ((FAIL++))
fi

# Check log directory
if [ -d "/opt/admin/logs" ]; then
    echo "  [✓] Log directory exists at /opt/admin/logs"
    ((PASS++))
else
    echo "  [✗] Log directory missing"
    ((FAIL++))
fi

# Check analyst user
if id "${SSH_USER}" &>/dev/null; then
    echo "  [✓] Blue Team user '${SSH_USER}' exists"
    ((PASS++))
else
    echo "  [✗] Blue Team user '${SSH_USER}' missing"
    ((FAIL++))
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   PROVISIONING COMPLETE                                   ║"
echo "║   Passed: ${PASS}  |  Failed: ${FAIL}                    ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
echo "║   Web App:   http://feedback.admin.local:3075             ║"
echo "║   Blue SSH:  ssh analyst@<VM_IP>                          ║"
echo "║   Password:  ${SSH_PASS}                                  ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
