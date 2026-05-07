#!/bin/bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# ============================================================
#  Auto_Setup_Ubuntu_Server.sh — Initial server setup (v7)
# ============================================================
set -euo pipefail

SCRIPT_VERSION="5.1"

# ══ Colors ───────────────────────────────────────────────────
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
WHITE=$(printf '\033[0;37m')
MAGENTA=$(printf '\033[0;35m')
BOLD=$(printf '\033[1m')
BOLD_RED=$(printf '\033[1;31m')
BOLD_GREEN=$(printf '\033[1;32m')
BOLD_YELLOW=$(printf '\033[1;33m')
BOLD_CYAN=$(printf '\033[1;36m')
BOLD_WHITE=$(printf '\033[1;37m')
RESET=$(printf '\033[0m')

# ── Non-interactive terminal fallback — strip all colors ─────
if [[ ! -t 1 ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; WHITE=''
    MAGENTA=''; BOLD=''; BOLD_RED=''; BOLD_GREEN=''
    BOLD_YELLOW=''; BOLD_CYAN=''; BOLD_WHITE=''; RESET=''
fi

# ══ UI helper functions ───────────────────────────────────────
ok()   { printf "  ${BOLD_GREEN}✅${RESET}  %s\n" "$1"; }
info() { printf "  ${BOLD_CYAN}ℹ️${RESET}   %s\n" "$1"; }
warn() { printf "  ${BOLD_YELLOW}⚠️${RESET}   %s\n" "$1"; }
err()  { printf "  ${BOLD_RED}❌${RESET}  %s\n" "$1" >&2; }

header() {
    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  %s${RESET}\n" "$1"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n\n"
}

# ── ask_yes_no — $1=prompt, $2=hint (optional) ───────────────
ask_yes_no() {
    local hint="${2:-y/n}"
    while true; do
        read -rp "  ${BOLD_WHITE}$1 [${hint}]:${RESET} " input
        case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     err "Please type y or n (or yes/no)." ;;
        esac
    done
}

# ── pause_and_clear ───────────────────────────────────────────
pause_and_clear() {
    printf "\n${BOLD_GREEN}┌──────────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_GREEN}│${RESET}  ✔  ${BOLD_WHITE}STAGE COMPLETE!${RESET}                              ${BOLD_GREEN}│${RESET}\n"
    printf "${BOLD_GREEN}│${RESET}  ${MAGENTA}Press any key to move to the next step...${RESET}       ${BOLD_GREEN}│${RESET}\n"
    printf "${BOLD_GREEN}└──────────────────────────────────────────────────┘${RESET}\n"
    [[ -t 0 ]] && read -n 1 -s -r || true
    [[ -t 0 ]] && clear
}

# ══ Validators ───────────────────────────────────────────────

# ── Validate IPv4 format ──────────────────────────────────────
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

# ══ IP Detection Helpers ─────────────────────────────────────

# ── Detect RFC-1918 private addresses ────────────────────────
_is_private_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]]                              && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]     && return 0
    [[ "$ip" =~ ^192\.168\. ]]                         && return 0
    return 1
}

# ── Bare-metal: detect IP via local routing table ─────────────
_detect_ip_baremetal() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    ip="${ip:-$(hostname -I | awk '{print $1}')}"
    echo "$ip"
}

