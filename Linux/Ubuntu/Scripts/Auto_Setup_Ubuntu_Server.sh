#!/usr/bin/env bash
# ============================================================
#  Auto_Setup_Ubuntu_Server.sh — Initial server setup
# ============================================================

set -euo pipefail

# ── Colours ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

# ── Functions ───────────────────────────────────────────────
pause_and_clear() {
  echo -e "\n${BOLD}${GREEN}┌──────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ✔  ${BOLD}SECTION COMPLETE!${RESET}                            ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ${CYAN}Press any key to move to the next step...${RESET}       ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}└──────────────────────────────────────────────────┘${RESET}"
  read -n 1 -s -r
  clear
}

# ── Validate IPv4 format ─────────────────────────────────────
validate_ip() {
  local ip="$1"
  local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  if [[ ! "$ip" =~ $regex ]]; then return 1; fi
  IFS='.' read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    if (( octet > 255 )); then return 1; fi
  done
  return 0
}

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root (use sudo)."
  exit 1
fi

# ── TTY check (required for netplan try) ─────────────────────
if [[ ! -t 0 ]]; then
  error "This script must be run from an interactive terminal (TTY required)."
  exit 1
fi

clear

# ════════════════════════════════════════════════════════════
#  STEP 1 — System update
# ════════════════════════════════════════════════════════════
header "🖥️  Step 1 — System Update"
info "Checking for updates..."
apt-get update
apt-get upgrade -y
success "System is up to date."
pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 2 — Auto-detect network info
# ════════════════════════════════════════════════════════════
header "🌐  Step 2 — Detect Network Info"
info "Available Interfaces:"
ip -4 -br addr show | grep -v "lo" | while read -r line; do
    echo -e "  - ${BOLD}$(echo $line | awk '{print $1}')${RESET}: $(echo $line | awk '{print $2, $3}')"
done

DETECTED_GW=$(ip r | awk '/^default via/ {print $3; exit}')
DETECTED_IFACE=$(ip -4 -br addr | awk '$1 != "lo" && $3 != "" {print $1; exit}')
DETECTED_IP=$(ip -4 -br addr | awk -v iface="$DETECTED_IFACE" '$1 == iface {print $3; exit}' | cut -d/ -f1)

echo ""
info "Default Gateway   : ${DETECTED_GW:-<none>}"
info "Primary Interface : ${DETECTED_IFACE:-<none>}"
info "Primary Current IP: ${DETECTED_IP:-<none>}"

# ════════════════════════════════════════════════════════════
#  STEP 3 — Configure Static IP
# ════════════════════════════════════════════════════════════
header "⚙️   Step 3 — Configure Static IP"
read -rp "$(echo -e ${BOLD}"Network interface [${DETECTED_IFACE}]: "${RESET})" INPUT_IFACE
IFACE="${INPUT_IFACE:-$DETECTED_IFACE}"

# --- Validate Static IP ---
while true; do
  read -rp "$(echo -e ${BOLD}"Static IP to assign (no prefix) [${DETECTED_IP}]: "${RESET})" INPUT_STATIC
  STATIC_IP="${INPUT_STATIC:-$DETECTED_IP}"
  if validate_ip "$STATIC_IP"; then break
  else warn "Invalid IP address: '${STATIC_IP}'. Please enter a valid IPv4 address (e.g. 192.168.1.100)."; fi
done

read -rp "$(echo -e ${BOLD}"Prefix length [24]: "${RESET})" INPUT_PREFIX
PREFIX="${INPUT_PREFIX:-24}"

# --- Validate Gateway IP ---
while true; do
  read -rp "$(echo -e ${BOLD}"Gateway IP [${DETECTED_GW}]: "${RESET})" INPUT_GW
  GATEWAY="${INPUT_GW:-$DETECTED_GW}"
  if validate_ip "$GATEWAY"; then break
  else warn "Invalid gateway address: '${GATEWAY}'. Please enter a valid IPv4 address (e.g. 192.168.1.1)."; fi
done

# --- DNS Configuration ---
echo ""
info "DNS Configuration"
echo -e "  ${CYAN}Common options:${RESET}"
echo -e "    1.1.1.1, 1.0.0.1       (Cloudflare)"
echo -e "    8.8.8.8, 8.8.4.4       (Google)"
echo -e "    9.9.9.9, 149.112.112.112 (Quad9)"
echo ""

while true; do
  read -rp "$(echo -e ${BOLD}"Primary DNS [1.1.1.1]: "${RESET})" INPUT_DNS1
  DNS1="${INPUT_DNS1:-1.1.1.1}"
  if validate_ip "$DNS1"; then break
  else warn "Invalid DNS address: '${DNS1}'. Please enter a valid IPv4 address."; fi
done

while true; do
  read -rp "$(echo -e ${BOLD}"Secondary DNS [1.0.0.1]: "${RESET})" INPUT_DNS2
  DNS2="${INPUT_DNS2:-1.0.0.1}"
  if validate_ip "$DNS2"; then break
  else warn "Invalid DNS address: '${DNS2}'. Please enter a valid IPv4 address."; fi
done

