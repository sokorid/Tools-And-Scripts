#!/bin/bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# ==================================================================
#  Clear_Port_53.sh — resolves port conflicts by disabling port 53
# ==================================================================
set -euo pipefail

RC="/etc/resolv.conf"

# --- Root check ---
[[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }

# --- Validate IP (all 4 octets must be 0-255) ---
valid_ip() {
    local IFS='.'; local -a o=($1); [[ ${#o[@]} -eq 4 ]] || return 1
    for oct in "${o[@]}"; do [[ "$oct" =~ ^[0-9]+$ ]] && (( oct <= 255 )) || return 1; done
}

# --- DNS Selection ---
echo ""
echo "A DNS server translates domain names (like google.com) into IP addresses."
echo "Your system currently uses systemd-resolved for this, which occupies port 53."
echo "This script will disable it and point your system to a public DNS server instead."
echo "Cloudflare (1.1.1.1) and Google (8.8.8.8) are fast, reliable, and free options."
echo ""
echo "Select DNS server:"
echo "  1) Cloudflare  (1.1.1.1)"
echo "  2) Google      (8.8.8.8)"
echo "  3) Manual entry"
read -rp "Choice [1/2/3] (default 1): " choice
case "${choice:-1}" in
    1) DNS="1.1.1.1" ;;
    2) DNS="8.8.8.8" ;;
    3) read -rp "Enter DNS IP: " DNS ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

valid_ip "$DNS" || { echo "Invalid IP: $DNS"; exit 1; }

# --- Trap: auto-restore on failure ---
cleanup() {
    local code=$?
    rm -f "$RC.tmp"
    [[ $code -ne 0 && -f "$RC.bak" ]] && cp "$RC.bak" "$RC" && echo "Restored $RC from backup."
}
trap cleanup EXIT

# --- Install missing dependencies (lazy apt-get update) ---
declare -A pkgs=(["lsof"]="lsof" ["netstat"]="net-tools" ["nslookup"]="dnsutils")
updated=false
for cmd in "${!pkgs[@]}"; do
    command -v "$cmd" &>/dev/null && continue
    $updated || { apt-get update -y; updated=true; }
    apt-get install -y "${pkgs[$cmd]}"
done

# --- Show what's on port 53, then confirm ---
echo ""; echo "Processes on port 53:"
lsof -i :53 2>/dev/null || netstat -tulpn 2>/dev/null | grep ":53 " || echo "(none)"
read -rp "Disable systemd-resolved and set DNS to $DNS? (y/n): " ok
[[ "$ok" =~ [yY] ]] || { echo "Aborted."; exit 0; }

# --- Dereference symlink so it survives systemd-resolved stopping ---
if [[ -L "$RC" ]]; then
    cp "$(readlink -f "$RC")" "$RC.real" 2>/dev/null || true
    rm "$RC"; printf "# dns_reconfigure\nnameserver 1.1.1.1\n" > "$RC"
fi

# --- Backup ---
[[ -f "$RC.bak" ]] || cp "$RC" "$RC.bak"

# --- Stop systemd-resolved, wait for port 53 to clear (up to 5s) ---
systemctl disable --now systemd-resolved.service 2>/dev/null || true
for i in {1..5}; do lsof -i :53 &>/dev/null || break; sleep 1; done

# --- Validate DNS server resolves before applying ---
nslookup google.com "$DNS" &>/dev/null || { echo "$DNS failed to resolve. Exiting."; exit 1; }

# --- Write atomically (same filesystem, correct permissions) ---
tmp=$(mktemp -p /etc)
chmod 644 "$tmp"
if grep -q '^nameserver' "$RC"; then
    sed "s|^nameserver.*|nameserver $DNS|" "$RC" > "$tmp"
else
    cp "$RC" "$tmp"; echo "nameserver $DNS" >> "$tmp"
fi
mv "$tmp" "$RC"

echo "Done. DNS set to $DNS"
echo "To restore: sudo cp $RC.bak $RC"
