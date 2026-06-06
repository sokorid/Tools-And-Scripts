#!/bin/bash
# ════════════════════════════════════════════════════════════
# Author:  sokor | github.com/sokorid | codeberg.org/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ════════════════════════════════════════════════════════════
#  SSH_Hardening_Script.sh — The Automatic Setup Script
# ════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_VERSION="5.1"

# ── Colors ───────────────────────────────────────────────────
RED=$(printf '\033[0;31m')    GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m') CYAN=$(printf '\033[0;36m')
WHITE=$(printf '\033[0;37m')  MAGENTA=$(printf '\033[0;35m')
BOLD_RED=$(printf '\033[1;31m')
BOLD_GREEN=$(printf '\033[1;32m')  BOLD_YELLOW=$(printf '\033[1;33m')
BOLD_CYAN=$(printf '\033[1;36m')   BOLD_WHITE=$(printf '\033[1;37m')
RESET=$(printf '\033[0m')

if [[ ! -t 1 ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; WHITE=''; MAGENTA=''
    BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''
    BOLD_CYAN=''; BOLD_WHITE=''; RESET=''
fi

# ── UI helpers ───────────────────────────────────────────────
ok()      { printf "  ${BOLD_GREEN}✅${RESET} %s\n" "$1"; }
info()    { printf "  ${BOLD_CYAN}ℹ️${RESET}  %s\n" "$1"; }
warn()    { printf "  ${BOLD_YELLOW}⚠️${RESET}  %s\n" "$1"; }
err()     { printf "  ${BOLD_RED}❌${RESET}  %s\n" "$1" >&2; }
error()   { err "$1"; }
success() { ok "$1"; }

header() {
    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  %s${RESET}\n" "$1"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
}

# ── Bordered boxes — title + body lines ──────────────────────
# warn_box COLOR "Title" "line" ...  (used for warn=yellow, danger=red)
_box() {
    local c="$1" title="$2"; shift 2
    printf "${c}  ┌─ %s ─────────────────────────────────────────────┐${RESET}\n" "$title"
    printf "${c}  │${RESET}\n"
    for line in "$@"; do
        printf "${c}  │${RESET}  ${MAGENTA}%s${RESET}\n" "$line"
    done
    printf "${c}  │${RESET}\n"
    printf "${c}  └───────────────────────────────────────────────────────────┘${RESET}\n"
}
warn_box()   { _box "$BOLD_YELLOW" "⚠️  $1" "${@:2}"; }
danger_box() { _box "$BOLD_RED"    "❌  $1" "${@:2}"; }

ask_yes_no() {
    local hint="${2:-y/n}" input
    while true; do
        read -rp "  ${BOLD_WHITE}$1${RESET} [${BOLD_WHITE}${hint}${RESET}]: " input
        case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
            y|yes) return 0 ;; n|no) return 1 ;;
            *) err "Please type y or n (or yes/no)." ;;
        esac
    done
}

pause_and_clear() {
    echo -e "\n${BOLD_GREEN}┌──────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD_GREEN}│${RESET}  ✔  ${BOLD_WHITE}STAGE COMPLETE!${RESET}                              ${BOLD_GREEN}│${RESET}"
    echo -e "${BOLD_GREEN}│${RESET}  ${CYAN}Press any key to move to the next step...${RESET}       ${BOLD_GREEN}│${RESET}"
    echo -e "${BOLD_GREEN}└──────────────────────────────────────────────────┘${RESET}"
    [[ -t 0 && -t 1 ]] && read -n 1 -s -r || true
    [[ -t 0 && -t 1 ]] && clear
}

# ── Time converters ──────────────────────────────────────────
convert_to_seconds() {
    local input=$1 unit value
    unit=$(echo "$input"  | grep -o -E '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')
    value=$(echo "$input" | grep -o -E '[0-9]+')
    [[ -z "$value" ]] && echo "-1" && return
    case "$unit" in
        yr|year|years)   echo $((value * 31536000)) ;;
        mo|month|months) echo $((value * 2592000))  ;;
        d|day|days)      echo $((value * 86400))    ;;
        h|hour|hours)    echo $((value * 3600))     ;;
        m|min|minutes)   echo $((value * 60))       ;;
        s|sec|seconds|"") echo "$value"             ;;
        *) echo "-1" ;;
    esac
}

# Fail2Ban uses its own time format (e.g. 1h, 7d) — not raw seconds.
convert_to_fail2ban_time() {
    local input=$1 unit value
    unit=$(echo "$input"  | grep -o -E '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')
    value=$(echo "$input" | grep -o -E '[0-9]+')
    [[ -z "$value" ]] && echo "" && return
    case "$unit" in
        yr|year|years)   echo "${value}y"  ;;
        mo|month|months) echo "${value}mo" ;;
        d|day|days)      echo "${value}d"  ;;
        h|hour|hours)    echo "${value}h"  ;;
        m|min|minutes)   echo "${value}m"  ;;
        s|sec|seconds|"") echo "${value}s" ;;
        *) echo "" ;;
    esac
}

# Handles commented-out defaults like "#Port 22"
# Value is escaped before sed substitution to prevent pipe/metachar injection.
set_ssh_option() {
    local key="$1" val="$2"
    local escaped_val
    escaped_val=$(printf '%s' "$val" | sed 's/[&/\]/\\&/g')
    if grep -qE "^#?${key}[[:space:]]" /etc/ssh/sshd_config; then
        sed -i -E "s|^#?(${key})\s+.*|${key} ${escaped_val}|" /etc/ssh/sshd_config
    else
        echo "${key} ${val}" >> /etc/ssh/sshd_config
    fi
}

# ── SSH service control (handles socket activation on modern Ubuntu) ─
SSH_SERVICE="ssh"
SSH_SOCKET=""
if systemctl list-unit-files --type=socket 2>/dev/null | grep -qE '^sshd?\.socket'; then
    SSH_SOCKET=$(systemctl list-unit-files --type=socket 2>/dev/null \
        | grep -oE '^sshd?\.socket' | head -1)
fi

ssh_stop()    {
    [[ -n "$SSH_SOCKET" ]] && systemctl stop "$SSH_SOCKET" > /dev/null 2>&1 || true
    systemctl stop "$SSH_SERVICE" > /dev/null 2>&1 || true
}
ssh_start()   {
    systemctl start "$SSH_SERVICE" || { err "Failed to start SSH!"; exit 1; }
    [[ -n "$SSH_SOCKET" ]] && systemctl start "$SSH_SOCKET" > /dev/null 2>&1 || true
}
ssh_restart() { ssh_stop; sleep 1; ssh_start; }