echo ""
info "Configuration Summary:"
echo -e "  Interface : ${BOLD}${IFACE}${RESET}"
echo -e "  Static IP : ${BOLD}${STATIC_IP}/${PREFIX}${RESET}"
echo -e "  Gateway   : ${BOLD}${GATEWAY}${RESET}"
echo -e "  DNS       : ${BOLD}${DNS1}, ${DNS2}${RESET}"
echo ""

read -rp "$(echo -e ${YELLOW}"Proceed? [y/N]: "${RESET})" CONFIRM
if [[ ! "${CONFIRM,,}" =~ ^(y|yes)$ ]]; then
    warn "Aborted by user."
    exit 0
fi

# ════════════════════════════════════════════════════════════
#  CLEANUP — Disable conflicting Netplan configs
# ════════════════════════════════════════════════════════════
info "Checking for conflicting Netplan configurations..."
TARGET_FILENAME="01-network-manager-all.yaml"

# Use find to safely handle missing files without glob expansion issues
while IFS= read -r config_file; do
    if [[ "$(basename "$config_file")" != "$TARGET_FILENAME" ]]; then
        warn "Found conflicting config: $(basename "$config_file"). Disabling it..."
        mv "$config_file" "${config_file}.$(date +%Y%m%d_%H%M%S).bak"
    fi
done < <(find /etc/netplan -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)

# ════════════════════════════════════════════════════════════
#  STEP 4 — Write netplan config
# ════════════════════════════════════════════════════════════
header "📝  Step 4 — Write Netplan Config"
NETPLAN_FILE="/etc/netplan/${TARGET_FILENAME}"

if [[ -f "$NETPLAN_FILE" ]]; then
  cp "$NETPLAN_FILE" "${NETPLAN_FILE}.$(date +%Y%m%d_%H%M%S).bak"
fi

cat > "$NETPLAN_FILE" <<YAML
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: false
      addresses: [${STATIC_IP}/${PREFIX}]
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS1}, ${DNS2}]
YAML

chmod 600 "$NETPLAN_FILE"
success "Netplan config written."

# ════════════════════════════════════════════════════════════
#  STEP 5 — Apply config
# ════════════════════════════════════════════════════════════
header "🚀  Step 5 — Apply Netplan Config"
read -rp "$(echo -e ${BOLD}"Use 'netplan try' for safety? [Y/n]: "${RESET})" USE_TRY
USE_TRY="${USE_TRY:-y}"

if [[ "${USE_TRY,,}" =~ ^(y|yes)$ ]]; then
    info "Running 'netplan try' (120s timeout)..."
    netplan try
else
    info "Applying configuration immediately..."
    netplan apply
fi

echo ""
warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
warn "  Network config applied. If your SSH session dropped,"
warn "  reconnect using: ssh user@${STATIC_IP}"
warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 6 — SSH Welcome Message
# ════════════════════════════════════════════════════════════
header "💬  Step 6 — SSH Welcome Message"
read -rp "$(echo -e ${BOLD}"Disable SSH welcome message? [y/N]: "${RESET})" DO_MOTD

if [[ "${DO_MOTD,,}" =~ ^(y|yes)$ ]]; then
  PAM_SSHD="/etc/pam.d/sshd"
  if [[ -f "$PAM_SSHD" ]]; then
    cp "$PAM_SSHD" "${PAM_SSHD}.$(date +%Y%m%d_%H%M%S).bak"
    # Space-agnostic regex ensures both MOTD lines are commented out
    sed -i 's/^session\s\+optional\s\+pam_motd.so/#&/' "$PAM_SSHD"
    systemctl restart ssh
    success "SSH welcome message disabled."
  fi
fi
pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 7 — Timezone & Updates
# ════════════════════════════════════════════════════════════
header "🔄  Step 7 — Timezone & Updates"

# --- TIMEZONE LOGIC ---
info "Checking system timezone..."
CURRENT_TZ=$(timedatectl show --property=Timezone --value)
echo -e "Current Timezone: ${BOLD}${CURRENT_TZ:-Not Set}${RESET}"

