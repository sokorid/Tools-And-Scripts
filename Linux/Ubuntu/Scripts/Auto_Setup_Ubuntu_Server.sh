#!/usr/bin/env bash
# ============================================================
#  Auto_Setup_Ubuntu_Server.sh — Initial server setup
# ============================================================
set -euo pipefail

#the current version of The Script
SCRIPT_VERSION="4.4"

# Colors and UI
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0m')

# Check if the terminal is "dumb" or non-interactive
if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

info()    { printf "  ${CYAN}ℹ️${RESET}  %s\n" "$1"; }
success() { printf "  ${GREEN}✅${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}⚠️${RESET}  %s\n" "$1"; }
error()   { printf "  ${RED}❌${RESET}  %s\n" "$1" >&2; }
header() {
    printf "\n${BOLD}${CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD}${CYAN}  %s${RESET}\n" "$1"
    printf "${BOLD}${CYAN}════════════════════════════════════════════════════════════${RESET}\n"
}

# Function to handle y/n inputs but allow yes/no
# $1 = prompt text, $2 = optional hint shown in brackets (e.g. "y" or "n")
ask_yes_no() {
    local hint="${2:-y/n}"
    while true; do
        read -rp "  $1 [$hint]: " input
        case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) error "Please type y or n (or yes/no)." ;;
        esac
    done
}