# ── Stealth mode (ICMP drop via UFW) ────────────────────────
DO_STEALTH="no"
set_icmp_stealth() {
    local f="/etc/ufw/before.rules"
    grep -q "icmp-type echo-request -j DROP" "$f" \
        && { ok "Stealth mode already configured."; return; }
    info "Configuring UFW to drop ICMP echo requests..."
    sed -i '/--icmp-type echo-request -j ACCEPT/i -A ufw-before-input -p icmp --icmp-type echo-request -j DROP' "$f"
    ok "Stealth Mode queued: server will no longer respond to pings after firewall reload."
}

# ══════════════════════════════════════════════════════════════
#  PRE-FLIGHT
# ══════════════════════════════════════════════════════════════

[[ $EUID -ne 0 ]] && { err "Please run this script with sudo."; exit 1; }

# Ubuntu version check — min 18.04, tested on 26.04
check_ubuntu_version() {
    command -v lsb_release &>/dev/null \
        || { error "lsb_release not found. Ubuntu 18.04+ required."; exit 1; }
    local distro version major minor tested_major tested_minor
    tested_major=26
    tested_minor=04
    distro=$(lsb_release -si)
    [[ "$distro" != "Ubuntu" ]] \
        && { error "Ubuntu only. Detected: $distro"; exit 1; }
    version=$(lsb_release -sr)
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    [[ "$major" -lt 18 ]] \
        && { error "Ubuntu 18.04+ required. Detected: $version"; exit 1; }
    if [[ "$major" -lt "$tested_major" ]] || \
       { [[ "$major" -eq "$tested_major" ]] && [[ "$minor" -lt "$tested_minor" ]]; }; then
        echo ""
        warn_box "Untested Ubuntu Version" \
            "Tested on Ubuntu 26.04. You are on Ubuntu ${version}." \
            "Continuing may produce unexpected results."
        echo ""
        ask_yes_no "Continue at your own risk?" "yes/no" \
            || { error "Aborting."; exit 1; }
        success "Ubuntu $version — continuing at user's risk."
    else
        success "Ubuntu $version — compatible."
    fi
}
check_ubuntu_version

if ! command -v ufw &>/dev/null; then
    echo ""
    warn_box "UFW Not Installed" \
        "UFW is not installed. Many VPS images ship without it." \
        "This script requires UFW to manage firewall rules."
    echo ""
    if ask_yes_no "Install UFW now and continue?" "yes/no"; then
        info "Installing UFW..."
        apt-get update -qq && apt-get install -y ufw -qq > /dev/null 2>&1 \
            && ok "UFW installed." \
            || { err "UFW install failed. Try: apt-get install ufw"; exit 1; }
    else
        err "UFW is required. Exiting."; exit 1
    fi
fi

# ── Identity detection ───────────────────────────────────────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
REAL_USER="${REAL_USER:-${USER:-root}}"

if [[ "$REAL_USER" == "root" ]]; then
    echo ""
    warn_box "Running as Root" \
        "Could not detect a non-root user (SUDO_USER is unset)." \
        "Your SSH key will be added to /root/.ssh/authorized_keys." \
        "To use a different user: sudo -u youruser bash script.sh"
    echo ""
    ask_yes_no "Continue installing for root?" "yes/no" \
        || { err "Aborting."; exit 1; }
fi

SERVER_IP=""; SERVER_TYPE=""

# Returns 0 if IP is RFC-1918 private
_is_private_ip() {
    [[ "$1" =~ ^10\. || "$1" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. || "$1" =~ ^192\.168\. ]]
}

_detect_ip_baremetal() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    echo "${ip:-$(hostname -I | awk '{print $1}')}"
}

_detect_ip_vps() {
    local ip _svc
    for _svc in "https://api.ipify.org" "https://ifconfig.me/ip" "https://icanhazip.com"; do
        ip=$(curl -s --fail --proto '=https' --max-time 3 "$_svc" 2>/dev/null | tr -d '[:space:]') || true
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "$ip"; return; }
    done
    # Fallback to local route
    ip=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    echo "${ip:-$(hostname -I | awk '{print $1}')}"
}

# ── Snapshot SSH state for rollback ─────────────────────────
_get_ssh_val() {
    grep -E "^$1\s" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1 || true
}
ORIG_PUBKEY_AUTH=$(_get_ssh_val "PubkeyAuthentication")
ORIG_PASS_AUTH=$(_get_ssh_val "PasswordAuthentication")
ORIG_ROOT_LOGIN=$(_get_ssh_val "PermitRootLogin")
ORIG_PORT=$(_get_ssh_val "Port")
ORIG_PORT="${ORIG_PORT:-22}"

# ── Defaults ─────────────────────────────────────────────────
F2B_MAXRETRY=5; F2B_BANTIME=1h; F2B_FINDTIME=10m
F2B_RECIDIVE="no"; F2B_RECIDIVE_COUNT=3; F2B_RECIDIVE_FINDTIME=""
DO_FAIL2BAN="no"
BACKUP_PATH=""
CLIENT_OS=""    # set in Stage 1: "windows" or "maclinux"
KEY_FILENAME="" # set in Stage 1: e.g. id_ed25519 or this-PC

# ══════════════════════════════════════════════════════════════
#  WELCOME
# ══════════════════════════════════════════════════════════════
clear
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_WHITE}  📦  SSH Hardening Script  ${BOLD_YELLOW}v${SCRIPT_VERSION}${RESET}\n"
printf "${BOLD_CYAN}  Secure your server in 9 guided steps${RESET}\n"
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n\n"
printf "  ${MAGENTA}What this script does:${RESET}\n"
printf "  ${BOLD_CYAN}1.${RESET}  ${MAGENTA}Installs your SSH public key${RESET}\n"
printf "  ${BOLD_CYAN}2.${RESET}  ${MAGENTA}Changes your SSH port to a custom one${RESET}\n"
printf "  ${BOLD_CYAN}3.${RESET}  ${MAGENTA}Hardens SSH login settings${RESET}\n"
printf "  ${BOLD_CYAN}4.${RESET}  ${MAGENTA}Optionally installs Fail2Ban (brute-force protection)${RESET}\n"
printf "  ${BOLD_CYAN}5.${RESET}  ${MAGENTA}Optionally enables Stealth Mode (disables ping responses)${RESET}\n"
printf "  ${BOLD_CYAN}6.${RESET}  ${MAGENTA}Applies everything + lets you verify before committing${RESET}\n\n"
printf "  ${BOLD_YELLOW}⚠️${RESET}  ${MAGENTA}If anything goes wrong, the script automatically rolls back${RESET}\n"
printf "      ${MAGENTA}all changes — you won't be locked out.${RESET}\n\n"