# ── VPS: resolve public IP via external lookup ────────────────
_detect_ip_vps() {
    local _public_ip=""
    for _svc in \
        "https://api.ipify.org" \
        "https://ifconfig.me/ip" \
        "https://icanhazip.com"; do
        _public_ip=$(curl -s --max-time 3 "$_svc" 2>/dev/null | tr -d '[:space:]') || true
        if [[ "$_public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$_public_ip"
            return
        fi
    done
    # Fallback — could not reach any lookup service
    local _fallback
    _fallback=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    echo "${_fallback:-$(hostname -I | awk '{print $1}')}"
}

# Resolved after the bare-metal / VPS question below
SERVER_IP=""
SERVER_TYPE=""   # "baremetal" or "vps"

# ══ Pre-flight checks ─────────────────────────────────────────

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then

    err "This script must be run as root (use sudo)."
    exit 1
fi

# ── Ubuntu version check — minimum 18.04, tested on 26.04 LTS
check_ubuntu_version() {
    if ! command -v lsb_release &>/dev/null; then
        err "lsb_release not found. This script requires Ubuntu 18.04 LTS or later."
        exit 1
    fi
    local distro
    distro=$(lsb_release -si)
    if [[ "$distro" != "Ubuntu" ]]; then
        err "This script is designed for Ubuntu only. Detected: $distro"
        exit 1
    fi
    local version major minor tested_major tested_minor
    version=$(lsb_release -sr)
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    tested_major=26
    tested_minor=04

    # ── Below minimum — hard stop ─────────────────────────────
    if [[ "$major" -lt 18 ]]; then
        err "Ubuntu 18.04 or later is required. Detected: Ubuntu $version"
        err "This script cannot run on your version. Exiting."
        exit 1
    fi

    # ── Below tested version — warn and prompt ────────────────
    if [[ "$major" -lt "$tested_major" ]] || \
       { [[ "$major" -eq "$tested_major" ]] && [[ "$minor" -lt "$tested_minor" ]]; }; then
        printf "\n"
        warn "This script has only been tested on Ubuntu ${tested_major}.${tested_minor}."
        printf "  ${MAGENTA}You are running Ubuntu %s.\n" "$version"
        printf "  Continuing may produce unexpected results.${RESET}\n\n"
        if ! ask_yes_no "Do you want to continue at your own risk?" "yes/no"; then
            err "Aborting."
            exit 1
        fi
        ok "Ubuntu $version detected — continuing at user's risk."
    else
        ok "Ubuntu $version detected — compatible."
    fi
}
check_ubuntu_version

# ── TTY check (required for netplan try) ─────────────────────
if [[ ! -t 0 ]]; then
    err "This script must be run from an interactive terminal (TTY required)."
    exit 1
fi

# ── Detect the real (non-root) user running the script ───────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
REAL_USER="${REAL_USER:-${USER:-root}}"

if [[ "$REAL_USER" == "root" ]]; then
    warn "Could not detect a non-root user (SUDO_USER is unset)."
    printf "  ${MAGENTA}Any SSH key operations will target ${BOLD_WHITE}/root/.ssh${RESET}\n"
    printf "  ${MAGENTA}If that is not what you want, re-run with: ${BOLD_WHITE}sudo -u youruser bash script.sh${RESET}\n\n"
fi

clear

# ════════════════════════════════════════════════════════════
#  Server Environment — Bare Metal or VPS?
# ════════════════════════════════════════════════════════════
printf "${BOLD_CYAN}📦  Auto Setup Ubuntu Server Script v${SCRIPT_VERSION}${RESET}\n"
header "🖥️   What type of server is this?"
printf "  ${MAGENTA}This determines how your server's IP address is detected\n"
printf "  and which setup steps apply to your environment.${RESET}\n\n"
printf "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Bare Metal${RESET}\n"
printf "  ${MAGENTA}       Physical server or VM with a directly assigned IP.${RESET}\n\n"
printf "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}VPS / Cloud${RESET}\n"
printf "  ${MAGENTA}       Hosted on Vultr, DigitalOcean, Linode, AWS, Hetzner, etc.${RESET}\n"
printf "  ${MAGENTA}       (NAT or private network — public IP fetched externally.)${RESET}\n\n"

while true; do
    read -rp "  ${BOLD_WHITE}Enter your choice${RESET} [${BOLD_WHITE}1/2${RESET}]: " _env_choice
    case "$_env_choice" in
        1)
            SERVER_TYPE="baremetal"
            info "Bare metal selected — using local route for IP detection."
            SERVER_IP=$(_detect_ip_baremetal)
            ok "Detected IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"
            break
            ;;
        2)
            SERVER_TYPE="vps"
            info "VPS selected — resolving public IP via external lookup..."
            SERVER_IP=$(_detect_ip_vps)
            if _is_private_ip "$SERVER_IP"; then
                warn "Could not resolve a public IP — showing private address: ${BOLD_WHITE}${SERVER_IP}${RESET}"
                warn "Check your actual public IP later with: ${BOLD_YELLOW}curl https://api.ipify.org${RESET}"
            else
                ok "Resolved public IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"
            fi
            break
            ;;
        *)
            err "Please enter 1 or 2."
            ;;
    esac
done
unset _env_choice

clear
printf "${BOLD_CYAN}📦  Auto Setup Ubuntu Server Script v${SCRIPT_VERSION}${RESET}\n"
printf "\n"
info "Server type: ${BOLD_WHITE}${SERVER_TYPE}${RESET}  |  IP: ${BOLD_WHITE}${SERVER_IP}${RESET}  |  User: ${BOLD_WHITE}${REAL_USER}${RESET}"
printf "\n"

# ════════════════════════════════════════════════════════════
#  STEP 1 — System Update
# ════════════════════════════════════════════════════════════
header "🖥️  Step 1 — System Update"

info "Checking for updates..."
if apt-get update > /dev/null 2>&1; then
    ok "Package lists refreshed."
else
    err "Failed to fetch package lists — check your internet connection."
    exit 1
fi

info "Installing updates — this may take a few minutes..."
printf "  ${MAGENTA}(Running in the background, please wait)${RESET}\n\n"

FAILED_PKGS=()
while IFS= read -r line; do
    if [[ "$line" =~ ^Get: ]]; then
        pkg=$(echo "$line" | awk '{print $NF}')
        printf "  ${BOLD_CYAN}↓ Downloading:${RESET} ${WHITE}%s${RESET}\n" "$pkg"
    elif [[ "$line" =~ ^Unpacking|^Setting\ up ]]; then
        pkg=$(echo "$line" | awk '{print $2}')
        printf "  ${BOLD_GREEN}✔ Installing:${RESET}  ${WHITE}%s${RESET}\n" "$pkg"
    elif [[ "$line" =~ ^[Ee]rr:|^[Ee]rror ]]; then
        FAILED_PKGS+=("$line")
        printf "  ${BOLD_RED}✘ Error:${RESET}       ${WHITE}%s${RESET}\n" "$line"
    fi
done < <(apt-get upgrade -y 2>&1)

printf "\n"
if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
    warn "${#FAILED_PKGS[@]} package(s) had errors during upgrade:"
    for pkg in "${FAILED_PKGS[@]}"; do
        printf "  ${RED}•${RESET} ${WHITE}%s${RESET}\n" "$pkg"
    done
    warn "The system may be partially updated — review the errors above before continuing."
    printf "\n"
    if ! ask_yes_no "${BOLD_YELLOW}Continue anyway?${RESET}" "yes/no"; then
        err "Aborted by user."
        exit 1
    fi
