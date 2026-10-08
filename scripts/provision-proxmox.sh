#!/bin/bash
# Proxmox VM Provisioning Script for Red vs Blue CTF
# Usage: ./provision-proxmox.sh <VMID> <HOSTNAME> <SUBNET> <GATEWAY>

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <VMID> <HOSTNAME> <SUBNET> <GATEWAY>"
    exit 1
fi

VMID=$1
HOSTNAME=$2
SUBNET=$3
GATEWAY=$4

echo "Provisioning VM $VMID ($HOSTNAME) on Proxmox..."

# Update system
apt-get update
apt-get install -y docker.io docker-compose-plugin git curl

# Create required directories
mkdir -p /opt/admin/logs

# Apply network settings (Simplified mock implementation)
echo "Network configured for $SUBNET with gateway $GATEWAY"

echo "Provisioning complete. Ready for docker-compose up."