# ── Server type ──────────────────────────────────────────────
header "🖥️   What type of server is this?"
printf "  ${MAGENTA}This determines how your server's IP address is detected.${RESET}\n\n"
printf "  ${BOLD_GREEN}[1]${RESET} ${BOLD_WHITE}Bare Metal${RESET}\n"
printf "  ${MAGENTA}      Physical server or VM with a directly assigned public IP.${RESET}\n\n"
printf "  ${BOLD_CYAN}[2]${RESET} ${BOLD_WHITE}VPS / Cloud${RESET}\n"
printf "  ${MAGENTA}      Hosted on Vultr, DigitalOcean, Linode, AWS, Oracle, etc.${RESET}\n"
printf "  ${MAGENTA}      (NAT or private network — public IP fetched externally.)${RESET}\n\n"

while true; do
    read -rp "  ${BOLD_WHITE}Enter your choice${RESET} [${BOLD_WHITE}1/2${RESET}]: " _env_choice
    case "$_env_choice" in
        1) SERVER_TYPE="baremetal"
           info "Bare metal selected — using local route for IP detection."
           SERVER_IP=$(_detect_ip_baremetal)
           ok "Detected IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"; break ;;
        2) SERVER_TYPE="vps"
           info "VPS selected — resolving public IP via external lookup..."
           SERVER_IP=$(_detect_ip_vps)
           if _is_private_ip "$SERVER_IP"; then
               warn "Could not resolve public IP — showing private: ${BOLD_WHITE}${SERVER_IP}${RESET}"
               warn "Check your real IP later: ${BOLD_YELLOW}curl https://api.ipify.org${RESET}"
           else
               ok "Resolved public IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"
           fi; break ;;
        *) err "Please enter 1 or 2." ;;
    esac
done
unset _env_choice

# ── Context banner ───────────────────────────────────────────
clear
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_WHITE}  📦  SSH Hardening Script  ${BOLD_YELLOW}v${SCRIPT_VERSION}${RESET}\n"
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n\n"
info "Detected user: ${BOLD_WHITE}${REAL_USER}${RESET}  |  IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"

# ══════════════════════════════════════════════════════════════
#  STAGE 1 — Public Key
# ══════════════════════════════════════════════════════════════
header "🔑  Stage 1 — Your SSH Public Key"

printf "${BOLD_WHITE}  ┌─ Your Operating System ───────────────────────────────────┐${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Which computer are you connecting ${BOLD_WHITE}FROM${RESET}${MAGENTA}?${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This determines the instructions below and makes the${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}connection commands at the end copy-paste ready for you.${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${BOLD_WHITE}[1]${RESET}  ${CYAN}Windows${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${BOLD_WHITE}[2]${RESET}  ${CYAN}Mac / Linux${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}\n"
printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
while true; do
    read -rp "  ${BOLD_WHITE}Your OS [1/2]:${RESET} " _os_choice
    case "$_os_choice" in
        1) CLIENT_OS="windows";  ok "Windows selected.";   break ;;
        2) CLIENT_OS="maclinux"; ok "Mac/Linux selected."; break ;;
        *) err "Please enter 1 or 2." ;;
    esac
done
unset _os_choice
echo ""; [[ -t 0 && -t 1 ]] && clear

header "🔑  Stage 1 — Your SSH Public Key"
if [[ "$CLIENT_OS" == "windows" ]]; then
    printf "  ${MAGENTA}To find your key, run this in ${BOLD_WHITE}Command Prompt or PowerShell${RESET}${MAGENTA}:${RESET}\n"
    printf "  ${BOLD_CYAN}  type %%USERPROFILE%%\\.ssh\\id_ed25519.pub${RESET}\n\n"
    printf "  ${MAGENTA}If you need one: ${BOLD_YELLOW}ssh-keygen -t ed25519${RESET}${MAGENTA} in PowerShell.${RESET}\n"
else
    printf "  ${MAGENTA}To find your key, run this in ${BOLD_WHITE}Terminal${RESET}${MAGENTA}:${RESET}\n"
    printf "  ${BOLD_CYAN}  cat ~/.ssh/id_ed25519.pub${RESET}\n\n"
    printf "  ${MAGENTA}If you need one: ${BOLD_YELLOW}ssh-keygen -t ed25519${RESET}${MAGENTA} in your terminal.${RESET}\n"
fi
echo ""

while true; do
    read -rp "  ${BOLD_WHITE}Paste your Public Key here:${RESET} " PUBKEY
    [[ "$PUBKEY" =~ $'\n' ]] \
        && { err "Key contains newlines — paste a single-line key."; continue; }
    # Strip carriage returns and leading/trailing whitespace (common from Windows terminals)
    PUBKEY=$(printf '%s' "$PUBKEY" | tr -d '\r' | xargs)
    [[ ! "$PUBKEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]] \
        && { err "Invalid format. Key should start with 'ssh-ed25519' or similar."; continue; }
    TMPKEY=$(mktemp)
    trap 'rm -f "$TMPKEY"' EXIT
    echo "$PUBKEY" > "$TMPKEY"
    if ssh-keygen -l -f "$TMPKEY" &>/dev/null; then
        ok "Key accepted and cryptographically validated."
        rm -f "$TMPKEY"; trap - EXIT; break
    else
        rm -f "$TMPKEY"
        err "Key failed validation — it may be truncated. Please paste it again."
    fi
done

# Detect key type to suggest default filename
echo ""
case "$PUBKEY" in
    ssh-ed25519*) KEY_DEFAULT="id_ed25519" ;;
    ssh-rsa*)     KEY_DEFAULT="id_rsa"     ;;
    ssh-ecdsa*)   KEY_DEFAULT="id_ecdsa"   ;;
    *)            KEY_DEFAULT="id_ed25519" ;;
esac

printf "${BOLD_WHITE}  ┌─ Private Key Filename ────────────────────────────────────┐${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Your key type suggests the private key is named ${BOLD_WHITE}${KEY_DEFAULT}${RESET}${MAGENTA}.${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}If you used a custom name (e.g. ${BOLD_WHITE}this-PC${RESET}${MAGENTA}) type it below.${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Otherwise press ${BOLD_WHITE}Enter${RESET}${MAGENTA} to use the default.${RESET}\n"
printf "${BOLD_WHITE}  │${RESET}\n"
printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
read -rp "  ${BOLD_WHITE}Private key filename${RESET} [${BOLD_WHITE}${KEY_DEFAULT}${RESET}]: " KEY_FILENAME
KEY_FILENAME="${KEY_FILENAME:-$KEY_DEFAULT}"
# Strip any character that isn't alphanumeric, hyphen, underscore, or dot
KEY_FILENAME=$(printf '%s' "$KEY_FILENAME" | tr -cd 'A-Za-z0-9_.-')
# Fall back to default if sanitization emptied the value
[[ -z "$KEY_FILENAME" ]] && KEY_FILENAME="$KEY_DEFAULT"
# Strip .pub suffix if user entered the public key filename by mistake
KEY_FILENAME="${KEY_FILENAME%.pub}"
ok "Key filename set to ${BOLD_WHITE}${KEY_FILENAME}${RESET}"

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 2 — SSH Port
# ══════════════════════════════════════════════════════════════
header "🌐  Stage 2 — Choose Your SSH Port"
printf "  ${MAGENTA}SSH listens on a port — the door number bots knock on.${RESET}\n"
printf "  ${MAGENTA}The default port ${BOLD_WHITE}22${RESET}${MAGENTA} is known to every scanner on the internet.${RESET}\n"
printf "  ${MAGENTA}A high random port significantly reduces automated attack noise.${RESET}\n\n"
printf "  ${BOLD_CYAN}Port 22:${RESET}       ${WHITE}Standard default. Fine with other protections.${RESET}\n"
printf "  ${BOLD_CYAN}1024–65535:${RESET}    ${WHITE}Recommended range for a custom port.${RESET}\n"
printf "  ${BOLD_YELLOW}Avoid:${RESET}         ${WHITE}80 (HTTP), 443 (HTTPS), 3306 (MySQL), 5432 (Postgres), etc.${RESET}\n"
if [[ "$SERVER_TYPE" == "vps" ]]; then
    echo ""
    warn_box "VPS Firewall Note" \
        "After this script finishes, open your chosen port in your" \
        "VPS provider's control panel too — UFW alone is not enough." \
        "Most providers (Vultr, DigitalOcean, AWS, etc.) have a separate" \
        "network-level firewall independent of UFW."