read -rp "$(echo -e ${BOLD}"Change system timezone? [y/N]: "${RESET})" SET_TZ
if [[ "${SET_TZ,,}" =~ ^(y|yes)$ ]]; then
    while true; do
        echo -e "\n${CYAN}Timezone Selection:${RESET}"
        echo "1) America/New_York (Eastern)"
        echo "2) America/Chicago  (Central)"
        echo "3) America/Denver    (Mountain)"
        echo "4) America/Los_Angeles (Pacific)"
        echo "5) UTC"
        echo "6) Search by City or Country"
        echo "7) List ALL available timezones"
        echo "8) Skip / Keep Current"
        
        read -rp "$(echo -e ${BOLD}"Select an option [1-8]: "${RESET})" TZ_CHOICE
        case $TZ_CHOICE in
            1) SELECTED_TZ="America/New_York"; break ;;
            2) SELECTED_TZ="America/Chicago"; break ;;
            3) SELECTED_TZ="America/Denver"; break ;;
            4) SELECTED_TZ="America/Los_Angeles"; break ;;
            5) SELECTED_TZ="UTC"; break ;;
            6) 
                read -rp "Enter search keyword: " SEARCH_TERM
                MAPFILE_T=( $(timedatectl list-timezones | grep -i "$SEARCH_TERM" || true) )
                if [[ ${#MAPFILE_T[@]} -eq 0 ]]; then warn "No matches found.";
                elif [[ ${#MAPFILE_T[@]} -eq 1 ]]; then SELECTED_TZ="${MAPFILE_T[0]}"; break;
                else
                    for i in "${!MAPFILE_T[@]}"; do echo "$((i+1))) ${MAPFILE_T[$i]}"; done
                    read -rp "Select a number: " TZ_NUM
                    if [[ "$TZ_NUM" =~ ^[0-9]+$ ]] && [ "$TZ_NUM" -le "${#MAPFILE_T[@]}" ]; then
                        SELECTED_TZ="${MAPFILE_T[$((TZ_NUM-1))]}"; break
                    fi
                fi ;;
            7) timedatectl list-timezones; read -rp "Enter full timezone: " SELECTED_TZ
               if timedatectl list-timezones | grep -qx "$SELECTED_TZ"; then break; fi ;;
            8) SELECTED_TZ=$CURRENT_TZ; break ;;
            *) warn "Invalid choice." ;;
        esac
    done
    timedatectl set-timezone "$SELECTED_TZ"
    success "Timezone set to $SELECTED_TZ"
fi

# --- AUTOMATIC UPDATES LOGIC ---
echo ""
read -rp "$(echo -e ${BOLD}"Enable automatic updates? [y/N]: "${RESET})" DO_AUTO_UPDATES

if [[ "${DO_AUTO_UPDATES,,}" =~ ^(y|yes)$ ]]; then
    info "Installing unattended-upgrades..."
    apt-get install -y unattended-upgrades
    dpkg-reconfigure --priority=low unattended-upgrades
    success "Updates enabled."

    # --- AUTO-REBOOT ---
    echo ""
    read -rp "$(echo -e ${BOLD}"Configure auto-reboots? [y/N]: "${RESET})" DO_REBOOT
    if [[ "${DO_REBOOT,,}" =~ ^(y|yes)$ ]]; then
        UPGRADES_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
        if [[ -f "$UPGRADES_CONF" ]]; then
            cp "$UPGRADES_CONF" "${UPGRADES_CONF}.$(date +%Y%m%d_%H%M%S).bak"
            
            echo -e "\n${CYAN}Reboot Time Format:${RESET}"
            echo "1) 24-hour format (e.g., 04:00, 16:30)"
            echo "2) 12-hour format (e.g., 4:00 AM, 2:30 PM)"
            read -rp "Select format [1-2]: " TIME_FORMAT

            if [[ "$TIME_FORMAT" == "2" ]]; then
                read -rp "Enter time (e.g., 2:00 PM): " RAW_TIME
                REBOOT_TIME=$(date -d "$RAW_TIME" +"%H:%M" 2>/dev/null || echo "INVALID")
            else
                read -rp "Enter time (24h format) [04:00]: " REBOOT_TIME
                REBOOT_TIME="${REBOOT_TIME:-04:00}"
                if ! [[ "$REBOOT_TIME" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                    REBOOT_TIME="INVALID"
                fi
            fi

            if [[ "$REBOOT_TIME" == "INVALID" ]]; then
                error "Invalid time format. Reverting to default 04:00."
                REBOOT_TIME="04:00"
            fi

            # Remove old reboot settings and append fresh ones
            sed -i '/Unattended-Upgrade::Automatic-Reboot/d' "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot \"true\";" >> "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot-Time \"${REBOOT_TIME}\";" >> "$UPGRADES_CONF"
            
            FRIENDLY_CONFIRM=$(date -d "$REBOOT_TIME" +"%r")
            success "Auto-reboot scheduled for $REBOOT_TIME ($FRIENDLY_CONFIRM)."
        fi
    fi

    # --- DRY RUN ---
    echo ""
    info "Running verification dry-run..."
    unattended-upgrade --dry-run --debug 2>&1 | tail -10
    success "Verification complete."

else
    info "Skipping automatic updates."
fi
pause_and_clear

# ════════════════════════════════════════════════════════════
#  Finish
# ════════════════════════════════════════════════════════════
CURRENT_USER="${SUDO_USER:-$(whoami)}"
CURRENT_HOSTNAME=$(hostname)

echo -e "\n${BOLD}${GREEN}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  ✅  Server setup complete! 🎉                         ${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════${RESET}"
echo -e ""
echo -e "${BOLD}${CYAN}  🔌  How to connect via SSH:${RESET}"
echo -e ""
echo -e "  ${BOLD}By IP address:${RESET}"
echo -e "    ${YELLOW}ssh ${CURRENT_USER}@${STATIC_IP}${RESET}"
echo -e ""
echo -e "  ${BOLD}By hostname:${RESET}"
echo -e "    ${YELLOW}ssh ${CURRENT_USER}@${CURRENT_HOSTNAME}${RESET}"
echo -e ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════${RESET}\n"