else
    ok "System is up to date."
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 1.5 — Root Account & User Setup
#  Only runs when executed directly as root (not via sudo)
# ════════════════════════════════════════════════════════════
NEW_USER_CREATED=""

if [[ -z "${SUDO_USER:-}" ]]; then
    header "🔐  Step 1.5 — Root Account & User Setup"

    printf "  ${WHITE}You are currently logged in as the ${BOLD_WHITE}root${RESET}${WHITE} user.\n"
    printf "  This section will help you secure the root account and optionally\n"
    printf "  create a regular user account — the recommended way to manage a\n"
    printf "  Linux server day-to-day.${RESET}\n\n"

    # ── Root password ─────────────────────────────────────────
    printf "  ${BOLD_YELLOW}ℹ️  Why you might need to change the root password:${RESET}\n"
    printf "  ${MAGENTA}If this server was provisioned automatically — for example by a\n"
    printf "  VPS or cloud provider — a root password may have been generated for\n"
    printf "  you that you never set yourself. It is good practice to replace it\n"
    printf "  with a strong password that only you know.${RESET}\n\n"

    if ask_yes_no "Would you like to change the root password?" "yes/no"; then
        printf "\n"
        info "You will be prompted to enter a new password for root."
        printf "  ${MAGENTA}Choose a strong password — at least 12 characters, mixing\n"
        printf "  letters, numbers, and symbols.${RESET}\n\n"
        passwd root
        ok "Root password updated."
    else
        info "Skipping root password change."
    fi

    printf "\n"

    # ── Create a new user account ─────────────────────────────
    printf "  ${BOLD_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"
    printf "  ${BOLD_YELLOW}💡 Best practice — why you should use a regular user account:${RESET}\n\n"
    printf "  ${WHITE}Running as root all the time is risky. The root user has no safety\n"
    printf "  net — a single typo or rogue command can delete critical system files,\n"
    printf "  and any software you run inherits that same unrestricted power.\n\n"
    printf "  The standard approach on Linux servers is to create a normal user\n"
    printf "  account for everyday work, and only use elevated privileges when\n"
    printf "  specifically needed (via sudo). This limits the blast radius of\n"
    printf "  mistakes and makes your server easier to audit.${RESET}\n\n"

    if ask_yes_no "Would you like to create a new user account?" "yes/no"; then
        printf "\n"

        while true; do
            read -rp "  ${BOLD_WHITE}Enter the username for the new account:${RESET} " NEW_USERNAME
            if [[ -z "$NEW_USERNAME" ]]; then
                warn "Username cannot be blank. Please try again."
            elif id "$NEW_USERNAME" &>/dev/null; then
                warn "A user named '${NEW_USERNAME}' already exists. Please choose a different name."
            elif [[ ! "$NEW_USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
                warn "Invalid username. Use only lowercase letters, numbers, hyphens, or underscores."
                warn "Username must start with a letter or underscore and be 32 characters or fewer."
            else
                break
            fi
        done

        printf "\n"
        info "Creating user account: ${BOLD_WHITE}${NEW_USERNAME}${RESET}"
        useradd -m -s /bin/bash "$NEW_USERNAME"
        printf "\n"
        info "Set a password for ${BOLD_WHITE}${NEW_USERNAME}${RESET}:"
        printf "  ${MAGENTA}This is the password the account will use to log in.${RESET}\n\n"
        passwd "$NEW_USERNAME"
        NEW_USER_CREATED="$NEW_USERNAME"
        ok "User '${NEW_USERNAME}' created successfully."
        printf "\n"

        # ── Add to sudo ───────────────────────────────────────
        printf "  ${BOLD_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"
        printf "  ${BOLD_YELLOW}💡 About sudo / administrative privileges:${RESET}\n\n"
        printf "  ${WHITE}Adding a user to the 'sudo' group lets them run commands as root\n"
        printf "  by prefixing them with 'sudo' — for example: ${BOLD_WHITE}sudo apt-get update${RESET}${WHITE}.\n"
        printf "  They will be asked for their own password to confirm each time.\n\n"
        printf "  ${BOLD_WHITE}Why add them to sudo?${RESET}\n"
        printf "  ${MAGENTA}  → They can manage the server, install software, and change system\n"
        printf "    settings without needing to log in as root directly.\n"
        printf "  → Every privileged action is logged with their username.\n"
        printf "  → It is the recommended setup for any admin user on Ubuntu.${RESET}\n\n"
        printf "  ${BOLD_WHITE}Why not add them to sudo?${RESET}\n"
        printf "  ${MAGENTA}  → If this account is for a limited-access or untrusted user who\n"
        printf "    should not be able to make system-level changes, leave sudo off.\n"
        printf "  → You can always add them later with: ${BOLD_WHITE}usermod -aG sudo %s${RESET}\n\n" "$NEW_USERNAME"

        if ask_yes_no "Add '${NEW_USERNAME}' to sudo (administrative privileges)?" "yes/no"; then
            usermod -aG sudo "$NEW_USERNAME"
            ok "'${NEW_USERNAME}' has been added to the sudo group."
        else
            info "Skipping sudo — '${NEW_USERNAME}' will be a standard user without admin privileges."
        fi

    else
        info "Skipping user creation."
    fi

    # ── Switch-user reminder ──────────────────────────────────
    if [[ -n "$NEW_USER_CREATED" ]]; then
        printf "\n"
        printf "  ${BOLD_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
        printf "  ${BOLD_GREEN}  👤  New user ready!${RESET}\n"
        printf "  ${BOLD_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"
        printf "  ${WHITE}When you are finished with this setup script, you can switch to\n"
        printf "  your new account with the following command:${RESET}\n\n"
        printf "    ${BOLD_YELLOW}su - %s${RESET}\n\n" "$NEW_USER_CREATED"
        printf "  ${WHITE}Or if you are connecting over SSH next time, log in directly as:${RESET}\n\n"
        printf "    ${BOLD_YELLOW}ssh %s@<your-server-ip>${RESET}\n\n" "$NEW_USER_CREATED"
    fi

    pause_and_clear
fi

# ════════════════════════════════════════════════════════════
#  STEP 2 — Detect Network Info
# ════════════════════════════════════════════════════════════
header "🌐  Step 2 — Detect Network Info"

info "Scanning your system for active network interfaces..."
printf "\n  ${WHITE}The following interfaces were found (loopback excluded):${RESET}\n\n"
ip -4 -br addr show | grep -v "^lo" | while read -r line; do
    iface=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    addr=$(echo "$line"  | awk '{print $3}')
    printf "  ${BOLD_CYAN}%-12s${RESET}  ${MAGENTA}%-8s${RESET}  ${WHITE}%s${RESET}\n" \
        "$iface" "$state" "${addr:-<no IP assigned>}"
done

printf "\n"
info "Determining your current default route and primary interface..."

DETECTED_GW=$(ip r    | awk '/^default via/ {print $3; exit}')
DETECTED_IFACE=$(ip -4 -br addr | awk '$1 != "lo" && $3 != "" {print $1; exit}')
DETECTED_IP=$(ip -4 -br addr | awk -v iface="$DETECTED_IFACE" \
    '$1 == iface {print $3; exit}' | cut -d/ -f1)

printf "\n"
printf "  ${MAGENTA}These values will be used as defaults in the next step.\n"
printf "  You can accept them by pressing Enter or type your own value.${RESET}\n\n"
printf "  ${BOLD_CYAN}Default Gateway   :${RESET}  ${WHITE}%s${RESET}\n" "${DETECTED_GW:-<none detected>}"
printf "  ${BOLD_CYAN}Primary Interface :${RESET}  ${WHITE}%s${RESET}\n" "${DETECTED_IFACE:-<none detected>}"
printf "  ${BOLD_CYAN}Current IP        :${RESET}  ${WHITE}%s${RESET}\n" "${DETECTED_IP:-<none detected>}"
printf "\n"

# ════════════════════════════════════════════════════════════
#  STEP 3 — Configure Static IP
# ════════════════════════════════════════════════════════════
header "⚙️   Step 3 — Configure Static IP"

printf "  ${WHITE}A static IP ensures this machine always has the same address on\n"
printf "  the network — useful for servers, remote access, and port forwarding.${RESET}\n\n"

# ── VPS-aware warning ─────────────────────────────────────────
if [[ "$SERVER_TYPE" == "vps" ]]; then
    printf "  ${BOLD_RED}⚠️  VPS DETECTED — We strongly recommend skipping this step.${RESET}\n"
    printf "  ${MAGENTA}Your IP is managed by the provider at the hypervisor level.\n"
    printf "  Configuring a static IP here can overwrite your provider's network\n"
    printf "  settings, drop your SSH connection, and lock you out of the server.\n\n"
    printf "  Manage your IP through your provider's control panel instead.${RESET}\n\n"

else
    
    printf "  ${BOLD_YELLOW}⚠️  Physical / bare-metal server? We strongly recommend setting a static IP.${RESET}\n"
    printf "  ${MAGENTA}Without one, your server's address can change every time it reboots\n"
    printf "  or reconnects to the network. This breaks SSH connections, any services\n"
    printf "  pointed at a fixed address, and makes your server harder to manage\n"
    printf "  reliably over time.${RESET}\n\n"
fi

# ── Ask if they want to set a static IP ──────────────────────
SKIP_STATIC_IP=false
if ! ask_yes_no "Would you like to configure a static IP address?" "yes/no"; then
    printf "\n"
    warn "Skipping static IP configuration."
    printf "  ${MAGENTA}Your server will continue using DHCP. If your router assigns a\n"
    printf "  different IP after a reboot, you will need to find the new address\n"
    printf "  before you can reconnect. You can run this script again at any time\n"
    printf "  to configure a static IP.${RESET}\n\n"
    SKIP_STATIC_IP=true
fi

if [[ "$SKIP_STATIC_IP" == false ]]; then

    printf "  ${MAGENTA}Press Enter on any field to accept the detected default value.${RESET}\n\n"

    read -rp "  ${BOLD_WHITE}Network interface [${DETECTED_IFACE}]:${RESET} " INPUT_IFACE
    IFACE="${INPUT_IFACE:-$DETECTED_IFACE}"

    printf "\n  ${WHITE}Enter the IP address you want to permanently assign to ${BOLD_WHITE}%s${RESET}${WHITE}.\n" "$IFACE"
    printf "  Make sure this address is not already in use on your network.${RESET}\n\n"

    while true; do
        read -rp "  ${BOLD_WHITE}Static IP to assign (no prefix) [${DETECTED_IP}]:${RESET} " INPUT_STATIC
        STATIC_IP="${INPUT_STATIC:-$DETECTED_IP}"
        if validate_ip "$STATIC_IP"; then break
        else warn "Invalid IP address: '${STATIC_IP}'. Please enter a valid IPv4 address (e.g. 192.168.1.100)."; fi
    done

    printf "\n  ${WHITE}The prefix length (also called a subnet mask) controls how many\n"
    printf "  devices can exist on your local network segment.${RESET}\n\n"

    printf "  ${BOLD_WHITE}How to choose:${RESET}\n"
    printf "  ${MAGENTA}  → Not sure? Use ${BOLD_WHITE}/24${MAGENTA} — it is correct for the vast majority of\n"
    printf "    home labs, small offices, and self-hosted servers.\n"
    printf "  → Match whatever your router or network is already using.\n"
    printf "    If your gateway is 192.168.1.1 and your current IP is\n"
    printf "    192.168.1.x, your prefix is almost certainly /24.${RESET}\n\n"

    printf "  ${BOLD_CYAN}Prefix  Subnet Mask       Hosts    Common use${RESET}\n"
    printf "  ${WHITE}/24     255.255.255.0     254      Home, small office, VMs, homelabs${RESET}\n"
    printf "  ${WHITE}/16     255.255.0.0       65,534   Mid-size businesses, data centers${RESET}\n"
    printf "  ${WHITE}/8      255.0.0.0         16M+     ISPs, very large enterprise networks${RESET}\n\n"

    printf "  ${BOLD_YELLOW}⚠️  If you pick the wrong prefix:${RESET}\n"
    printf "  ${MAGENTA}Your server may not be able to reach your gateway or other devices\n"
    printf "  on your network, even if the IP address itself looks correct.${RESET}\n\n"

    while true; do
        read -rp "  ${BOLD_WHITE}Prefix length [24]:${RESET} " INPUT_PREFIX
        PREFIX="${INPUT_PREFIX:-24}"
        if validate_prefix "$PREFIX"; then break
        else warn "Invalid prefix: '${PREFIX}'. Please enter a number between 1 and 32 (e.g. 24)."; fi
    done

    printf "\n  ${WHITE}The gateway is your router's IP address — all traffic destined\n"
    printf "  outside your local network will be sent through it.${RESET}\n\n"

    while true; do
        read -rp "  ${BOLD_WHITE}Gateway IP [${DETECTED_GW}]:${RESET} " INPUT_GW
        GATEWAY="${INPUT_GW:-$DETECTED_GW}"
        if validate_ip "$GATEWAY"; then break
        else warn "Invalid gateway address: '${GATEWAY}'. Please enter a valid IPv4 address (e.g. 192.168.1.1)."; fi
    done

    printf "\n"
    info "DNS Configuration"
    printf "  ${WHITE}DNS servers translate domain names (e.g. google.com) into IP addresses.\n"
    printf "  Two servers are configured for redundancy — if the primary is unreachable,\n"
    printf "  your system automatically falls back to the secondary.${RESET}\n\n"
    printf "  ${MAGENTA}Common options:\n"
    printf "    1.1.1.1,  1.0.0.1         (Cloudflare — fast, privacy-focused)\n"
    printf "    8.8.8.8,  8.8.4.4         (Google — reliable, widely used)\n"
    printf "    9.9.9.9,  149.112.112.112  (Quad9 — security & malware filtering)${RESET}\n\n"

    while true; do
        read -rp "  ${BOLD_WHITE}Primary DNS [1.1.1.1]:${RESET} " INPUT_DNS1
        DNS1="${INPUT_DNS1:-1.1.1.1}"
        if validate_ip "$DNS1"; then break
        else warn "Invalid DNS address: '${DNS1}'. Please enter a valid IPv4 address."; fi
    done

    while true; do
        read -rp "  ${BOLD_WHITE}Secondary DNS [1.0.0.1]:${RESET} " INPUT_DNS2
        DNS2="${INPUT_DNS2:-1.0.0.1}"
        if validate_ip "$DNS2"; then break
        else warn "Invalid DNS address: '${DNS2}'. Please enter a valid IPv4 address."; fi
    done

    printf "\n"
    info "Configuration Summary:"
    printf "  ${MAGENTA}Please review your settings carefully before continuing.\n"
    printf "  Applying an incorrect IP or gateway can disconnect this machine from the network.${RESET}\n\n"
    printf "  ${BOLD_CYAN}Interface :${RESET}  ${WHITE}%s${RESET}\n"          "$IFACE"
    printf "  ${BOLD_CYAN}Static IP :${RESET}  ${BOLD_YELLOW}%s/%s${RESET}\n" "$STATIC_IP" "$PREFIX"
    printf "  ${BOLD_CYAN}Gateway   :${RESET}  ${WHITE}%s${RESET}\n"          "$GATEWAY"
    printf "  ${BOLD_CYAN}DNS       :${RESET}  ${WHITE}%s, %s${RESET}\n"      "$DNS1" "$DNS2"
    printf "\n"

    if ! ask_yes_no "${BOLD_YELLOW}Proceed with these settings?${RESET}" "yes/no"; then
        warn "Aborted by user. No changes have been made to your system."
        exit 0
    fi

    # ── Disable conflicting Netplan configs ───────────────────
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
    #  STEP 4 — Write Netplan Config
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
    ok "Netplan config written."

    # ════════════════════════════════════════════════════════════
    #  STEP 5 — Apply Netplan Config
    # ════════════════════════════════════════════════════════════
    header "🚀  Step 5 — Apply Netplan Config"

    printf "  ${WHITE}You have two options for applying the new network configuration:${RESET}\n\n"

    printf "  ${GREEN}[1]${RESET}  ${BOLD_WHITE}netplan try${RESET}  ${MAGENTA}(recommended)${RESET}\n"
    printf "  ${MAGENTA}      Applies the config temporarily for 120 seconds. If something goes\n"
    printf "      wrong and you lose connectivity, the settings automatically revert\n"
    printf "      to what they were before — keeping you from locking yourself out.${RESET}\n\n"

    printf "  ${YELLOW}[2]${RESET}  ${BOLD_WHITE}netplan apply${RESET}  ${MAGENTA}(immediate, permanent)${RESET}\n"
    printf "  ${MAGENTA}      Applies the config permanently right away with no safety window.\n"
    printf "      Only choose this if you are confident the settings are correct,\n"
    printf "      or if you have physical access to the machine in case it goes wrong.${RESET}\n\n"

    if ask_yes_no "Use 'netplan try' for safety?" "yes/no"; then
        printf "\n"
        info "Running 'netplan try' — the config will be applied for 120 seconds..."
        printf "  ${MAGENTA}If everything looks good and your connection holds, press Enter\n"
        printf "  when prompted to make the change permanent.\n"
        printf "  If you lose connectivity, do nothing — the old config will restore\n"
        printf "  itself automatically after the timeout.${RESET}\n\n"
        netplan try
    else
        printf "\n"
        info "Applying configuration immediately with 'netplan apply'..."
        printf "  ${MAGENTA}The new settings are now being written to the system.${RESET}\n\n"
        netplan apply
    fi

    CURRENT_USER="${SUDO_USER:-$(whoami)}"

    printf "\n${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    warn "Network config applied. If your SSH session dropped,"
    warn "reconnect using: ${BOLD_WHITE}ssh ${CURRENT_USER}@${STATIC_IP}${RESET}"
    warn "Your new static IP is permanently set to: ${BOLD_WHITE}${STATIC_IP}/${PREFIX}${RESET}"
    printf "${BOLD_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

    pause_and_clear

fi  # end SKIP_STATIC_IP block

# ════════════════════════════════════════════════════════════
#  STEP 6 — SSH Welcome Message
# ════════════════════════════════════════════════════════════
header "💬  Step 6 — SSH Welcome Message"

printf "  ${WHITE}When you connect via SSH, Ubuntu displays a welcome message (MOTD)\n"
printf "  containing system info, news, and promotional messages from Canonical.\n"
printf "  On a server you manage yourself, this is often just noise — disabling\n"
printf "  it gives you a cleaner login experience.${RESET}\n\n"

if ask_yes_no "Disable SSH welcome message?" "yes/no"; then
    PAM_SSHD="/etc/pam.d/sshd"
    if [[ -f "$PAM_SSHD" ]]; then
        info "Backing up ${PAM_SSHD} before making changes..."
        cp "$PAM_SSHD" "${PAM_SSHD}.$(date +%Y%m%d_%H%M%S).bak"
        printf "  ${MAGENTA}The original file has been saved with a timestamped .bak extension\n"
        printf "  in case you need to restore it later.${RESET}\n"
        sed -i 's/^session\s\+optional\s\+pam_motd.so/#&/' "$PAM_SSHD"
        info "Restarting SSH service to apply changes..."
        systemctl restart ssh
        ok "SSH welcome message disabled. You will no longer see the MOTD on login."
    else
        warn "Could not find ${PAM_SSHD} — skipping this step."
    fi
else
    info "Skipping — SSH welcome message will remain unchanged."
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  STEP 7 — Timezone & Automatic Updates
# ════════════════════════════════════════════════════════════
header "🔄  Step 7 — Timezone & Updates"

# ── Timezone ─────────────────────────────────────────────────
printf "  ${WHITE}An incorrect timezone affects log timestamps, scheduled tasks (cron),\n"
printf "  SSL certificate validation, and anything time-sensitive on your server.${RESET}\n\n"

info "Checking system timezone..."
CURRENT_TZ=$(timedatectl show --property=Timezone --value)
printf "  ${BOLD_CYAN}Current Timezone:${RESET}  ${BOLD_YELLOW}%s${RESET}\n\n" "${CURRENT_TZ:-Not Set}"

if ask_yes_no "Change system timezone?" "yes/no"; then
    while true; do
        printf "\n  ${WHITE}Select your timezone. If your region is not listed, use option 6\n"
        printf "  to search by city or country.${RESET}\n\n"

        printf "  ${GREEN}[1]${RESET}  ${BOLD_WHITE}America/New_York${RESET}     ${MAGENTA}(Eastern)${RESET}\n"
        printf "  ${CYAN}[2]${RESET}  ${BOLD_WHITE}America/Chicago${RESET}      ${MAGENTA}(Central)${RESET}\n"
        printf "  ${CYAN}[3]${RESET}  ${BOLD_WHITE}America/Denver${RESET}       ${MAGENTA}(Mountain)${RESET}\n"
        printf "  ${CYAN}[4]${RESET}  ${BOLD_WHITE}America/Los_Angeles${RESET}  ${MAGENTA}(Pacific)${RESET}\n"
        printf "  ${CYAN}[5]${RESET}  ${BOLD_WHITE}UTC${RESET}                  ${MAGENTA}(Universal — recommended for servers)${RESET}\n"
        printf "  ${YELLOW}[6]${RESET}  ${BOLD_WHITE}Search by city or country${RESET}\n"
        printf "  ${RED}[7]${RESET}  ${BOLD_WHITE}Skip / Keep current${RESET}  ${MAGENTA}(${CURRENT_TZ})${RESET}\n\n"

        read -rp "  ${BOLD_WHITE}Select an option [1-7]:${RESET} " TZ_CHOICE
        case $TZ_CHOICE in
            1) SELECTED_TZ="America/New_York";    break ;;
            2) SELECTED_TZ="America/Chicago";     break ;;
            3) SELECTED_TZ="America/Denver";      break ;;
            4) SELECTED_TZ="America/Los_Angeles"; break ;;
            5) SELECTED_TZ="UTC";                 break ;;
            6)
                printf "\n  ${MAGENTA}Enter any part of a city or country name (e.g. 'london', 'paris', 'australia').\n"
                printf "  Leave blank and press Enter to browse the full list and select by number.${RESET}\n"
                read -rp "  ${BOLD_WHITE}Search keyword (or press Enter to list all):${RESET} " SEARCH_TERM
                readarray -t MAPFILE_T < <(timedatectl list-timezones | grep -i "$SEARCH_TERM" || true)
                if [[ ${#MAPFILE_T[@]} -eq 0 ]]; then
                    warn "No timezones matched '${SEARCH_TERM}'. Try a different keyword."
                elif [[ ${#MAPFILE_T[@]} -eq 1 ]]; then
                    SELECTED_TZ="${MAPFILE_T[0]}"
                    info "One match found: ${BOLD_YELLOW}${SELECTED_TZ}${RESET}"
                    break
                else
                    printf "\n  ${MAGENTA}Multiple matches found — select one:${RESET}\n\n"
                    for i in "${!MAPFILE_T[@]}"; do
                        printf "  ${CYAN}[%d]${RESET}  ${WHITE}%s${RESET}\n" "$((i+1))" "${MAPFILE_T[$i]}"
                    done
                    printf "\n"
                    read -rp "  ${BOLD_WHITE}Select a number:${RESET} " TZ_NUM
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
    ok "Timezone set to ${BOLD_YELLOW}${SELECTED_TZ}${RESET}."
fi

# ── Automatic updates ─────────────────────────────────────────
printf "\n  ${WHITE}Automatic updates keep your system patched against security vulnerabilities\n"
printf "  without requiring you to log in and run updates manually. This is strongly\n"
printf "  recommended for any internet-facing server.${RESET}\n\n"

if ask_yes_no "Enable automatic updates?" "yes/no"; then
    info "Installing unattended-upgrades package..."
    printf "  ${MAGENTA}This package handles downloading and applying security updates automatically\n"
    printf "  in the background, typically during off-peak hours.${RESET}\n\n"
    apt-get install -y unattended-upgrades > /dev/null 2>&1 || true
    UNATTENDED_CONFIG="/etc/apt/apt.conf.d/20auto-upgrades"
    cat > "$UNATTENDED_CONFIG" <<'AUTOCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
AUTOCONF
    ok "Automatic updates enabled."

    # ── Package upgrades (optional) ──────────────────────────
    printf "\n  ${WHITE}By default, only security patches are applied automatically.\n"
    printf "  You can also enable automatic upgrades for all packages\n"
    printf "  (bug fixes, feature updates, etc.).${RESET}\n\n"

    printf "  ${BOLD_WHITE}Why you may NOT want this:${RESET}\n"
    printf "  ${MAGENTA}  → Package updates can change software behavior unexpectedly.\n"
    printf "  → A routine update could break a service or app you depend on.\n"
    printf "  → It is harder to track what changed when something breaks.${RESET}\n\n"

    printf "  ${BOLD_WHITE}Why you may want this:${RESET}\n"
    printf "  ${MAGENTA}  → Keeps all software current without manual intervention.\n"
    printf "  → Good for low-maintenance personal servers where stability\n"
    printf "    is less critical than staying up to date.${RESET}\n\n"

    if ask_yes_no "Also enable automatic upgrades for all packages?" "yes/no"; then
        sed -i 's|//\s*"\${distro_id}:\${distro_codename}-updates";|"\${distro_id}:\${distro_codename}-updates";|' \
            /etc/apt/apt.conf.d/50unattended-upgrades
        ok "Automatic package upgrades enabled."
    else
        info "Keeping default — only security patches will be applied automatically."
    fi

    # ── Auto-reboot ───────────────────────────────────────────
    printf "\n  ${WHITE}Some updates (such as kernel patches) require a reboot to take effect.\n"
    printf "  You can allow the system to reboot automatically at a scheduled time\n"
    printf "  so patches are fully applied without manual intervention.${RESET}\n\n"

    if ask_yes_no "Configure automatic reboots after updates?" "yes/no"; then
        UPGRADES_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
        if [[ -f "$UPGRADES_CONF" ]]; then
            info "Backing up ${UPGRADES_CONF} before making changes..."
            cp "$UPGRADES_CONF" "${UPGRADES_CONF}.$(date +%Y%m%d_%H%M%S).bak"

            while true; do
                printf "\n  ${WHITE}Choose how you would like to enter the reboot time:${RESET}\n\n"
                printf "  ${GREEN}[1]${RESET}  ${BOLD_WHITE}24-hour format${RESET}  ${MAGENTA}(e.g. 04:00, 16:30)${RESET}\n"
                printf "  ${CYAN}[2]${RESET}  ${BOLD_WHITE}12-hour format${RESET}  ${MAGENTA}(e.g. 4:00 AM, 2:30 PM)${RESET}\n\n"
                read -rp "  ${BOLD_WHITE}Select format [1-2]:${RESET} " TIME_FORMAT

                if [[ "$TIME_FORMAT" == "2" ]]; then
                    printf "  ${MAGENTA}Enter the time in 12-hour format, including AM or PM (e.g. 2:00 AM, 2AM).${RESET}\n"
                    read -rp "  ${BOLD_WHITE}Enter time:${RESET} " RAW_TIME
                    if ! [[ "$RAW_TIME" =~ ^(1[0-2]|0?[1-9])(:[0-5][0-9])?[[:space:]]*(AM|PM|am|pm)$ ]]; then
                        REBOOT_TIME="INVALID"
                    else
                        REBOOT_TIME=$(date -d "$RAW_TIME" +"%H:%M" 2>/dev/null || echo "INVALID")
                    fi
                elif [[ "$TIME_FORMAT" == "1" ]]; then
                    printf "  ${MAGENTA}Enter the time in 24-hour format (e.g. 04:00 for 4 AM, 16:30 for 4:30 PM).\n"
                    printf "  Choose a time when the server is least likely to be in active use.${RESET}\n"
                    read -rp "  ${BOLD_WHITE}Enter time [04:00]:${RESET} " REBOOT_TIME
                    REBOOT_TIME="${REBOOT_TIME:-04:00}"
                    if ! [[ "$REBOOT_TIME" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                        REBOOT_TIME="INVALID"
                    fi
                else
                    warn "Invalid choice — please enter 1 or 2."
                    continue
                fi

                if [[ "$REBOOT_TIME" == "INVALID" ]]; then
                    err "Could not parse that time — please try again."
                    continue
                fi

                break
            done

            sed -i '/Unattended-Upgrade::Automatic-Reboot/d' "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot \"true\";"             >> "$UPGRADES_CONF"
            echo "Unattended-Upgrade::Automatic-Reboot-Time \"${REBOOT_TIME}\";" >> "$UPGRADES_CONF"
            FRIENDLY_CONFIRM=$(date -d "$REBOOT_TIME" +"%I:%M %p")
            ok "Auto-reboot scheduled daily at ${BOLD_YELLOW}${REBOOT_TIME}${RESET} (${FRIENDLY_CONFIRM}) if updates require it."
        else
            warn "Could not find ${UPGRADES_CONF} — skipping auto-reboot configuration."
        fi
    else
        info "Skipping auto-reboot — you will need to reboot manually after kernel updates."
    fi

    # ── Dry run ───────────────────────────────────────────────
    printf "\n"
    info "Running a dry-run to verify the unattended-upgrades configuration..."
    printf "  ${MAGENTA}This simulates an update run without actually installing anything.${RESET}\n\n"
    unattended-upgrade --dry-run --debug > /dev/null 2>&1 || true
    printf "\n"
    if unattended-upgrade --dry-run --debug > /dev/null 2>&1; then
        ok "Verification complete — automatic updates are configured and working."
    else
        warn "Dry-run exited with an error — automatic updates may not be configured correctly."
        info "You can investigate by running: ${BOLD_WHITE}sudo unattended-upgrade --dry-run --debug${RESET}"
    fi
else
    info "Skipping automatic updates — you can enable this later by running:"
    printf "  ${BOLD_WHITE}sudo apt-get install unattended-upgrades${RESET}\n"
fi

pause_and_clear

# ════════════════════════════════════════════════════════════
#  Finish
# ════════════════════════════════════════════════════════════
CURRENT_USER="${REAL_USER:-${SUDO_USER:-$(whoami)}}"
CURRENT_HOSTNAME=$(hostname)

# ── Build the SSH connection IP based on priority:
#    1. Static IP (if configured this session)
#    2. SERVER_IP (public IP for VPS, local route for bare-metal)
#    3. Fallback placeholder
if [[ "$SKIP_STATIC_IP" == false ]]; then
    CONNECT_IP="$STATIC_IP"
else
    CONNECT_IP="${SERVER_IP:-${DETECTED_IP:-<your-server-ip>}}"
fi

printf "\n${BOLD_GREEN}════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_GREEN}  ✅  Server setup complete! 🎉${RESET}\n"
printf "${BOLD_GREEN}════════════════════════════════════════════════════════${RESET}\n\n"
printf "${BOLD_CYAN}  🔌  How to connect via SSH:${RESET}\n\n"
printf "  ${BOLD_WHITE}By IP address:${RESET}\n"
printf "    ${BOLD_YELLOW}ssh %s@%s${RESET}\n\n" "$CURRENT_USER" "$CONNECT_IP"
printf "  ${BOLD_WHITE}By hostname:${RESET}\n"
printf "    ${BOLD_YELLOW}ssh %s@%s${RESET}\n\n" "$CURRENT_USER" "$CURRENT_HOSTNAME"
printf "${BOLD_GREEN}════════════════════════════════════════════════════════${RESET}\n\n"