fi
echo ""

while true; do
    read -rp "  ${BOLD_WHITE}Enter desired SSH Port${RESET} [${BOLD_WHITE}2552${RESET}]: " SSH_PORT
    SSH_PORT="${SSH_PORT:-2552}"
    [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]]  && { err "Port must be a number."; continue; }
    [[ "$SSH_PORT" -gt 65535 ]]       && { err "Port must be 65535 or below."; continue; }
    if [[ "$SSH_PORT" -eq 22 ]]; then
        warn "Port 22 is heavily scanned. Ensure Fail2Ban is enabled."
        printf "  ${MAGENTA}This works fine but bots will target it constantly.${RESET}\n"
        ask_yes_no "Continue with port 22?" "yes/no" || continue
        # Skip in-use check — SSH already runs on 22
        ok "Port ${BOLD_WHITE}22${RESET} confirmed."; break
    elif [[ "$SSH_PORT" -lt 1024 ]]; then
        warn "Port ${SSH_PORT} is reserved (below 1024) — may conflict with other services."
        ask_yes_no "Use port ${SSH_PORT} anyway?" "yes/no" || continue
    fi
    if ss -tulpn | grep -q ":$SSH_PORT "; then
        err "Port $SSH_PORT is ALREADY in use! Choose another."
    else
        ok "Port ${BOLD_WHITE}${SSH_PORT}${RESET} is available."; break
    fi
done

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 3 — SSH Hardening Settings
# ══════════════════════════════════════════════════════════════
header "⚙️   Stage 3 — SSH Hardening Settings"
printf "  ${BOLD_CYAN}High-Security Defaults include:${RESET}\n"
printf "  ${MAGENTA}  - Disable Passwords:  Force SSH Key login only. Keys cannot be guessed.${RESET}\n"
printf "  ${MAGENTA}  - Disable Root Login: Attackers cannot target the 'root' account directly.${RESET}\n"
printf "  ${MAGENTA}  - Idle Timeout:       Auto-disconnect sessions idle for more than 5 minutes.${RESET}\n"
printf "  ${MAGENTA}  - Max Tries:          Drop the connection after 3 failed login attempts.${RESET}\n\n"

if ask_yes_no "Apply these high-security defaults?" "yes/no"; then
    PUBKEY_AUTH=yes; PASS_AUTH=no; ROOT_LOGIN=no
    MAX_TRIES=3; GRACE_TIME=30; X11=no; SECONDS_VAL=300; ALIVE_COUNT=2
    ok "Defaults applied."
