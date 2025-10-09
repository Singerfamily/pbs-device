#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Check for required arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <host> <configuration>"
  exit 1
fi
HOST="$1"
CONFIGURATION="$2"

# check if we have the "--no-reboot" argument
if [ "$3" == "--no-reboot" ]; then
  echo "Reboot disabled"
  export NIXOS_ANYWHERE_NO_REBOOT=1
fi

# Create a temporary directory
temp=$(mktemp -d)

# Variable to track if we added a key to .sops.yaml
SOPS_KEY_ADDED=false

# Function to cleanup temporary directory on exit
cleanup() {
  # If we added a key and the script failed, remove it
  if [ "$SOPS_KEY_ADDED" = true ] && [ $? -ne 0 ]; then
    echo "Deployment failed, removing added age key from .sops.yaml"
    # Remove the line containing the configuration name that was just added
    sed -i "/# $CONFIGURATION$/d" .sops.yaml
    # Optionally update keys again to reflect the change
    sops updatekeys ./secrets/secrets.yaml 2>/dev/null || true
  fi
  rm -rf "$temp"
}
trap cleanup EXIT

# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/etc/ssh"

# Generate a new ed25519 host key
ssh-keygen -t ed25519 -f "$temp/etc/ssh/ssh_host_ed25519_key" -N ""

# Set the correct permissions so sshd will accept the key
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

# Load keys to sops
echo "      - $(ssh-to-age < $temp/etc/ssh/ssh_host_ed25519_key.pub) # $CONFIGURATION" >> .sops.yaml
SOPS_KEY_ADDED=true

sops updatekeys ./secrets/secrets.yaml

# Default phases to run
# kexec,disko,install,reboot
# If we have the "--no-reboot" argument, skip the reboot phase
phases="kexec,disko,install"
if [ "$NIXOS_ANYWHERE_NO_REBOOT" = "1" ]; then
  echo "Reboot disabled, skipping reboot phase"
else
  phases="kexec,disko,install,reboot"
fi

nix run github:nix-community/nixos-anywhere -- --extra-files "$temp" --flake .#$CONFIGURATION --target-host $HOST --phases $phases