# Function to handle Pause and Clear
pause_and_clear() {
  echo -e "\n${BOLD}${GREEN}┌──────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ✔  ${BOLD}STAGE COMPLETE!${RESET}                              ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ${CYAN}Press any key to move to the next step...${RESET}       ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}└──────────────────────────────────────────────────┘${RESET}"
  [[ -t 0 ]] && read -n 1 -s -r || true
  [[ -t 0 ]] && clear
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

# ── Validate prefix length (1–32) ────────────────────────────
validate_prefix() {
  local p="$1"
  [[ "$p" =~ ^([1-9]|[1-2][0-9]|3[0-2])$ ]]
}

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root (use sudo)."
  exit 1
fi

# ============================================================
#  Ubuntu version check — 26.04 LTS minimum
# ============================================================
check_ubuntu_version() {
    if ! command -v lsb_release &>/dev/null; then
        error "lsb_release not found. This script requires Ubuntu 22.04 LTS or later."
        exit 1
    fi

    local distro
    distro=$(lsb_release -si)
    if [[ "$distro" != "Ubuntu" ]]; then
        error "This script is designed for Ubuntu only. Detected: $distro"
        exit 1
    fi

    local version
    version=$(lsb_release -sr)
    local major
    major=$(echo "$version" | cut -d. -f1)

    if [[ "$major" -lt 26 ]]; then
        error "Ubuntu 26.04 LTS or later is required. Detected: Ubuntu $version"
        exit 1
    fi

    success "Ubuntu $version detected — compatible."
}

check_ubuntu_version

# ── TTY check (required for netplan try) ─────────────────────
if [[ ! -t 0 ]]; then
  error "This script must be run from an interactive terminal (TTY required)."
  exit 1
fi

clear

# ════════════════════════════════════════════════════════════
#  STEP 1 — System update
# ════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}📦  Auto Setup Ubuntu Server Script v${SCRIPT_VERSION}${RESET}"
header "🖥️  Step 1 — System Update"

info "Checking for updates..."
if apt-get update > /dev/null 2>&1; then
    success "Package lists refreshed."
else
    error "Failed to fetch package lists — check your internet connection."
    exit 1
fi

info "Installing updates — this may take a few minutes..."
echo -e "  ${CYAN}(Running in the background, please wait)${RESET}"
echo ""

FAILED_PKGS=()
while IFS= read -r line; do
    if [[ "$line" =~ ^Get: ]]; then
        pkg=$(echo "$line" | awk '{print $NF}')
        printf "  ${CYAN}↓ Downloading:${RESET} %s\n" "$pkg"
    elif [[ "$line" =~ ^Unpacking|^Setting\ up ]]; then
        pkg=$(echo "$line" | awk '{print $2}')
        printf "  ${GREEN}✔ Installing:${RESET}  %s\n" "$pkg"
    elif [[ "$line" =~ ^[Ee]rr:|^[Ee]rror ]]; then
        FAILED_PKGS+=("$line")
        printf "  ${RED}✘ Error:${RESET}       %s\n" "$line"
    fi
done < <(apt-get upgrade -y 2>&1)

echo ""
if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
    warn "${#FAILED_PKGS[@]} package(s) had errors during upgrade:"
    for pkg in "${FAILED_PKGS[@]}"; do
        echo -e "  ${RED}•${RESET} $pkg"
    done
    warn "The system may be partially updated — review the errors above before continuing."
    echo ""
    if ! ask_yes_no "$(echo -e "${YELLOW}Continue anyway?${RESET}")" "yes/no"; then
        error "Aborted by user."
        exit 1
    fi
else
    success "System is up to date."
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 2 — Auto-detect network info
# ════════════════════════════════════════════════════════════
header "🌐  Step 2 — Detect Network Info"

info "Scanning your system for active network interfaces..."
echo ""
echo -e "  ${CYAN}The following interfaces were found (loopback excluded):${RESET}"
ip -4 -br addr show | grep -v "^lo" | while read -r line; do
    iface=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    addr=$(echo "$line" | awk '{print $3}')
    echo -e "  - ${BOLD}${iface}${RESET}: ${state} ${addr:-<no IP assigned>}"
done

echo ""
info "Determining your current default route and primary interface..."

DETECTED_GW=$(ip r | awk '/^default via/ {print $3; exit}')
DETECTED_IFACE=$(ip -4 -br addr | awk '$1 != "lo" && $3 != "" {print $1; exit}')
DETECTED_IP=$(ip -4 -br addr | awk -v iface="$DETECTED_IFACE" \
    '$1 == iface {print $3; exit}' | cut -d/ -f1)

echo ""
echo -e "  ${CYAN}These values will be used as defaults in the next step.${RESET}"
echo -e "  ${CYAN}You can accept them by pressing Enter or type your own value.${RESET}"
echo ""
info "Default Gateway   : ${DETECTED_GW:-<none detected>}"
info "Primary Interface : ${DETECTED_IFACE:-<none detected>}"
info "Primary Current IP: ${DETECTED_IP:-<none detected>}"

# ════════════════════════════════════════════════════════════
#  STEP 3 — Configure Static IP
# ════════════════════════════════════════════════════════════
header "⚙️   Step 3 — Configure Static IP"

echo -e "  ${CYAN}A static IP ensures this machine always has the same address on"
echo -e "  the network — useful for servers, remote access, or port forwarding.${RESET}"
echo -e "  ${CYAN}Press Enter on any field to accept the detected default value.${RESET}"
echo ""

read -rp "$(echo -e "${BOLD}Network interface [${DETECTED_IFACE}]: ${RESET}")" INPUT_IFACE
IFACE="${INPUT_IFACE:-$DETECTED_IFACE}"

echo ""
echo -e "  ${CYAN}Enter the IP address you want to permanently assign to ${BOLD}${IFACE}${RESET}${CYAN}."
echo -e "  Make sure this address is not already in use on your network.${RESET}"
echo ""

while true; do
    read -rp "$(echo -e "${BOLD}Static IP to assign (no prefix) [${DETECTED_IP}]: ${RESET}")" INPUT_STATIC
    STATIC_IP="${INPUT_STATIC:-$DETECTED_IP}"
    if validate_ip "$STATIC_IP"; then break
    else warn "Invalid IP address: '${STATIC_IP}'. Please enter a valid IPv4 address (e.g. 192.168.1.100)."; fi
done

echo ""
echo -e "  ${CYAN}The prefix length defines your subnet size.${RESET}"
echo -e "  ${CYAN}  /24 = 255.255.255.0  (most home & office networks)${RESET}"
echo -e "  ${CYAN}  /16 = 255.255.0.0    (larger networks)${RESET}"
echo -e "  ${CYAN}  /8  = 255.0.0.0      (very large networks)${RESET}"
echo ""

while true; do
    read -rp "$(echo -e "${BOLD}Prefix length [24]: ${RESET}")" INPUT_PREFIX
    PREFIX="${INPUT_PREFIX:-24}"
    if validate_prefix "$PREFIX"; then break
    else warn "Invalid prefix: '${PREFIX}'. Please enter a number between 1 and 32 (e.g. 24)."; fi
done

echo ""
echo -e "  ${CYAN}The gateway is your router's IP address — all traffic destined${RESET}"
echo -e "  ${CYAN}outside your local network will be sent through it.${RESET}"
echo ""

while true; do
    read -rp "$(echo -e "${BOLD}Gateway IP [${DETECTED_GW}]: ${RESET}")" INPUT_GW
    GATEWAY="${INPUT_GW:-$DETECTED_GW}"
    if validate_ip "$GATEWAY"; then break
    else warn "Invalid gateway address: '${GATEWAY}'. Please enter a valid IPv4 address (e.g. 192.168.1.1)."; fi
done

echo ""
info "DNS Configuration"
echo -e "  ${CYAN}DNS servers translate domain names (e.g. google.com) into IP addresses."
echo -e "  Two servers are configured for redundancy — if the primary is unreachable,"
echo -e "  your system automatically falls back to the secondary.${RESET}"
echo ""
echo -e "  ${CYAN}Common options:${RESET}"
echo -e "    1.1.1.1,  1.0.0.1         (Cloudflare — fast, privacy-focused)"
echo -e "    8.8.8.8,  8.8.4.4         (Google — reliable, widely used)"
echo -e "    9.9.9.9,  149.112.112.112  (Quad9 — security & malware filtering)"
echo ""

while true; do
    read -rp "$(echo -e "${BOLD}Primary DNS [1.1.1.1]: ${RESET}")" INPUT_DNS1
    DNS1="${INPUT_DNS1:-1.1.1.1}"
    if validate_ip "$DNS1"; then break
    else warn "Invalid DNS address: '${DNS1}'. Please enter a valid IPv4 address."; fi
done

while true; do
    read -rp "$(echo -e "${BOLD}Secondary DNS [1.0.0.1]: ${RESET}")" INPUT_DNS2
    DNS2="${INPUT_DNS2:-1.0.0.1}"
    if validate_ip "$DNS2"; then break
    else warn "Invalid DNS address: '${DNS2}'. Please enter a valid IPv4 address."; fi
done

echo ""
info "Configuration Summary:"
echo -e "  ${CYAN}Please review your settings carefully before continuing."
echo -e "  Applying an incorrect IP or gateway can disconnect this machine from the network.${RESET}"
echo ""
echo -e "  Interface : ${BOLD}${IFACE}${RESET}"
echo -e "  Static IP : ${BOLD}${STATIC_IP}/${PREFIX}${RESET}"
echo -e "  Gateway   : ${BOLD}${GATEWAY}${RESET}"
echo -e "  DNS       : ${BOLD}${DNS1}, ${DNS2}${RESET}"
echo ""

if ! ask_yes_no "$(echo -e "${YELLOW}Proceed with these settings?${RESET}")" "yes/no"; then
    warn "Aborted by user. No changes have been made to your system."
    exit 0
fi

# ════════════════════════════════════════════════════════════
#  CLEANUP — Disable conflicting Netplan configs
# ════════════════════════════════════════════════════════════
info "Checking for conflicting Netplan configurations..."
TARGET_FILENAME="01-network-manager-all.yaml"

while IFS= read -r config_file; do
    if [[ "$(basename "$config_file")" != "$TARGET_FILENAME" ]]; then
        warn "Found conflicting config: $(basename "$config_file"). Disabling it..."
        mv "$config_file" "${config_file}.$(date +%Y%m%d_%H%M%S).bak"
    fi
done < <(find /etc/netplan -maxdepth 1 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)

clear

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

echo -e "  ${CYAN}You have two options for applying the new network configuration:${RESET}"
echo ""
echo -e "  ${BOLD}Option 1 — netplan try (recommended):${RESET}"
echo -e "  ${CYAN}  Applies the config temporarily for 120 seconds. If something goes"
echo -e "  wrong and you lose connectivity, the settings automatically revert"
echo -e "  to what they were before — keeping you from locking yourself out.${RESET}"
echo ""
echo -e "  ${BOLD}Option 2 — netplan apply (immediate):${RESET}"
echo -e "  ${CYAN}  Applies the config permanently right away with no safety window."
echo -e "  Only choose this if you are confident the settings are correct,"
echo -e "  or if you have physical access to the machine in case it goes wrong.${RESET}"
echo ""

if ask_yes_no "$(echo -e "${BOLD}Use 'netplan try' for safety?${RESET}")" "yes/no"; then
    echo ""
    info "Running 'netplan try' — the config will be applied for 120 seconds..."
    echo -e "  ${CYAN}If everything looks good and your connection holds, press Enter"
    echo -e "  when prompted to make the change permanent.${RESET}"
    echo -e "  ${CYAN}If you lose connectivity, do nothing — the old config will restore"
    echo -e "  itself automatically after the timeout.${RESET}"
    echo ""
    netplan try
else
    echo ""
    info "Applying configuration immediately with 'netplan apply'..."
    echo -e "  ${CYAN}The new settings are now being written to the system.${RESET}"
    echo ""
    netplan apply
fi

CURRENT_USER="${SUDO_USER:-$(whoami)}"

echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
warn "  Network config applied. If your SSH session dropped,"
warn "  reconnect using: ssh ${CURRENT_USER}@${STATIC_IP}"
warn "  Your new static IP is permanently set to: ${STATIC_IP}/${PREFIX}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 6 — SSH Welcome Message
# ════════════════════════════════════════════════════════════
header "💬  Step 6 — SSH Welcome Message"

echo -e "  ${CYAN}When you connect via SSH, Ubuntu displays a welcome message (MOTD)"
echo -e "  containing system info, news, and promotional messages from Canonical."
echo -e "  On a server you manage yourself, this is often just noise — disabling"
echo -e "  it gives you a cleaner login experience.${RESET}"
echo ""

if ask_yes_no "$(echo -e "${BOLD}Disable SSH welcome message?${RESET}")" "yes/no"; then
    PAM_SSHD="/etc/pam.d/sshd"
    if [[ -f "$PAM_SSHD" ]]; then
        info "Backing up $PAM_SSHD before making changes..."
        cp "$PAM_SSHD" "${PAM_SSHD}.$(date +%Y%m%d_%H%M%S).bak"
        echo -e "  ${CYAN}The original file has been saved with a timestamped .bak extension"
        echo -e "  in case you need to restore it later.${RESET}"
        sed -i 's/^session\s\+optional\s\+pam_motd.so/#&/' "$PAM_SSHD"
        info "Restarting SSH service to apply changes..."
        systemctl restart ssh
        success "SSH welcome message disabled. You will no longer see the MOTD on login."
    else
        warn "Could not find $PAM_SSHD — skipping this step."
    fi
else
    info "Skipping — SSH welcome message will remain unchanged."
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 7 — Timezone & Updates
# ════════════════════════════════════════════════════════════
header "🔄  Step 7 — Timezone & Updates"

# --- TIMEZONE ---
echo -e "  ${CYAN}An incorrect timezone affects log timestamps, scheduled tasks (cron),"
echo -e "  SSL certificate validation, and anything time-sensitive on your server.${RESET}"
echo ""

info "Checking system timezone..."
CURRENT_TZ=$(timedatectl show --property=Timezone --value)
echo -e "  Current Timezone: ${BOLD}${CURRENT_TZ:-Not Set}${RESET}"
echo ""

if ask_yes_no "$(echo -e "${BOLD}Change system timezone?${RESET}")" "yes/no"; then
    while true; do
        echo ""
        echo -e "  ${CYAN}Select your timezone. If your region is not listed, use option 6"
        echo -e "  to search by city or country.${RESET}"
        echo ""
        echo "  1) America/New_York    (Eastern)"
        echo "  2) America/Chicago     (Central)"
        echo "  3) America/Denver      (Mountain)"
        echo "  4) America/Los_Angeles (Pacific)"
        echo "  5) UTC                 (Universal — recommended for servers)"
        echo "  6) Search by city or country"
        echo "  7) Skip / Keep current (${CURRENT_TZ})"
        echo ""
        read -rp "$(echo -e "${BOLD}Select an option [1-7]: ${RESET}")" TZ_CHOICE
        case $TZ_CHOICE in
            1) SELECTED_TZ="America/New_York"; break ;;
            2) SELECTED_TZ="America/Chicago"; break ;;
            3) SELECTED_TZ="America/Denver"; break ;;
            4) SELECTED_TZ="America/Los_Angeles"; break ;;
            5) SELECTED_TZ="UTC"; break ;;
            6)
                echo ""
                echo -e "  ${CYAN}Enter any part of a city or country name (e.g. 'london', 'paris', 'australia')."
                echo -e "  Leave blank and press Enter to browse the full list and select by number.${RESET}"
                read -rp "  Search keyword (or press Enter to list all): " SEARCH_TERM
                readarray -t MAPFILE_T < <(timedatectl list-timezones | grep -i "$SEARCH_TERM" || true)
                if [[ ${#MAPFILE_T[@]} -eq 0 ]]; then
                    warn "No timezones matched '${SEARCH_TERM}'. Try a different keyword."
                elif [[ ${#MAPFILE_T[@]} -eq 1 ]]; then
                    SELECTED_TZ="${MAPFILE_T[0]}"
                    info "One match found: ${SELECTED_TZ}"
                    break
                else
                    echo ""
                    echo -e "  ${CYAN}Multiple matches found — select one:${RESET}"
                    for i in "${!MAPFILE_T[@]}"; do echo "  $((i+1))) ${MAPFILE_T[$i]}"; done
                    echo ""
                    read -rp "  Select a number: " TZ_NUM
                    if [[ "$TZ_NUM" =~ ^[0-9]+$ ]] && \
                       [ "$TZ_NUM" -ge 1 ] && \
                       [ "$TZ_NUM" -le "${#MAPFILE_T[@]}" ]; then
                        SELECTED_TZ="${MAPFILE_T[$((TZ_NUM-1))]}"; break
                    else
                        warn "Invalid selection. Please enter a number between 1 and ${#MAPFILE_T[@]}."
                    fi
                fi ;;
            7) SELECTED_TZ=$CURRENT_TZ; break ;;
            *) warn "Invalid choice — please enter a number between 1 and 7." ;;
        esac
    done
    clear
    timedatectl set-timezone "$SELECTED_TZ"
    success "Timezone set to ${SELECTED_TZ}."
fi

# --- AUTOMATIC UPDATES ---
echo ""
echo -e "  ${CYAN}Automatic updates keep your system patched against security vulnerabilities"
echo -e "  without requiring you to log in and run updates manually. This is strongly"
echo -e "  recommended for any internet-facing server.${RESET}"
echo ""

if ask_yes_no "$(echo -e "${BOLD}Enable automatic updates?${RESET}")" "yes/no"; then
    info "Installing unattended-upgrades package..."
    echo -e "  ${CYAN}This package handles downloading and applying security updates automatically"
    echo -e "  in the background, typically during off-peak hours.${RESET}"
    echo ""
    apt-get install -y unattended-upgrades > /dev/null 2>&1 || true
    UNATTENDED_CONFIG="/etc/apt/apt.conf.d/20auto-upgrades"
    cat > "$UNATTENDED_CONFIG" <<'AUTOCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
AUTOCONF
    success "Automatic updates enabled."

    # --- AUTO-REBOOT ---
    echo ""
    echo -e "  ${CYAN}Some updates (such as kernel patches) require a reboot to take effect."
    echo -e "  You can allow the system to reboot automatically at a scheduled time"
    echo -e "  so patches are fully applied without manual intervention.${RESET}"
    echo ""
    if ask_yes_no "$(echo -e "${BOLD}Configure automatic reboots after updates?${RESET}")" "yes/no"; then
        UPGRADES_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
        if [[ -f "$UPGRADES_CONF" ]]; then
            info "Backing up ${UPGRADES_CONF} before making changes..."
            cp "$UPGRADES_CONF" "${UPGRADES_CONF}.$(date +%Y%m%d_%H%M%S).bak"

            while true; do
                echo ""
                echo -e "  ${CYAN}Choose how you would like to enter the reboot time:${RESET}"
                echo ""
                echo "  1) 24-hour format (e.g. 04:00, 16:30)"
                echo "  2) 12-hour format (e.g. 4:00 AM, 2:30 PM)"
                echo ""
                read -rp "$(echo -e "${BOLD}Select format [1-2]: ${RESET}")" TIME_FORMAT

                if [[ "$TIME_FORMAT" == "2" ]]; then
                    echo -e "  ${CYAN}Enter the time in 12-hour format, including AM or PM (e.g. 2:00 AM, 2AM).${RESET}"
                    read -rp "  Enter time: " RAW_TIME
                    REBOOT_TIME=$(date -d "$RAW_TIME" +"%H:%M" 2>/dev/null || echo "INVALID")
                    if ! [[ "$RAW_TIME" =~ ^(1[0-2]|0?[1-9])(:[0-5][0-9])?[[:space:]]*(AM|PM|am|pm)$ ]]; then
                        REBOOT_TIME="INVALID"
                    else
                        REBOOT_TIME=$(date -d "$RAW_TIME" +"%H:%M" 2>/dev/null || echo "INVALID")
                    fi
                elif [[ "$TIME_FORMAT" == "1" ]]; then
                    echo -e "  ${CYAN}Enter the time in 24-hour format (e.g. 04:00 for 4 AM, 16:30 for 4:30 PM)."
                    echo -e "  Choose a time when the server is least likely to be in active use.${RESET}"
                    read -rp "  Enter time [04:00]: " REBOOT_TIME
                    REBOOT_TIME="${REBOOT_TIME:-04:00}"
                    if ! [[ "$REBOOT_TIME" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                        REBOOT_TIME="INVALID"
                    fi
                else
                    warn "Invalid choice — please enter 1 or 2."
                    continue
                fi

                if [[ "$REBOOT_TIME" == "INVALID" ]]; then
                    error "Could not parse that time — please try again."
                    continue
                fi

                break
            done

            sed -i '/Unattended-Upgrade::Automatic-Reboot/d' "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot \"true\";" >> "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot-Time \"${REBOOT_TIME}\";" >> "$UPGRADES_CONF"
            FRIENDLY_CONFIRM=$(date -d "$REBOOT_TIME" +"%I:%M %p")
            success "Auto-reboot scheduled daily at ${REBOOT_TIME} (${FRIENDLY_CONFIRM}) if updates require it."
        else
            warn "Could not find ${UPGRADES_CONF} — skipping auto-reboot configuration."
        fi
    else
        info "Skipping auto-reboot — you will need to reboot manually after kernel updates."
    fi

    # --- DRY RUN ---
    echo ""
    info "Running a dry-run to verify the unattended-upgrades configuration..."
    echo -e "  ${CYAN}This simulates an update run without actually installing anything."
    echo ""
    unattended-upgrade --dry-run --debug > /dev/null 2>&1
    DRY_RUN_EXIT="${PIPESTATUS[0]}"
    echo ""
    if [[ $? -eq 0 ]]; then
        success "Verification complete — automatic updates are configured and working."
    else
        warn "Dry-run exited with an error — automatic updates may not be configured correctly."
        info "You can investigate by running: sudo unattended-upgrade --dry-run --debug"
    fi
else
    info "Skipping automatic updates — you can enable this later by running:"
    echo -e "  ${BOLD}sudo apt-get install unattended-upgrades${RESET}"
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  Finish
# ════════════════════════════════════════════════════════════
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