else
    printf "\n${BOLD_CYAN}Manual Configuration${RESET}\n"
    printf "  ${MAGENTA}You will be asked about each setting one at a time.${RESET}\n"
    printf "  ${MAGENTA}Read each description — type ${BOLD_WHITE}yes${RESET}${MAGENTA} or ${BOLD_WHITE}no${RESET}${MAGENTA} for each.${RESET}\n\n"

    # Helper: ask a yes/no setting with a box
    # Usage: _ask_setting "Box Title" "prompt" VAR_NAME "line1" "line2" ...
    # We'll inline each box since the lines differ per setting

    printf "${BOLD_WHITE}  ┌─ Public Key Authentication ───────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}SSH keys are cryptographic pairs — private key on your PC,${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}public key on the server. Login only works if both match.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Far stronger than any password — cannot be guessed.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: yes${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Enable Public Key Authentication?${RESET} (yes/no): " PUBKEY_AUTH
        case "$(echo "$PUBKEY_AUTH" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Password Authentication ─────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}When enabled, anyone can attempt to log in with a password.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Bots scan port 22 and try thousands of passwords constantly.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Disabling this stops that entirely.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}Warning: SSH keys become your ONLY way in if disabled.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}Make sure your key is working before you log out!${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no (disable passwords, use keys only)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow Password Authentication?${RESET} (yes/no): " PASS_AUTH
        case "$(echo "$PASS_AUTH" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Root Login ───────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}'root' exists on every Linux server — attackers target it first.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Disabling root login forces a normal account + sudo, adding${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}an extra layer — attacker must guess username AND key/password.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no (disable root login)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow Root Login?${RESET} (yes/no): " ROOT_LOGIN
        case "$(echo "$ROOT_LOGIN" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Max Auth Tries ───────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Limits login attempts per connection. After this many failures${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}the connection is forcibly dropped. 3 is enough for humans.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 3${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Max Auth Tries${RESET} [${BOLD_WHITE}3${RESET}]: " MAX_TRIES
    MAX_TRIES="${MAX_TRIES:-3}"
    [[ ! "$MAX_TRIES" =~ ^[0-9]+$ ]] || [[ "$MAX_TRIES" -lt 1 ]] && { warn "Invalid value — defaulting to 3."; MAX_TRIES=3; }
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Login Grace Time ─────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Time allowed to complete login after connecting. If not${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}finished in time, the connection is dropped.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}30s${RESET}${MAGENTA}  ${BOLD_WHITE}1m${RESET}${MAGENTA}  ${BOLD_WHITE}2m${RESET}${MAGENTA}  ${BOLD_WHITE}1h${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 30s${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Login Grace Time${RESET} [${BOLD_WHITE}30s${RESET}]: " GRACE_INPUT
        GRACE_INPUT="${GRACE_INPUT:-30s}"
        GRACE_TIME=$(convert_to_seconds "$GRACE_INPUT")
        if [[ "$GRACE_TIME" == "-1" || "$GRACE_TIME" -le 0 ]]; then
            warn "Invalid format. Try: 30s, 1m, 2m"
        else
            ok "Grace time set to ${BOLD_WHITE}${GRACE_TIME}${RESET} seconds."; break
        fi
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ X11 Forwarding ───────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Lets you run GUI apps over SSH. Most servers never need this.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Enabling it increases attack surface with no benefit.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Enable X11 Forwarding?${RESET} (yes/no): " X11
        case "$(echo "$X11" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Idle Timeout ─────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Idle sessions get keep-alive pings. If no response, the${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}session is disconnected. Closes forgotten open sessions.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}300s${RESET}${MAGENTA}  ${BOLD_WHITE}15m${RESET}${MAGENTA}  ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 300s (5 minutes)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Idle Timeout duration${RESET} [${BOLD_WHITE}300s${RESET}]: " TIME_INPUT
    TIME_INPUT="${TIME_INPUT:-300s}"
    SECONDS_VAL=$(convert_to_seconds "$TIME_INPUT")
    if [[ "$SECONDS_VAL" == "-1" || "$SECONDS_VAL" -le 0 ]]; then
        warn "Invalid format. Defaulting to 300 seconds."; SECONDS_VAL=300
    fi
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Keep-Alive Check Count ───────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How many unanswered pings before the session is closed.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Total idle time before disconnect = timeout × this count.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 2${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Alive Check Count${RESET} [${BOLD_WHITE}2${RESET}]: " ALIVE_COUNT
    ALIVE_COUNT="${ALIVE_COUNT:-2}"
    [[ ! "$ALIVE_COUNT" =~ ^[0-9]+$ ]] || [[ "$ALIVE_COUNT" -lt 1 ]] && { warn "Invalid value — defaulting to 2."; ALIVE_COUNT=2; }
    echo ""
    printf "  ${GREEN}Idle timeout:${RESET} ${BOLD_WHITE}${SECONDS_VAL}s${RESET} × ${BOLD_WHITE}${ALIVE_COUNT}${RESET} = ${BOLD_YELLOW}$((SECONDS_VAL * ALIVE_COUNT))s${RESET} ${MAGENTA}max before disconnect${RESET}\n"
fi

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 4 — Fail2Ban
# ══════════════════════════════════════════════════════════════
header "🛡️   Stage 4 — Fail2Ban Protection"
printf "  ${MAGENTA}Fail2Ban watches SSH logs and bans IPs that repeatedly fail to log in.${RESET}\n\n"
printf "  ${BOLD_CYAN}Max Retry (5):${RESET}   ${WHITE}Ban an IP after 5 failed login attempts.${RESET}\n"
printf "  ${MAGENTA}                 Lower = stricter. 3–5 is the sweet spot.${RESET}\n\n"
printf "  ${BOLD_CYAN}Ban Time (1h):${RESET}   ${WHITE}How long a banned IP stays blocked.${RESET}\n"
printf "  ${MAGENTA}                 Use longer values (24h, 7d) for persistent attackers.${RESET}\n\n"
printf "  ${BOLD_CYAN}Find Time (10m):${RESET} ${WHITE}Window failures must occur in to trigger a ban.${RESET}\n"
printf "  ${MAGENTA}                 5 failures in 2 hours won't ban; 5 in 10 min will.${RESET}\n\n"

if ask_yes_no "Install Fail2Ban with these defaults?" "yes/no"; then
    F2B_MAXRETRY=5; F2B_BANTIME=1h; F2B_FINDTIME=10m; DO_FAIL2BAN="yes"
    ok "Fail2Ban defaults selected."
else
    printf "\n  ${MAGENTA}Would you like to configure Fail2Ban with custom values instead?${RESET}\n"
    printf "  ${BOLD_YELLOW}Answering no skips Fail2Ban entirely.${RESET}\n\n"
    if ask_yes_no "Manually configure Fail2Ban?" "yes/no"; then

        printf "\n${BOLD_WHITE}  ┌─ Max Retry ────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Failed attempts allowed before an IP is banned.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Lower = stricter, but could lock out a typo-prone user.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 5${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        read -rp "  ${BOLD_WHITE}Max Retry${RESET} [${BOLD_WHITE}5${RESET}]: " F2B_MAXRETRY
        F2B_MAXRETRY="${F2B_MAXRETRY:-5}"
        echo ""; [[ -t 0 && -t 1 ]] && clear

        printf "${BOLD_WHITE}  ┌─ Ban Time ─────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How long a banned IP stays blocked. After this it's unbanned.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format: ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}24h${RESET}${MAGENTA}  ${BOLD_WHITE}7d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}${MAGENTA}  ${BOLD_WHITE}-1${RESET}${MAGENTA} (permanent)${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 1h${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Ban Time${RESET} [${BOLD_WHITE}1h${RESET}]: " _f2b_bantime_input
            _f2b_bantime_input="${_f2b_bantime_input:-1h}"
            if [[ "$_f2b_bantime_input" == "-1" ]]; then
                F2B_BANTIME="-1"; ok "Ban time: ${BOLD_WHITE}permanent${RESET}."; break
            fi
            F2B_BANTIME=$(convert_to_fail2ban_time "$_f2b_bantime_input")
            [[ -n "$F2B_BANTIME" ]] \
                && { ok "Ban time: ${BOLD_WHITE}${F2B_BANTIME}${RESET}."; break; } \
                || err "Invalid format. Try: 1h, 24h, 7d, 1mo, 1yr, or -1."
        done
        echo ""; [[ -t 0 && -t 1 ]] && clear

        printf "${BOLD_WHITE}  ┌─ Find Time ────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Rolling window failures must occur in to count toward a ban.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Failures outside this window are forgotten.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format: ${BOLD_WHITE}10m${RESET}${MAGENTA}  ${BOLD_WHITE}30m${RESET}${MAGENTA}  ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 10m${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Find Time${RESET} [${BOLD_WHITE}10m${RESET}]: " _f2b_findtime_input
            _f2b_findtime_input="${_f2b_findtime_input:-10m}"
            F2B_FINDTIME=$(convert_to_fail2ban_time "$_f2b_findtime_input")
            [[ -n "$F2B_FINDTIME" ]] \
                && { ok "Find time: ${BOLD_WHITE}${F2B_FINDTIME}${RESET}."; break; } \
                || err "Invalid format. Try: 10m, 30m, 1h, 1d, 1mo, 1yr."
        done
        echo ""; [[ -t 0 && -t 1 ]] && clear
        DO_FAIL2BAN="yes"
    else
        DO_FAIL2BAN="no"
        warn "Fail2Ban will NOT be installed."
        printf "  ${MAGENTA}Install later: ${BOLD_WHITE}apt-get install fail2ban${RESET}\n"
    fi
fi

# ── Recidive: permanent ban for repeat offenders ─────────────
if [[ "$DO_FAIL2BAN" == "yes" ]]; then
    echo ""
    printf "${BOLD_WHITE}  ┌─ Permanent Ban for Repeat Offenders ──────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Watches IPs that keep returning after bans. Once an IP${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}exceeds your threshold it gets a permanent ban — never${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}automatically unbanned. Best defence against persistent${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}attackers who simply wait out temporary bans.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: yes${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    if ask_yes_no "Enable permanent ban for repeat offenders?" "yes/no"; then
        F2B_RECIDIVE="yes"
        echo ""; [[ -t 0 && -t 1 ]] && clear

        printf "${BOLD_WHITE}  ┌─ Repeat Offender Threshold ────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How many bans before permanent block? E.g. threshold 3:${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}banned → unbanned → returns, banned → unbanned → returns,${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}banned twice, unbanned, tries again — third ban is permanent.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 3${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Ban threshold${RESET} [${BOLD_WHITE}3${RESET}]: " F2B_RECIDIVE_COUNT
            F2B_RECIDIVE_COUNT="${F2B_RECIDIVE_COUNT:-3}"
            [[ "$F2B_RECIDIVE_COUNT" =~ ^[0-9]+$ ]] && [[ "$F2B_RECIDIVE_COUNT" -ge 1 ]] \
                && { ok "IPs banned ${BOLD_WHITE}${F2B_RECIDIVE_COUNT}${RESET}+ times will be permanently blocked."; break; } \
                || err "Please enter a whole number of 1 or more."
        done
        echo ""; [[ -t 0 && -t 1 ]] && clear

        printf "${BOLD_WHITE}  ┌─ Repeat Offender Memory Window ───────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How far back to look when counting bans. Only bans within${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}this window count toward the permanent-ban threshold.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Example — threshold 3, window 1d:${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}  3 bans in 24h → permanent. 1 today + 1 last week → not yet.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Longer = stricter, but higher risk of permanent false positives.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format: ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}${MAGENTA}  ${BOLD_WHITE}7d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}${MAGENTA}   ${BOLD_GREEN}Recommendation: 1d${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Memory window${RESET} [${BOLD_WHITE}1d${RESET}]: " _recidive_window_input
            _recidive_window_input="${_recidive_window_input:-1d}"
            F2B_RECIDIVE_FINDTIME=$(convert_to_fail2ban_time "$_recidive_window_input")
            [[ -n "$F2B_RECIDIVE_FINDTIME" ]] \
                && { ok "Recidive window: ${BOLD_WHITE}${F2B_RECIDIVE_FINDTIME}${RESET}."; break; } \
                || err "Invalid format. Try: 1h, 1d, 7d, 1mo, 1yr."
        done
    else
        F2B_RECIDIVE="no"; info "Repeat-offender permanent ban disabled."
    fi
fi

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 5 — Stealth Mode
# ══════════════════════════════════════════════════════════════
header "👻  Stage 5 — Stealth Mode (ICMP Stealth)"
printf "  ${MAGENTA}By default, servers respond to 'ping'. Disabling this makes it${RESET}\n"
printf "  ${MAGENTA}harder for bots to discover your server during network scans.${RESET}\n"
printf "  ${BOLD_WHITE}Security Note:${RESET} ${MAGENTA}This does${RESET} ${BOLD_WHITE}not${RESET} ${MAGENTA}fully hide you — an open port still${RESET}\n"
printf "  ${MAGENTA}reveals your server. This is an${RESET} ${CYAN}added layer${RESET}${MAGENTA} of obscurity.${RESET}\n"
printf "  ${BOLD_YELLOW}Note:${RESET} You won't be able to ping this server to test uptime.\n\n"

if ask_yes_no "Disallow pinging of the server (Stealth Mode)?" "yes/no"; then
    DO_STEALTH="yes"; set_icmp_stealth
else
    info "Stealth Mode skipped. Server remains pingable."
fi

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 6 — Apply Configurations
# ══════════════════════════════════════════════════════════════
header "🚀  Stage 6 — Applying Configurations"

if [[ "$SERVER_TYPE" == "vps" ]] && [[ "$SSH_PORT" != "22" ]]; then
    echo ""
    danger_box "VPS Provider Firewall — Action Required" \
        "You changed your SSH port to ${SSH_PORT} on a VPS." \
        "" \
        "UFW alone is not enough. Your provider's cloud-level firewall" \
        "sits OUTSIDE this server and must also allow the port." \
        "" \
        "Open port ${SSH_PORT}/tcp in your provider's control panel NOW" \
        "or you WILL be locked out after this script runs." \
        "" \
        "  Vultr:         Network → Firewall Groups" \
        "  DigitalOcean:  Networking → Firewalls" \
        "  Linode:        Firewalls (Cloud Manager)" \
        "  AWS:           EC2 → Security Groups" \
        "  Oracle:        Networking → Security Lists / NSGs"
    echo ""
    if ! ask_yes_no "I have opened port ${SSH_PORT} in my provider's firewall. Continue?" "yes/no"; then
        warn "Pausing. Open the port, then re-run the script."; exit 0
    fi
fi

BACKUP_PATH="/etc/ssh/sshd_config.$(date +%Y%m%d%H%M%S).bak"
cp /etc/ssh/sshd_config "$BACKUP_PATH"
info "Config backed up to: ${BOLD_WHITE}${BACKUP_PATH}${RESET}"

info "Writing settings to ${BOLD_WHITE}/etc/ssh/sshd_config${RESET}..."
set_ssh_option "Port"                   "$SSH_PORT"
set_ssh_option "PubkeyAuthentication"   "$PUBKEY_AUTH"
set_ssh_option "PasswordAuthentication" "$PASS_AUTH"
set_ssh_option "PermitRootLogin"        "$ROOT_LOGIN"
set_ssh_option "MaxAuthTries"           "$MAX_TRIES"
set_ssh_option "LoginGraceTime"         "$GRACE_TIME"
set_ssh_option "X11Forwarding"          "$X11"
set_ssh_option "ClientAliveInterval"    "$SECONDS_VAL"
set_ssh_option "ClientAliveCountMax"    "$ALIVE_COUNT"
set_ssh_option "AuthorizedKeysFile"     ".ssh/authorized_keys"

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh"
if grep -qF "$PUBKEY" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
    info "Public key already present in authorized_keys — skipped."
else
    printf '%s\n' "$PUBKEY" >> "$USER_HOME/.ssh/authorized_keys"
    ok "Public key added to authorized_keys."
fi
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"

info "Updating UFW rules..."
ufw allow "$SSH_PORT/tcp" > /dev/null
if [[ "$SSH_PORT" != "22" ]]; then
    # Remove the default port 22 rule — assumes SSH was the only service using it
    ufw delete allow 22/tcp > /dev/null 2>&1 || true
    info "Removed old port 22 rule from firewall."
fi
ufw --force enable > /dev/null
[[ "$DO_STEALTH" == "yes" ]] && ufw reload > /dev/null

if [[ "$DO_FAIL2BAN" == "yes" ]]; then
    info "Installing Fail2Ban..."
    apt-get update -qq && apt-get install -y fail2ban -qq > /dev/null 2>&1
    cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled  = true
port     = ${SSH_PORT}
maxretry = ${F2B_MAXRETRY}
bantime  = ${F2B_BANTIME}
findtime = ${F2B_FINDTIME}
backend  = auto
EOF
    if [[ "$F2B_RECIDIVE" == "yes" ]]; then
        cat >> /etc/fail2ban/jail.local << EOF

[recidive]
enabled   = true
logpath   = /var/log/fail2ban.log
banaction = %(banaction_allports)s
bantime   = -1
findtime  = ${F2B_RECIDIVE_FINDTIME}
maxretry  = ${F2B_RECIDIVE_COUNT}
EOF
        ok "Recidive jail: IPs banned ${F2B_RECIDIVE_COUNT}+ times within ${F2B_RECIDIVE_FINDTIME} permanently blocked."
    fi
    systemctl enable  fail2ban > /dev/null 2>&1
    systemctl restart fail2ban > /dev/null 2>&1
fi

info "Validating SSH config syntax..."
if ! sshd -t; then
    err "sshd config has errors! Restoring backup: ${BACKUP_PATH}"
    cp "$BACKUP_PATH" /etc/ssh/sshd_config
    err "Original config restored. No SSH changes were applied."
    exit 1
fi
ok "SSH config syntax is valid."

info "Restarting SSH service..."
systemctl daemon-reload
ssh_restart
for i in {1..10}; do systemctl is-active --quiet "$SSH_SERVICE" && break; sleep 1; done

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 7 — Final Verification
# ══════════════════════════════════════════════════════════════
header "🔍  Stage 7 — Final Verification"

systemctl is-active --quiet "$SSH_SERVICE" \
    && ok "SSH Service: ${BOLD_WHITE}Active${RESET}" \
    || err "SSH Service: FAILED"

ss -tulpn | grep -q ":$SSH_PORT " \
    && ok "Port Check: ${BOLD_WHITE}Listening on ${SSH_PORT}${RESET}" \
    || err "Port Check: Nothing listening on ${SSH_PORT}"

ufw status | grep -q "$SSH_PORT" \
    && ok "Firewall: ${BOLD_WHITE}Rule Active${RESET}" \
    || err "Firewall: Rule Missing"

pause_and_clear

# ══════════════════════════════════════════════════════════════
#  STAGE 8 — Finish Screen
# ══════════════════════════════════════════════════════════════
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_GREEN}  ✅  SSH HARDENING COMPLETE! 🎉${RESET}\n"
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

printf "\n${BOLD_CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD_CYAN}User:${RESET}     ${WHITE}${REAL_USER}${RESET}\n"
printf "  ${BOLD_CYAN}IP:${RESET}       ${WHITE}${SERVER_IP}${RESET}\n"
printf "  ${BOLD_CYAN}Port:${RESET}     ${WHITE}${SSH_PORT}${RESET}\n\n"
printf "  ${BOLD_CYAN}Basic:${RESET}\n"
printf "  ${BOLD_YELLOW}  ssh -p ${SSH_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n\n"
if [[ "$CLIENT_OS" == "windows" ]]; then
    printf "  ${BOLD_CYAN}With key:${RESET}\n"
    printf "  ${BOLD_YELLOW}  ssh -i \"%%USERPROFILE%%\\.ssh\\${KEY_FILENAME}\" -p ${SSH_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
else
    printf "  ${BOLD_CYAN}With key:${RESET}\n"
    printf "  ${BOLD_YELLOW}  ssh -i ~/.ssh/${KEY_FILENAME} -p ${SSH_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
fi
echo ""
printf "  ${MAGENTA}Use ${BOLD_WHITE}Basic${RESET}${MAGENTA} if your client auto-detects your key.${RESET}\n"
printf "  ${MAGENTA}Use ${BOLD_WHITE}With key${RESET}${MAGENTA} if Basic fails, or if you used a custom key name —${RESET}\n"
printf "  ${MAGENTA}it points SSH directly to your private key. Always works.${RESET}\n"

printf "\n${BOLD_RED}  🛡️  SAFETY RECOVERY:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD_WHITE}Automated:${RESET} ${MAGENTA}If your login fails, select${RESET} ${BOLD_WHITE}'n'${RESET}${MAGENTA} below.${RESET}\n"
printf "  ${MAGENTA}             The script will${RESET} ${CYAN}instantly undo${RESET}${MAGENTA} all changes,${RESET}\n"
printf "  ${MAGENTA}             restore your backup, and reset the firewall.${RESET}\n\n"
printf "  ${BOLD_WHITE}Backup:${RESET}    ${MAGENTA}Stored at${RESET} ${CYAN}${BACKUP_PATH}${RESET}\n"

printf "\n${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
warn "DO NOT CLOSE THIS WINDOW. Test your login in a NEW terminal now!"
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

# ══════════════════════════════════════════════════════════════
#  STAGE 9 — Final Confirmation & Automated Rollback
# ══════════════════════════════════════════════════════════════
echo ""
if ask_yes_no "Did the connection test work successfully?" "yes/no"; then
    printf "\n${BOLD_GREEN}🎉  Excellent! System hardened and verified.${RESET}\n"
    printf "  ${MAGENTA}Your backup remains at:${RESET} ${BOLD_YELLOW}${BACKUP_PATH}${RESET}\n"
    printf "  ${MAGENTA}Exiting safely...${RESET}\n\n"
    exit 0
fi

# ── Rollback ─────────────────────────────────────────────────
clear; printf "\n"
header "⚠️  RESTORING ORIGINAL CONFIGURATION"
warn "Connection failed. Performing full system rollback..."

info "Restoring SSH configuration..."
SSH_RESTORED=false

if cp "$BACKUP_PATH" /etc/ssh/sshd_config 2>/dev/null && sshd -t 2>/dev/null; then
    info "Backup restored and validated."; SSH_RESTORED=true
fi

if [[ "$SSH_RESTORED" == false ]]; then
    warn "Backup invalid — reinstalling OpenSSH for factory defaults..."
    rm -f /etc/ssh/sshd_config
    if   command -v apt-get &>/dev/null; then apt-get install --reinstall openssh-server -y > /dev/null 2>&1
    elif command -v dnf     &>/dev/null; then dnf reinstall openssh-server -y > /dev/null 2>&1
    elif command -v yum     &>/dev/null; then yum reinstall openssh-server -y > /dev/null 2>&1; fi
    sshd -t 2>/dev/null && { info "Factory defaults restored."; SSH_RESTORED=true; }
fi

if [[ "$SSH_RESTORED" == false ]]; then
    warn "Reinstall failed — writing emergency fallback config..."
    cat > /etc/ssh/sshd_config << 'EOF'
# Emergency fallback — safe SSH defaults
Port 22
AddressFamily any
ListenAddress 0.0.0.0
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    if sshd -t 2>/dev/null; then
        info "Emergency config written and validated."; SSH_RESTORED=true
    else
        warn "Fallback validation failed — writing bare minimum config..."
        printf 'Port 22\nPermitRootLogin yes\nPasswordAuthentication yes\n' > /etc/ssh/sshd_config
        warn "Bare minimum emergency config applied."
        warn "Root password login is now ENABLED — secure this as soon as you reconnect."
    fi
fi

# Restore individual SSH values (from snapshot or manual override)
_restore_ssh_val() {
    local key="$1" val="$2"
    if [[ -n "$val" ]]; then
        grep -q "^$key" /etc/ssh/sshd_config \
            && sed -i "s/^$key.*/$key $val/" /etc/ssh/sshd_config \
            || echo "$key $val" >> /etc/ssh/sshd_config
    else
        sed -i "/^$key/d" /etc/ssh/sshd_config
    fi
}

echo ""
printf "  ${BOLD_CYAN}Pre-script values:${RESET}\n"
printf "  ${BOLD_CYAN}Port:${RESET}                   ${WHITE}${ORIG_PORT:-not set}${RESET}\n"
printf "  ${BOLD_CYAN}PubkeyAuthentication:${RESET}   ${WHITE}${ORIG_PUBKEY_AUTH:-not set}${RESET}\n"
printf "  ${BOLD_CYAN}PasswordAuthentication:${RESET} ${WHITE}${ORIG_PASS_AUTH:-not set}${RESET}\n"
printf "  ${BOLD_CYAN}PermitRootLogin:${RESET}        ${WHITE}${ORIG_ROOT_LOGIN:-not set}${RESET}\n\n"

if ask_yes_no "Manually override recovery settings? (No = restore pre-script values)" "yes/no"; then
    echo ""; [[ -t 0 && -t 1 ]] && clear
    printf "  ${MAGENTA}These values will be written to ${BOLD_WHITE}/etc/ssh/sshd_config${RESET}${MAGENTA} so you can reconnect.${RESET}\n"
    printf "  ${BOLD_YELLOW}Important:${RESET} ${MAGENTA}Choose a port your SSH client and VPS firewall allow.${RESET}\n\n"

    printf "${BOLD_WHITE}  ┌─ Recovery Port ────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Which port should SSH listen on after rollback?${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}If unsure, use ${BOLD_WHITE}22${RESET}${MAGENTA} — the universal SSH default.${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Port:${RESET} " RB_PORT
        [[ "$RB_PORT" =~ ^[0-9]+$ ]] && [[ "$RB_PORT" -ge 1 ]] && [[ "$RB_PORT" -le 65535 ]] \
            && break || err "Please enter a valid port between 1 and 65535."
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Public Key Authentication ───────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Should the server accept SSH key logins?${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Yes = connect with key. No = password-only login.${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Enable PubkeyAuthentication?${RESET} (yes/no): " RB_PUBKEY
        case "$(echo "$RB_PUBKEY" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Password Authentication ─────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Should the server accept password logins?${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}If both Pubkey and Password are set to no, you'll be locked out.${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow PasswordAuthentication?${RESET} (yes/no): " RB_PASS
        case "$(echo "$RB_PASS" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    printf "${BOLD_WHITE}  ┌─ Root Login ───────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Allow root to log in directly? Only enable if you have no${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}other sudo-capable user to fall back to.${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow PermitRootLogin?${RESET} (yes/no): " RB_ROOT
        case "$(echo "$RB_ROOT" | tr '[:upper:]' '[:lower:]')" in yes|no) break ;; *) err "Please type yes or no." ;; esac
    done
    echo ""; [[ -t 0 && -t 1 ]] && clear

    RESTORE_PORT="$RB_PORT"; RESTORE_PUBKEY="$RB_PUBKEY"
    RESTORE_PASS="$RB_PASS"; RESTORE_ROOT="$RB_ROOT"
    info "Using manually specified recovery values."
else
    RESTORE_PORT="$ORIG_PORT";   RESTORE_PUBKEY="$ORIG_PUBKEY_AUTH"
    RESTORE_PASS="$ORIG_PASS_AUTH"; RESTORE_ROOT="$ORIG_ROOT_LOGIN"
    info "Using pre-script values for recovery."
fi

info "Applying recovery settings..."
grep -q "^Port " /etc/ssh/sshd_config \
    && sed -i "s/^Port .*/Port $RESTORE_PORT/" /etc/ssh/sshd_config \
    || echo "Port $RESTORE_PORT" >> /etc/ssh/sshd_config
_restore_ssh_val "PubkeyAuthentication"   "${RESTORE_PUBKEY:-no}"
_restore_ssh_val "PasswordAuthentication" "${RESTORE_PASS:-yes}"
_restore_ssh_val "PermitRootLogin"        "${RESTORE_ROOT:-yes}"
sed -i '/^AuthenticationMethods/d' /etc/ssh/sshd_config

sshd -t 2>/dev/null \
    && info "SSH settings applied and validated." \
    || err "sshd config invalid after recovery! Check: sshd -t"

info "Disabling Firewall (UFW) for safety..."
ufw delete allow "$SSH_PORT/tcp" > /dev/null 2>&1 || true
ufw --force disable               > /dev/null 2>&1
ufw allow "$RESTORE_PORT/tcp"     > /dev/null 2>&1

if [[ "$DO_FAIL2BAN" == "yes" ]] && command -v fail2ban-client >/dev/null 2>&1; then
    info "Stopping and disabling Fail2Ban..."
    systemctl stop    fail2ban > /dev/null 2>&1 || true
    systemctl disable fail2ban > /dev/null 2>&1 || true
fi

if [[ "$DO_STEALTH" == "yes" ]] && [[ -f /etc/ufw/before.rules ]]; then
    info "Removing Stealth Mode (ICMP Drop)..."
    sed -i '/--icmp-type echo-request -j DROP/d' /etc/ufw/before.rules
fi

info "Reloading services to apply rollback..."
systemctl daemon-reload
ssh_restart
for i in {1..10}; do systemctl is-active --quiet "$SSH_SERVICE" && break; sleep 1; done

systemctl is-active --quiet "$SSH_SERVICE" \
    && ok "SSH service is back online." \
    || err "SSH service FAILED to restart! Check logs: journalctl -xe"

printf "\n${BOLD_RED}🚨  FULL ROLLBACK COMPLETE.${RESET}\n"
warn "UFW and Fail2Ban have been DISABLED to prevent lockouts."
printf "  ${MAGENTA}Fix your config and restart services when ready.${RESET}\n\n"
printf "\n${BOLD_CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD_CYAN}Command:${RESET}  ${BOLD_YELLOW}ssh -p ${RESTORE_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n\n"
exit 1
