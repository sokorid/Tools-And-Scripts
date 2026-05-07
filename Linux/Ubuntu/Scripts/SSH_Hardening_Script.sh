#!/bin/bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# ============================================================
#  SSH_Hardening_Script.sh — The Automatic Setup Script
# ============================================================
set -euo pipefail

# ── Version ──────────────────────────────────────────────────
SCRIPT_VERSION="5.0"

# ══ Colors ══════════════════════════════════════════════════
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

# ── Strip colors when terminal is dumb or non-interactive ────
if [[ ! -t 1 ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; WHITE=''; MAGENTA=''
    BOLD=''; BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''
    BOLD_CYAN=''; BOLD_WHITE=''; RESET=''
fi

# ══ UI Helper Functions ══════════════════════════════════════
ok()   { printf "  ${BOLD_GREEN}✅${RESET} %s\n" "$1"; }
info() { printf "  ${BOLD_CYAN}ℹ️${RESET}  %s\n" "$1"; }
warn() { printf "  ${BOLD_YELLOW}⚠️${RESET}  %s\n" "$1"; }
err()  { printf "  ${BOLD_RED}❌${RESET}  %s\n" "$1" >&2; }

error()   { err "$1"; }
success() { ok "$1"; }

header() {
    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  %s${RESET}\n" "$1"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
}

# ── ask_yes_no: handles y/yes/n/no, hint shown in BOLD_WHITE brackets ─
# $1 = prompt text, $2 = optional hint (default: y/n)
ask_yes_no() {
    local hint="${2:-y/n}"
    while true; do
        read -rp "  ${BOLD_WHITE}$1${RESET} [${BOLD_WHITE}${hint}${RESET}]: " input
        case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     err "Please type y or n (or yes/no)." ;;
        esac
    done
}

# ── pause_and_clear ──────────────────────────────────────────
pause_and_clear() {
    echo -e "\n${BOLD_GREEN}┌──────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD_GREEN}│${RESET}  ✔  ${BOLD_WHITE}STAGE COMPLETE!${RESET}                              ${BOLD_GREEN}│${RESET}"
    echo -e "${BOLD_GREEN}│${RESET}  ${CYAN}Press any key to move to the next step...${RESET}       ${BOLD_GREEN}│${RESET}"
    echo -e "${BOLD_GREEN}└──────────────────────────────────────────────────┘${RESET}"
    # Only read a keystroke if stdin AND stdout are interactive terminals
    [[ -t 0 && -t 1 ]] && read -n 1 -s -r || true
    # Only clear if both stdin and stdout are a real terminal
    [[ -t 0 && -t 1 ]] && clear
}

# ── convert_to_seconds ───────────────────────────────────────
convert_to_seconds() {
    local input=$1
    local unit value
    unit=$(echo "$input"  | grep -o -E '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')
    value=$(echo "$input" | grep -o -E '[0-9]+')
    [[ -z "$value" ]] && echo "-1" && return
    case "$unit" in
        yr|year|years)      echo $((value * 31536000)) ;;
        mo|month|months)    echo $((value * 2592000))  ;;
        d|day|days)         echo $((value * 86400))    ;;
        h|hour|hours)       echo $((value * 3600))     ;;
        m|min|minutes)      echo $((value * 60))       ;;
        s|sec|seconds|"")   echo "$value"              ;;
        *)                  echo "-1"                  ;;
    esac
}

# ── convert_to_fail2ban_time ─────────────────────────────────
# Fail2Ban accepts its own time format (e.g. 1h, 7d) — not raw seconds.
# This converts user input into the canonical Fail2Ban string.
# Supports: Xs Xm Xh Xd Xmo Xyr  →  outputs Fail2Ban-native string.
convert_to_fail2ban_time() {
    local input=$1
    local unit value
    unit=$(echo "$input"  | grep -o -E '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')
    value=$(echo "$input" | grep -o -E '[0-9]+')
    [[ -z "$value" ]] && echo "" && return
    case "$unit" in
        yr|year|years)      echo "${value}y"  ;;
        mo|month|months)    echo "${value}mo" ;;
        d|day|days)         echo "${value}d"  ;;
        h|hour|hours)       echo "${value}h"  ;;
        m|min|minutes)      echo "${value}m"  ;;
        s|sec|seconds|"")   echo "${value}s"  ;;
        *)                  echo ""           ;;
    esac
}

# ── set_ssh_option ───────────────────────────────────────────
# Handles stock sshd_config files that use "#Port 22" style defaults.
set_ssh_option() {
    if grep -qE "^#?${1}[[:space:]]" /etc/ssh/sshd_config; then
        sed -i -E "s|^#?($1)\s+.*|$1 $2|" /etc/ssh/sshd_config
    else
        echo "$1 $2" >> /etc/ssh/sshd_config
    fi
}

# ══ SSH Service Detection ════════════════════════════════════
SSH_SERVICE="ssh"

# Detect whether ssh.socket exists (modern Ubuntu uses socket activation)
SSH_SOCKET=""
if systemctl list-unit-files --type=socket 2>/dev/null | grep -qE '^sshd?\.socket'; then
    SSH_SOCKET=$(systemctl list-unit-files --type=socket 2>/dev/null \
        | grep -oE '^sshd?\.socket' | head -1)
fi

ssh_stop() {
    [[ -n "$SSH_SOCKET" ]] && systemctl stop "$SSH_SOCKET"  > /dev/null 2>&1 || true
    systemctl stop "$SSH_SERVICE" > /dev/null 2>&1 || true
}

ssh_start() {
    if ! systemctl start "$SSH_SERVICE"; then
        err "Failed to start SSH service!"
        exit 1
    fi
    [[ -n "$SSH_SOCKET" ]] && systemctl start "$SSH_SOCKET" > /dev/null 2>&1 || true
}

ssh_restart() {
    ssh_stop
    sleep 1
    ssh_start
}

# ══ Stealth Mode (ICMP Drop) ═════════════════════════════════
DO_STEALTH="no"

set_icmp_stealth() {
    local rules_file="/etc/ufw/before.rules"
    if grep -q "icmp-type echo-request -j DROP" "$rules_file"; then
        ok "Stealth mode is already configured."
        return
    fi
    info "Configuring UFW to drop ICMP echo requests..."
    sed -i '/--icmp-type echo-request -j ACCEPT/i -A ufw-before-input -p icmp --icmp-type echo-request -j DROP' "$rules_file"
    ok "Stealth Mode queued: server will no longer respond to pings after firewall is applied."
}

# ══ Root Check ═══════════════════════════════════════════════
if [[ $EUID -ne 0 ]]; then
    err "Please run this script with sudo."
    exit 1
fi

# ══ Ubuntu Version Check ══════════════════════════════════════
# Minimum: 18.04 LTS   Tested on: 26.04 LTS
check_ubuntu_version() {
    if ! command -v lsb_release &>/dev/null; then
        error "lsb_release not found. This script requires Ubuntu 18.04 LTS or later."
        exit 1
    fi
    local distro
    distro=$(lsb_release -si)
    if [[ "$distro" != "Ubuntu" ]]; then
        error "This script is designed for Ubuntu only. Detected: $distro"
        exit 1
    fi
    local version major minor tested_major tested_minor
    version=$(lsb_release -sr)
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    tested_major=26
    tested_minor=04

    # Hard stop — below minimum supported version
    if [[ "$major" -lt 18 ]]; then
        error "Ubuntu 18.04 or later is required. Detected: Ubuntu $version"
        error "This script cannot run on your version. Exiting."
        exit 1
    fi

    # Warn — below tested version, ask user to confirm
    if [[ "$major" -lt "$tested_major" ]] || \
       { [[ "$major" -eq "$tested_major" ]] && [[ "$minor" -lt "$tested_minor" ]]; }; then
        echo ""
        warn "This script has only been tested on Ubuntu ${tested_major}.${tested_minor}."
        printf "  ${MAGENTA}You are running Ubuntu ${version}. Continuing may produce unexpected results.${RESET}\n\n"
        if ! ask_yes_no "Do you want to continue at your own risk?" "yes/no"; then
            error "Aborting."
            exit 1
        fi
        success "Ubuntu $version detected — continuing at user's risk."
    else
        success "Ubuntu $version detected — compatible."
    fi
}
check_ubuntu_version

# Check for UFW before proceeding ───────────────────
if ! command -v ufw &>/dev/null; then
    warn "UFW is not installed on this system."
    printf "  ${MAGENTA}Many VPS images ship without UFW.${RESET}\n\n"
    if ask_yes_no "Install UFW now and continue?" "yes/no"; then
        info "Installing UFW..."
        if apt-get update -qq && apt-get install -y ufw -qq > /dev/null 2>&1; then
            ok "UFW installed successfully."
        else
            err "UFW installation failed. Cannot continue without UFW."
            printf "  ${MAGENTA}Try manually: ${BOLD_WHITE}apt-get install ufw${RESET}\n"
            exit 1
        fi
    else
        err "UFW is required. Exiting."
        exit 1
    fi
fi

# ══ Auto-detect Identity ═════════════════════════════════════
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
REAL_USER="${REAL_USER:-${USER:-root}}"
CURRENT_HOSTNAME=$(hostname)

# ── Warn if REAL_USER resolved to root ──────────────────────
if [[ "$REAL_USER" == "root" ]]; then
    warn "Could not detect a non-root user (SUDO_USER is unset)."
    printf "  ${MAGENTA}Your SSH public key will be added to ${BOLD_WHITE}/root/.ssh/authorized_keys${RESET}\n"
    printf "  ${MAGENTA}If this is not what you want, re-run with: ${BOLD_WHITE}sudo -u youruser bash script.sh${RESET}\n\n"
    if ! ask_yes_no "Continue installing for the root user?" "yes/no"; then
        err "Aborting. Re-run the script using sudo from a non-root user account."
        exit 1
    fi
fi

# SERVER_IP is resolved after the user answers the bare-metal / VPS question below.
SERVER_IP=""
SERVER_TYPE=""   # "baremetal" or "vps"

# ── Helper: detect RFC-1918 private addresses ────────────────
_is_private_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]]                              && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]     && return 0
    [[ "$ip" =~ ^192\.168\. ]]                         && return 0
    return 1
}

# ── Bare-metal IP detection (original behaviour) ─────────────
_detect_ip_baremetal() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    ip="${ip:-$(hostname -I | awk '{print $1}')}"
    echo "$ip"
}

# ── VPS IP detection (public IP via external lookup) ─────────
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

# ══ Snapshot original SSH auth state (for exact rollback) ════
_get_ssh_val() {
    grep -E "^$1\s" /etc/ssh/sshd_config 2>/dev/null \
        | awk '{print $2}' | tail -1 || true
}
ORIG_PUBKEY_AUTH=$(_get_ssh_val "PubkeyAuthentication")
ORIG_PASS_AUTH=$(_get_ssh_val "PasswordAuthentication")
ORIG_ROOT_LOGIN=$(_get_ssh_val "PermitRootLogin")
ORIG_PORT=$(_get_ssh_val "Port")
ORIG_PORT="${ORIG_PORT:-22}"

# ══ Fail2Ban defaults ════════════════════════════════════════
F2B_MAXRETRY=5
F2B_BANTIME=1h
F2B_FINDTIME=10m
F2B_RECIDIVE="no"
F2B_RECIDIVE_COUNT=3
DO_FAIL2BAN="no"

BACKUP_PATH=""

# ══ Welcome Banner ═══════════════════════════════════════════
clear
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_WHITE}  📦  SSH Hardening Script  ${BOLD_YELLOW}v${SCRIPT_VERSION}${RESET}\n"
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "\n"

# ══ Server Environment Question ══════════════════════════════
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

# ══ Second Welcome Banner ════════════════════════════════════
clear
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_WHITE}  📦  SSH Hardening Script  ${BOLD_YELLOW}v${SCRIPT_VERSION}${RESET}\n"
printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
printf "\n"
printf "\n"
info "Detected user: ${BOLD_WHITE}${REAL_USER}${RESET}  |  IP: ${BOLD_WHITE}${SERVER_IP}${RESET}"

# ══ STAGE 1 — Public Key ═════════════════════════════════════
header "🔑  Stage 1 — Your SSH Public Key"
printf "  ${MAGENTA}To find your key on your ${BOLD_WHITE}Main Computer${RESET}:${RESET}\n"
printf "  ${BOLD_CYAN}Windows:${RESET}     ${WHITE}type %%USERPROFILE%%\\.ssh\\id_ed25519.pub${RESET}\n"
printf "  ${BOLD_CYAN}macOS/Linux:${RESET} ${WHITE}cat ~/.ssh/id_ed25519.pub${RESET}\n"
echo ""
printf "  ${MAGENTA}If you need one: ${BOLD_YELLOW}ssh-keygen -t ed25519${RESET}${MAGENTA} on your PC.${RESET}\n"
echo ""

while true; do
    read -rp "  ${BOLD_WHITE}Paste your Public Key here:${RESET} " PUBKEY
    if [[ "$PUBKEY" =~ $'\n' ]]; then
        err "Key contains embedded newlines — please paste a single-line key."
        continue
    fi
    if [[ ! "$PUBKEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        err "Invalid format. Key should start with 'ssh-ed25519' or similar."
        continue
    fi
    TMPKEY=$(mktemp)
    echo "$PUBKEY" > "$TMPKEY"
    if ssh-keygen -l -f "$TMPKEY" &>/dev/null; then
        ok "Key accepted and cryptographically validated."
        rm -f "$TMPKEY"
        break
    else
        rm -f "$TMPKEY"
        err "Key failed validation. It may be truncated or corrupted — please paste it again."
    fi
done

pause_and_clear

# ══ STAGE 2 — Port Config ════════════════════════════════════
header "🌐  Stage 2 — Choose Your SSH Port"
printf "  ${MAGENTA}SSH listens on a port — think of it as the door number on your server.${RESET}\n"
printf "  ${MAGENTA}The default is port ${BOLD_WHITE}22${RESET}${MAGENTA}, which every bot on the internet knows to knock on.${RESET}\n"
printf "  ${MAGENTA}Changing it to a high random port reduces automated attack noise significantly.${RESET}\n\n"
printf "  ${BOLD_CYAN}Port 22:${RESET}       ${WHITE}The standard default. Fine if you have other protections.${RESET}\n"
printf "  ${BOLD_CYAN}1024–65535:${RESET}    ${WHITE}Recommended range for a custom port.${RESET}\n"
printf "  ${BOLD_YELLOW}Avoid:${RESET}         ${WHITE}80 (HTTP), 443 (HTTPS), 3306 (MySQL), 5432 (Postgres), etc.${RESET}\n"
if [[ "$SERVER_TYPE" == "vps" ]]; then
    printf "\n  ${BOLD_YELLOW}⚠️  VPS NOTE:${RESET} ${WHITE}After this script finishes, make sure your VPS provider's${RESET}\n"
    printf "  ${WHITE}firewall / security group also allows the port you choose here.${RESET}\n"
    printf "  ${MAGENTA}Most providers (Vultr, DigitalOcean, AWS, etc.) have a separate${RESET}\n"
    printf "  ${MAGENTA}network-level firewall in their dashboard that is independent of UFW.${RESET}\n"
    printf "  ${MAGENTA}UFW alone is not enough — both firewalls must allow your SSH port.${RESET}\n"
fi
echo ""

while true; do
    read -rp "  ${BOLD_WHITE}Enter desired SSH Port${RESET} [${BOLD_WHITE}2552${RESET}]: " SSH_PORT
    SSH_PORT="${SSH_PORT:-2552}"

    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]]; then
        err "Port must be a number."
        continue
    fi
    if [[ "$SSH_PORT" -gt 65535 ]]; then
        err "Port must be 65535 or below."
        continue
    fi
    if [[ "$SSH_PORT" -eq 22 ]]; then
        warn "You chose port 22 — the standard SSH default."
        printf "  ${MAGENTA}This works fine but is heavily scanned by bots. Make sure Fail2Ban${RESET}\n"
        printf "  ${MAGENTA}or another brute-force protection is enabled if you keep this.${RESET}\n"
        if ! ask_yes_no "Continue with port 22?" "yes/no"; then
            continue
        fi
        # Port 22 is already in use by the running SSH service — that's expected.
        # Skip the in-use check so it doesn't falsely block keeping the default port.
        ok "Port ${BOLD_WHITE}22${RESET} confirmed."
        break
    elif [[ "$SSH_PORT" -lt 1024 ]]; then
        warn "Port ${SSH_PORT} is a reserved system port (below 1024). It may conflict with other services."
        if ! ask_yes_no "Are you sure you want to use port ${SSH_PORT}?" "yes/no"; then
            continue
        fi
    fi
    if ss -tulpn | grep -q ":$SSH_PORT "; then
        err "Port $SSH_PORT is ALREADY in use! Choose another."
    else
        ok "Port ${BOLD_WHITE}${SSH_PORT}${RESET} is available."
        break
    fi
done

pause_and_clear

# ══ STAGE 3 — Hardening Options ══════════════════════════════
header "⚙️   Stage 3 — SSH Hardening Settings"
printf "  ${BOLD_CYAN}High-Security Defaults include:${RESET}\n"
printf "  ${MAGENTA}  - Disable Passwords:  Force SSH Key login only. Keys cannot be guessed.${RESET}\n"
printf "  ${MAGENTA}  - Disable Root Login: Attackers cannot target the 'root' account directly.${RESET}\n"
printf "  ${MAGENTA}  - Idle Timeout:       Auto-disconnect sessions idle for more than 5 minutes.${RESET}\n"
printf "  ${MAGENTA}  - Max Tries:          Drop the connection after 3 failed login attempts.${RESET}\n"
echo ""

if ask_yes_no "Apply these high-security defaults?" "yes/no"; then
    PUBKEY_AUTH=yes; PASS_AUTH=no; ROOT_LOGIN=no
    MAX_TRIES=3; GRACE_TIME=30; X11=no; SECONDS_VAL=300; ALIVE_COUNT=2
    ok "Defaults applied."
else
    printf "\n${BOLD_CYAN}Manual Configuration${RESET}\n"
    printf "  ${MAGENTA}You will be asked about each setting one at a time.${RESET}\n"
    printf "  ${MAGENTA}Read each description carefully — type ${BOLD_WHITE}yes${RESET}${MAGENTA} or ${BOLD_WHITE}no${RESET}${MAGENTA} for each question.${RESET}\n\n"

    # ── Public Key Authentication ────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Public Key Authentication ───────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}SSH keys are cryptographic pairs — a private key on your PC${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}and a public key on the server. Login only works if both match.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This is far stronger than any password and cannot be guessed.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: yes${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Enable Public Key Authentication?${RESET} (yes/no): " PUBKEY_AUTH
        case "$(echo "$PUBKEY_AUTH" | tr '[:upper:]' '[:lower:]')" in
            yes|no) break ;;
            *) err "Please type yes or no." ;;
        esac
    done
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Password Authentication ──────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Password Authentication ─────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}When enabled, anyone can attempt to log in with a password.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Bots constantly scan port 22 and try thousands of common${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}passwords automatically. Disabling this stops that entirely.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}Warning: If you disable this, SSH keys become your only way in.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}Make sure your key is working before you log out!${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no (disable passwords, use keys only)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow Password Authentication?${RESET} (yes/no): " PASS_AUTH
        case "$(echo "$PASS_AUTH" | tr '[:upper:]' '[:lower:]')" in
            yes|no) break ;;
            *) err "Please type yes or no." ;;
        esac
    done
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Root Login ───────────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Root Login ───────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}'root' is the superuser account that exists on every Linux${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}server. Because it is always there, attackers target it first.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Disabling root login forces use of a normal account + sudo,${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}adding an extra layer — they would need to guess both your${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}username AND your password/key.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no (disable root login)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Allow Root Login?${RESET} (yes/no): " ROOT_LOGIN
        case "$(echo "$ROOT_LOGIN" | tr '[:upper:]' '[:lower:]')" in
            yes|no) break ;;
            *) err "Please type yes or no." ;;
        esac
    done
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Max Auth Tries ───────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Max Auth Tries ───────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This limits how many login attempts are allowed per connection.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}After this many failures the connection is forcibly dropped.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Lower is stricter. 3 is enough for a human making typos.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 3${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Max Auth Tries${RESET} [${BOLD_WHITE}3${RESET}]: " MAX_TRIES
    MAX_TRIES="${MAX_TRIES:-3}"
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Login Grace Time ─────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Login Grace Time ─────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}After connecting, you have this long to complete login.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}If login is not finished in time, the connection is dropped.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This limits how long an attacker can sit on an open connection.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}30s${RESET}${MAGENTA}  ${BOLD_WHITE}1m${RESET}${MAGENTA}  ${BOLD_WHITE}2m${RESET}${MAGENTA} ${BOLD_WHITE}1h${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 30s${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Login Grace Time${RESET} [${BOLD_WHITE}30s${RESET}]: " GRACE_INPUT
        GRACE_INPUT="${GRACE_INPUT:-30s}"
        GRACE_TIME=$(convert_to_seconds "$GRACE_INPUT")
        if [[ "$GRACE_TIME" == "-1" || "$GRACE_TIME" -le 0 ]]; then
            warn "Invalid format. Try something like 30s, 1m, or 2m."
        else
            ok "Grace time set to ${BOLD_WHITE}${GRACE_TIME}${RESET} seconds."
            break
        fi
    done
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── X11 Forwarding ───────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ X11 Forwarding ───────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}X11 Forwarding lets you run graphical (GUI) apps over SSH${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}and have them display on your local screen.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Most servers never need this. Enabling it slightly increases${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}attack surface with no benefit on a headless server.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: no${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    while true; do
        read -rp "  ${BOLD_WHITE}Enable X11 Forwarding?${RESET} (yes/no): " X11
        case "$(echo "$X11" | tr '[:upper:]' '[:lower:]')" in
            yes|no) break ;;
            *) err "Please type yes or no." ;;
        esac
    done
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Idle Timeout ─────────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Idle Timeout ─────────────────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}If a logged-in session goes idle (no keyboard activity), the${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}server will send keep-alive checks. If no response is received${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}after the timeout, the session is automatically disconnected.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This closes forgotten open sessions that could be hijacked.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}300s${RESET}${MAGENTA}  ${BOLD_WHITE}15m${RESET}${MAGENTA}  ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 300s (5 minutes)${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Idle Timeout duration${RESET} [${BOLD_WHITE}300s${RESET}]: " TIME_INPUT
    TIME_INPUT="${TIME_INPUT:-300s}"
    SECONDS_VAL=$(convert_to_seconds "$TIME_INPUT")
    if [[ "$SECONDS_VAL" == "-1" || "$SECONDS_VAL" -le 0 ]]; then
        warn "Invalid time format. Defaulting to 300 seconds (5 minutes)."
        SECONDS_VAL=300
    fi
    echo ""
    [[ -t 0 && -t 1 ]] && clear

    # ── Alive Check Count ────────────────────────────────────
    printf "${BOLD_WHITE}  ┌─ Keep-Alive Check Count ───────────────────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}When an idle session hits the timeout above, the server sends${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}a keep-alive ping. This setting controls how many unanswered${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}pings are allowed before the session is forcibly closed.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Total idle time before disconnect = timeout × this count.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 2${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    read -rp "  ${BOLD_WHITE}Alive Check Count${RESET} [${BOLD_WHITE}2${RESET}]: " ALIVE_COUNT
    ALIVE_COUNT="${ALIVE_COUNT:-2}"

    echo ""
    printf "  ${GREEN}Idle timeout set to:${RESET} ${BOLD_WHITE}${SECONDS_VAL}s${RESET} × ${BOLD_WHITE}${ALIVE_COUNT}${RESET} checks = ${BOLD_YELLOW}$((SECONDS_VAL * ALIVE_COUNT))s${RESET} ${MAGENTA}max before disconnect${RESET}\n"
fi

pause_and_clear

# ══ STAGE 4 — Fail2Ban ═══════════════════════════════════════
header "🛡️   Stage 4 — Fail2Ban Protection"
printf "  ${MAGENTA}Fail2Ban watches your SSH logs and automatically bans IP addresses${RESET}\n"
printf "  ${MAGENTA}that repeatedly fail to log in. It's your first line of defence${RESET}\n"
printf "  ${MAGENTA}against brute-force attacks.${RESET}\n\n"
printf "  ${BOLD_CYAN}Max Retry (5):${RESET}   ${WHITE}An IP is banned after 5 failed login attempts.${RESET}\n"
printf "  ${MAGENTA}                 Lower = stricter. 3–5 is the typical sweet spot.${RESET}\n\n"
printf "  ${BOLD_CYAN}Ban Time (1h):${RESET}   ${WHITE}How long a banned IP stays blocked.${RESET}\n"
printf "  ${MAGENTA}                 1h means the attacker must wait an hour before trying again.${RESET}\n"
printf "  ${MAGENTA}                 Use longer values (24h, 7d) for persistent attackers.${RESET}\n\n"
printf "  ${BOLD_CYAN}Find Time (10m):${RESET} ${WHITE}The window failures must happen in to count toward a ban.${RESET}\n"
printf "  ${MAGENTA}                 5 failures spread over 2 hours won't trigger a ban.${RESET}\n"
printf "  ${MAGENTA}                 5 failures within 10 minutes will.${RESET}\n\n"

if ask_yes_no "Install Fail2Ban with these defaults?" "yes/no"; then
    F2B_MAXRETRY=5; F2B_BANTIME=1h; F2B_FINDTIME=10m
    DO_FAIL2BAN="yes"
    ok "Fail2Ban defaults selected."
else
    printf "\n  ${MAGENTA}Would you like to configure Fail2Ban with custom values instead?${RESET}\n"
    printf "  ${BOLD_YELLOW}Answering no here will skip Fail2Ban entirely — it will not be${RESET}\n"
    printf "  ${BOLD_YELLOW}installed or configured on your server.${RESET}\n\n"
    if ask_yes_no "Manually configure Fail2Ban?" "yes/no"; then

        # ── Max Retry ────────────────────────────────────────
        printf "\n${BOLD_WHITE}  ┌─ Max Retry ────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How many failed login attempts are allowed from one IP before${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}it gets banned. Lower values are stricter but could lock out${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}a legitimate user who mistyped their password a few times.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 5${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        read -rp "  ${BOLD_WHITE}Max Retry${RESET} [${BOLD_WHITE}5${RESET}]: " F2B_MAXRETRY
        F2B_MAXRETRY="${F2B_MAXRETRY:-5}"
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── Ban Time ─────────────────────────────────────────
        printf "${BOLD_WHITE}  ┌─ Ban Time ─────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How long a banned IP address stays blocked.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}After this time expires the IP is automatically unbanned.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}24h${RESET}${MAGENTA}  ${BOLD_WHITE}7d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}${MAGENTA}  ${BOLD_WHITE}-1${RESET}${MAGENTA} (permanent)${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 1h${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Ban Time${RESET} [${BOLD_WHITE}1h${RESET}]: " _f2b_bantime_input
            _f2b_bantime_input="${_f2b_bantime_input:-1h}"
            if [[ "$_f2b_bantime_input" == "-1" ]]; then
                F2B_BANTIME="-1"
                ok "Ban time set to ${BOLD_WHITE}permanent${RESET}."
                break
            fi
            F2B_BANTIME=$(convert_to_fail2ban_time "$_f2b_bantime_input")
            if [[ -n "$F2B_BANTIME" ]]; then
                ok "Ban time set to ${BOLD_WHITE}${F2B_BANTIME}${RESET}."
                break
            else
                err "Invalid format. Try something like 1h, 24h, 7d, 1mo, 1yr, or -1."
            fi
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── Find Time ────────────────────────────────────────
        printf "${BOLD_WHITE}  ┌─ Find Time ────────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}The rolling time window failures must occur within to count.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Only failures that happen within this window are tallied${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}toward a ban. Failures older than this window are forgotten.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}10m${RESET}${MAGENTA}  ${BOLD_WHITE}30m${RESET}${MAGENTA}  ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 10m${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Find Time${RESET} [${BOLD_WHITE}10m${RESET}]: " _f2b_findtime_input
            _f2b_findtime_input="${_f2b_findtime_input:-10m}"
            F2B_FINDTIME=$(convert_to_fail2ban_time "$_f2b_findtime_input")
            if [[ -n "$F2B_FINDTIME" ]]; then
                ok "Find time set to ${BOLD_WHITE}${F2B_FINDTIME}${RESET}."
                break
            else
                err "Invalid format. Try something like 10m, 30m, 1h, 1d, 1mo, 1yr."
            fi
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear
        DO_FAIL2BAN="yes"
    else
        DO_FAIL2BAN="no"
        warn "Fail2Ban will NOT be installed or configured on this server."
        printf "  ${MAGENTA}You can install it manually later with: ${BOLD_WHITE}apt-get install fail2ban${RESET}\n"
    fi
fi

# ── Recidive (Permanent Ban for Repeat Offenders) ────────────
if [[ "$DO_FAIL2BAN" == "yes" ]]; then
    echo ""
    printf "${BOLD_WHITE}  ┌─ Permanent Ban for Repeat Offenders ──────────────────────┐${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Fail2Ban's 'recidive' jail watches for IPs that keep coming${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}back and getting banned repeatedly. If an IP gets banned more${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}than the threshold you set, it earns a permanent ban — it will${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}never be let back in automatically, regardless of ban time.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}This is the best defence against persistent attackers who${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}just wait out their ban and try again.${RESET}\n"
    printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: yes${RESET}\n"
    printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
    if ask_yes_no "Enable permanent ban for repeat offenders?" "yes/no"; then
        F2B_RECIDIVE="yes"
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── Repeat Offender Threshold ────────────────────────
        printf "${BOLD_WHITE}  ┌─ Repeat Offender Threshold ────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How many times must an IP be banned before it gets permanently${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}blocked? Each time they get banned and come back counts as one.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Setting this to 3 means: banned once, unbanned, tries again,${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}banned twice, unbanned, tries again — third ban is permanent.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 3${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Ban threshold (number of bans before permanent):${RESET} [${BOLD_WHITE}3${RESET}]: " F2B_RECIDIVE_COUNT
            F2B_RECIDIVE_COUNT="${F2B_RECIDIVE_COUNT:-3}"
            if [[ "$F2B_RECIDIVE_COUNT" =~ ^[0-9]+$ ]] && [[ "$F2B_RECIDIVE_COUNT" -ge 1 ]]; then
                ok "IPs banned ${BOLD_WHITE}${F2B_RECIDIVE_COUNT}${RESET} or more times will be permanently blocked."
                break
            else
                err "Please enter a whole number of 1 or more."
            fi
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── Recidive Findtime Window ─────────────────────────
        printf "${BOLD_WHITE}  ┌─ Repeat Offender Memory Window ───────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}How far back should the recidive jail look when counting bans?${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Only bans that happened within this window count toward the${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}permanent-ban threshold. Bans older than this are forgotten.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Example — threshold 3, window 1d:${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}  An IP banned 3 times within 24 hours → permanent.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}  An IP banned once today, once last week → NOT permanent yet${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}  (last week's ban fell outside the 1d window).${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Longer windows = longer memory = stricter, but higher risk of${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}permanently blocking a legitimate user who had a bad month.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Format examples: ${BOLD_WHITE}1h${RESET}${MAGENTA}  ${BOLD_WHITE}1d${RESET}${MAGENTA}  ${BOLD_WHITE}7d${RESET}${MAGENTA}  ${BOLD_WHITE}1mo${RESET}${MAGENTA}  ${BOLD_WHITE}1yr${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_GREEN}Recommendation: 1d${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Memory window${RESET} [${BOLD_WHITE}1d${RESET}]: " _recidive_window_input
            _recidive_window_input="${_recidive_window_input:-1d}"
            F2B_RECIDIVE_FINDTIME=$(convert_to_fail2ban_time "$_recidive_window_input")
            if [[ -n "$F2B_RECIDIVE_FINDTIME" ]]; then
                ok "Recidive memory window set to ${BOLD_WHITE}${F2B_RECIDIVE_FINDTIME}${RESET}."
                break
            else
                err "Invalid format. Try something like 1h, 1d, 7d, 1mo, 1yr."
            fi
        done
    else
        F2B_RECIDIVE="no"
        info "Repeat-offender permanent ban disabled."
    fi
fi

pause_and_clear

# ══ STAGE 5 — Stealth Mode ═══════════════════════════════════
header "👻  Stage 5 — Stealth Mode (ICMP Stealth)"
printf "  ${MAGENTA}By default, servers respond to 'ping'. Disabling this makes it${RESET}\n"
printf "  ${MAGENTA}harder for bots to discover your server during network scans.${RESET}\n"
printf "  ${BOLD_WHITE}Security Note:${RESET} ${MAGENTA}This does${RESET} ${BOLD_WHITE}not${RESET} ${MAGENTA}fully hide you. If a bot finds an${RESET}\n"
printf "  ${MAGENTA}open port (like your SSH port), they will know you are there.${RESET}\n"
printf "  ${MAGENTA}This is simply an${RESET} ${CYAN}added layer${RESET} ${MAGENTA}of obscurity to slow them down.${RESET}\n"
printf "  ${BOLD_YELLOW}Note:${RESET} You won't be able to ping this server to test uptime.\n\n"

if ask_yes_no "Disallow pinging of the server (Stealth Mode)?" "yes/no"; then
    DO_STEALTH="yes"
    set_icmp_stealth
else
    info "Stealth Mode skipped. Server remains pingable."
fi

pause_and_clear

# ══ STAGE 6 — Applying Configurations ════════════════════════
header "🚀  Stage 6 — Applying Configurations"

# ── VPS Provider Firewall Reminder ──────────────────────────
if [[ "$SERVER_TYPE" == "vps" ]] && [[ "$SSH_PORT" != "22" ]]; then
    echo ""
    printf "${BOLD_RED}  ┌─ ⚠️  VPS PROVIDER FIREWALL WARNING ──────────────────────────┐${RESET}\n"
    printf "${BOLD_RED}  │${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${BOLD_YELLOW}You are on a VPS and have changed your SSH port to${RESET} ${BOLD_WHITE}${SSH_PORT}${RESET}${BOLD_YELLOW}.${RESET}\n"
    printf "${BOLD_RED}  │${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${MAGENTA}UFW alone is not enough. Your VPS provider has its own${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${MAGENTA}cloud-level firewall that sits OUTSIDE this server.${RESET}\n"
    printf "${BOLD_RED}  │${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${BOLD_WHITE}Before continuing, open port ${SSH_PORT}/tcp in your provider's${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${BOLD_WHITE}control panel — otherwise you WILL be locked out.${RESET}\n"
    printf "${BOLD_RED}  │${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${CYAN}Vultr:${RESET}         ${WHITE}Network → Firewall Groups${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${CYAN}DigitalOcean:${RESET}  ${WHITE}Networking → Firewalls${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${CYAN}Linode:${RESET}        ${WHITE}Firewalls (Cloud Manager)${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${CYAN}AWS:${RESET}           ${WHITE}EC2 → Security Groups${RESET}\n"
    printf "${BOLD_RED}  │${RESET}  ${CYAN}Oracle:${RESET}        ${WHITE}Networking → Security Lists / NSGs${RESET}\n"
    printf "${BOLD_RED}  │${RESET}\n"
    printf "${BOLD_RED}  └───────────────────────────────────────────────────────────────┘${RESET}\n\n"
    if ! ask_yes_no "I have opened port ${SSH_PORT} in my provider's firewall. Continue?" "yes/no"; then
        warn "Pausing. Open the port in your provider's control panel, then re-run the script."
        exit 0
    fi
fi

# Create unique timestamped backup
BACKUP_PATH="/etc/ssh/sshd_config.$(date +%Y%m%d%H%M%S).bak"
cp /etc/ssh/sshd_config "$BACKUP_PATH"
info "Config backed up to: ${BOLD_WHITE}${BACKUP_PATH}${RESET}"

info "Writing settings to ${BOLD_WHITE}/etc/ssh/sshd_config${RESET}..."

set_ssh_option "Port"                  "$SSH_PORT"
set_ssh_option "PubkeyAuthentication"  "$PUBKEY_AUTH"
set_ssh_option "PasswordAuthentication" "$PASS_AUTH"
set_ssh_option "PermitRootLogin"       "$ROOT_LOGIN"
set_ssh_option "MaxAuthTries"          "$MAX_TRIES"
set_ssh_option "LoginGraceTime"        "$GRACE_TIME"
set_ssh_option "X11Forwarding"         "$X11"
set_ssh_option "ClientAliveInterval"   "$SECONDS_VAL"
set_ssh_option "ClientAliveCountMax"   "$ALIVE_COUNT"
set_ssh_option "AuthorizedKeysFile"    ".ssh/authorized_keys"

# ── SSH Key Setup ────────────────────────────────────────────
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh"

if grep -qF "$PUBKEY" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
    info "Public key already present in authorized_keys — skipped."
else
    printf '%s\n' "$PUBKEY" >> "$USER_HOME/.ssh/authorized_keys"
    ok "Public key added to authorized_keys."
fi

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.ssh"
chmod 700  "$USER_HOME/.ssh"
chmod 600  "$USER_HOME/.ssh/authorized_keys"

# ── Firewall (UFW) ───────────────────────────────────────────
info "Updating UFW rules..."
ufw allow "$SSH_PORT/tcp" > /dev/null
if [[ "$SSH_PORT" != "22" ]]; then
    ufw delete allow 22/tcp > /dev/null 2>&1 || true
    info "Removed old port 22 rule from firewall."
fi
ufw --force enable > /dev/null

if [[ "$DO_STEALTH" == "yes" ]]; then
    ufw reload > /dev/null
fi

# ── Fail2Ban ─────────────────────────────────────────────────
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

    # ── Recidive jail — permanent ban for repeat offenders ───
    if [[ "$F2B_RECIDIVE" == "yes" ]]; then
        cat >> /etc/fail2ban/jail.local << EOF

[recidive]
enabled  = true
logpath  = /var/log/fail2ban.log
banaction = %(banaction_allports)s
bantime  = -1
findtime = ${F2B_RECIDIVE_FINDTIME}
maxretry = ${F2B_RECIDIVE_COUNT}
EOF
        ok "Recidive jail enabled — IPs banned ${F2B_RECIDIVE_COUNT}+ times within ${F2B_RECIDIVE_FINDTIME} will be permanently blocked."
    fi

    systemctl enable  fail2ban > /dev/null 2>&1
    systemctl restart fail2ban > /dev/null 2>&1
fi

# ── Validate & Restart SSH ───────────────────────────────────
info "Validating SSH config syntax..."
if ! sshd -t; then
    err "sshd config has errors! Restoring backup: ${BACKUP_PATH}"
    cp "$BACKUP_PATH" /etc/ssh/sshd_config
    err "Original config restored. No changes were applied to SSH."
    exit 1
fi
ok "SSH config syntax is valid."

info "Restarting SSH service..."
systemctl daemon-reload
ssh_restart

for i in {1..10}; do
    systemctl is-active --quiet "$SSH_SERVICE" && break
    sleep 1
done

pause_and_clear

# ══ STAGE 7 — Final Verification ═════════════════════════════
header "🔍  Stage 7 — Final Verification"

if systemctl is-active --quiet "$SSH_SERVICE"; then
    ok "SSH Service: ${BOLD_WHITE}Active${RESET}"
else
    err "SSH Service: FAILED"
fi

if ss -tulpn | grep -q ":$SSH_PORT "; then
    ok "Port Check: ${BOLD_WHITE}Listening on ${SSH_PORT}${RESET}"
else
    err "Port Check: Nothing listening on ${SSH_PORT}"
fi

if ufw status | grep -q "$SSH_PORT"; then
    ok "Firewall: ${BOLD_WHITE}Rule Active${RESET}"
else
    err "Firewall: Rule Missing"
fi

pause_and_clear

# ══ STAGE 8 — Finish Screen & Verification ═══════════════════
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD_GREEN}  ✅  SSH HARDENING COMPLETE! 🎉${RESET}\n"
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

printf "\n${BOLD_CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD_CYAN}Command:${RESET}  ${BOLD_YELLOW}ssh -p ${SSH_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
printf "  ${BOLD_CYAN}User:${RESET}     ${WHITE}${REAL_USER}${RESET}\n"
printf "  ${BOLD_CYAN}IP:${RESET}       ${WHITE}${SERVER_IP}${RESET}\n"
printf "  ${BOLD_CYAN}Port:${RESET}     ${WHITE}${SSH_PORT}${RESET}\n"

printf "\n${BOLD_RED}  🛡️  SAFETY RECOVERY:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD_WHITE}Automated:${RESET} ${MAGENTA}If your login fails, simply select${RESET} ${BOLD_WHITE}'n'${RESET}${MAGENTA} below.${RESET}\n"
printf "  ${MAGENTA}             The script will${RESET} ${CYAN}instantly undo${RESET}${MAGENTA} all changes,${RESET}\n"
printf "  ${MAGENTA}             restore your backup, and reset the firewall.${RESET}\n"
printf "\n"
printf "  ${BOLD_WHITE}Backup:${RESET}    ${MAGENTA}Stored at${RESET} ${CYAN}${BACKUP_PATH}${RESET}\n"

printf "\n${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
warn "DO NOT CLOSE THIS WINDOW. Test your login in a NEW terminal now!"
printf "${BOLD_GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

# ══ STAGE 9 — Final Confirmation & Automated Recovery ════════
echo ""
if ask_yes_no "Did the connection test work successfully?" "yes/no"; then
    printf "\n${BOLD_GREEN}🎉  Excellent! System hardened and verified.${RESET}\n"
    printf "  ${MAGENTA}Your backup remains at:${RESET} ${BOLD_YELLOW}${BACKUP_PATH}${RESET}\n"
    printf "  ${MAGENTA}Exiting safely...${RESET}\n\n"
    exit 0
else
    clear
    printf "\n"
    header "⚠️  RESTORING ORIGINAL CONFIGURATION"
    warn "Connection failed. Performing full system rollback..."

    # ── 1. Restore SSH Config — 3-tier fallback ──────────────
    info "Restoring SSH configuration..."

    SSH_RESTORED=false
    if cp "$BACKUP_PATH" /etc/ssh/sshd_config 2>/dev/null && sshd -t 2>/dev/null; then
        info "Backup restored and validated successfully."
        SSH_RESTORED=true
    fi

    if [[ "$SSH_RESTORED" == false ]]; then
        warn "Backup failed or invalid. Reinstalling OpenSSH to restore factory defaults..."
        rm -f /etc/ssh/sshd_config
        if command -v apt-get &>/dev/null; then
            apt-get install --reinstall openssh-server -y > /dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf reinstall openssh-server -y > /dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum reinstall openssh-server -y > /dev/null 2>&1
        fi
        if sshd -t 2>/dev/null; then
            info "Factory default sshd_config restored via package reinstall."
            SSH_RESTORED=true
        fi
    fi

    if [[ "$SSH_RESTORED" == false ]]; then
        warn "Package reinstall failed. Writing hardcoded emergency config..."
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
            info "Emergency fallback config written and validated."
            SSH_RESTORED=true
        else
            warn "Fallback validation failed. Writing bare minimum emergency config..."
            cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
EOF
        fi
    fi

    # ── Restore SSH settings — snapshot or manual override ───
    _restore_ssh_val() {
        local key="$1" val="$2"
        if [[ -n "$val" ]]; then
            if grep -q "^$key" /etc/ssh/sshd_config; then
                sed -i "s/^$key.*/$key $val/" /etc/ssh/sshd_config
            else
                echo "$key $val" >> /etc/ssh/sshd_config
            fi
        else
            sed -i "/^$key/d" /etc/ssh/sshd_config
        fi
    }

    echo ""
    printf "  ${BOLD_CYAN}Pre-script values:${RESET}\n"
    printf "  ${BOLD_CYAN}Port:${RESET}                   ${WHITE}${ORIG_PORT:-not set}${RESET}\n"
    printf "  ${BOLD_CYAN}PubkeyAuthentication:${RESET}   ${WHITE}${ORIG_PUBKEY_AUTH:-not set}${RESET}\n"
    printf "  ${BOLD_CYAN}PasswordAuthentication:${RESET} ${WHITE}${ORIG_PASS_AUTH:-not set}${RESET}\n"
    printf "  ${BOLD_CYAN}PermitRootLogin:${RESET}        ${WHITE}${ORIG_ROOT_LOGIN:-not set}${RESET}\n"
    echo ""

    if ask_yes_no "Manually override recovery settings? (No = restore pre-script values)" "yes/no"; then
        echo ""
        [[ -t 0 && -t 1 ]] && clear
        printf "  ${MAGENTA}You will set each SSH value manually. These will be written to${RESET}\n"
        printf "  ${MAGENTA}${BOLD_WHITE}/etc/ssh/sshd_config${RESET}${MAGENTA} so you can connect again.${RESET}\n\n"
        printf "  ${BOLD_YELLOW}Important:${RESET} ${MAGENTA}Make sure the port you choose matches what your SSH${RESET}\n"
        printf "  ${MAGENTA}client (and VPS firewall, if applicable) is configured to use.${RESET}\n\n"

        # ── Port ─────────────────────────────────────────────
        printf "${BOLD_WHITE}  ┌─ Recovery Port ────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Which port should SSH listen on after the rollback?${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Use the port your SSH client will connect to.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}If unsure, use ${BOLD_WHITE}22${RESET}${MAGENTA} — the universal SSH default.${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Port:${RESET} " RB_PORT
            if [[ "$RB_PORT" =~ ^[0-9]+$ ]] && [[ "$RB_PORT" -ge 1 ]] && [[ "$RB_PORT" -le 65535 ]]; then
                break
            else
                err "Please enter a valid port number between 1 and 65535."
            fi
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── PubkeyAuthentication ─────────────────────────────
        printf "${BOLD_WHITE}  ┌─ Public Key Authentication ───────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Should the server accept SSH key logins?${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Answer ${BOLD_WHITE}yes${RESET}${MAGENTA} if you want to connect using an SSH key.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Answer ${BOLD_WHITE}no${RESET}${MAGENTA} only if you intend to use password login.${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Enable PubkeyAuthentication?${RESET} (yes/no): " RB_PUBKEY
            case "$(echo "$RB_PUBKEY" | tr '[:upper:]' '[:lower:]')" in
                yes|no) break ;;
                *) err "Please type yes or no." ;;
            esac
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── PasswordAuthentication ───────────────────────────
        printf "${BOLD_WHITE}  ┌─ Password Authentication ─────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Should the server accept password logins?${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Answer ${BOLD_WHITE}yes${RESET}${MAGENTA} to allow password-based login as a fallback.${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}If both PubkeyAuthentication and PasswordAuthentication are${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${BOLD_YELLOW}set to no, you will be completely locked out. Be careful.${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Allow PasswordAuthentication?${RESET} (yes/no): " RB_PASS
            case "$(echo "$RB_PASS" | tr '[:upper:]' '[:lower:]')" in
                yes|no) break ;;
                *) err "Please type yes or no." ;;
            esac
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        # ── PermitRootLogin ──────────────────────────────────
        printf "${BOLD_WHITE}  ┌─ Root Login ───────────────────────────────────────────────┐${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Should the root account be allowed to log in directly?${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}Answer ${BOLD_WHITE}yes${RESET}${MAGENTA} only if you need root access and have no other${RESET}\n"
        printf "${BOLD_WHITE}  │${RESET}  ${MAGENTA}sudo-capable user on the server to fall back to.${RESET}\n"
        printf "${BOLD_WHITE}  └───────────────────────────────────────────────────────────┘${RESET}\n"
        while true; do
            read -rp "  ${BOLD_WHITE}Allow PermitRootLogin?${RESET} (yes/no): " RB_ROOT
            case "$(echo "$RB_ROOT" | tr '[:upper:]' '[:lower:]')" in
                yes|no) break ;;
                *) err "Please type yes or no." ;;
            esac
        done
        echo ""
        [[ -t 0 && -t 1 ]] && clear

        RESTORE_PORT="$RB_PORT"
        RESTORE_PUBKEY="$RB_PUBKEY"
        RESTORE_PASS="$RB_PASS"
        RESTORE_ROOT="$RB_ROOT"
        info "Using manually specified recovery values."
    else
        RESTORE_PORT="$ORIG_PORT"
        RESTORE_PUBKEY="$ORIG_PUBKEY_AUTH"
        RESTORE_PASS="$ORIG_PASS_AUTH"
        RESTORE_ROOT="$ORIG_ROOT_LOGIN"
        info "Using pre-script values for recovery."
    fi

    info "Applying recovery settings..."
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $RESTORE_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $RESTORE_PORT" >> /etc/ssh/sshd_config
    fi
    _restore_ssh_val "PubkeyAuthentication"   "${RESTORE_PUBKEY:-no}"
    _restore_ssh_val "PasswordAuthentication" "${RESTORE_PASS:-yes}"
    _restore_ssh_val "PermitRootLogin"        "${RESTORE_ROOT:-yes}"
    sed -i '/^AuthenticationMethods/d' /etc/ssh/sshd_config

    if sshd -t 2>/dev/null; then
        info "SSH settings applied and validated."
    else
        err "sshd config invalid after recovery! Check: sshd -t"
    fi

    # ── 2. Revert Firewall (UFW) ─────────────────────────────
    info "Disabling Firewall (UFW) for safety..."
    ufw delete allow "$SSH_PORT/tcp" > /dev/null 2>&1 || true
    ufw --force disable               > /dev/null 2>&1
    ufw allow "$RESTORE_PORT/tcp"     > /dev/null 2>&1

    # ── 3. Cleanly Disable Fail2Ban ──────────────────────────
    if [[ "$DO_FAIL2BAN" == "yes" ]] && command -v fail2ban-client >/dev/null 2>&1; then
        info "Stopping and disabling Fail2Ban..."
        systemctl stop    fail2ban > /dev/null 2>&1 || true
        systemctl disable fail2ban > /dev/null 2>&1 || true
    fi

    # ── 4. Remove Stealth Mode (if applied) ──────────────────
    if [[ "$DO_STEALTH" == "yes" ]]; then
        info "Removing Stealth Mode (ICMP Drop)..."
        if [[ -f /etc/ufw/before.rules ]]; then
            sed -i '/--icmp-type echo-request -j DROP/d' /etc/ufw/before.rules
        fi
    fi

    # ── 5. Restart Services ──────────────────────────────────
    info "Reloading services to apply rollback..."
    systemctl daemon-reload
    ssh_restart

    for i in {1..10}; do
        systemctl is-active --quiet "$SSH_SERVICE" && break
        sleep 1
    done

    if systemctl is-active --quiet "$SSH_SERVICE"; then
        ok "SSH service is back online."
    else
        err "SSH service FAILED to restart! Check logs with: journalctl -xe"
    fi

    printf "\n${BOLD_RED}🚨  FULL ROLLBACK COMPLETE.${RESET}\n"
    warn "UFW and Fail2Ban have been DISABLED to prevent lockouts."
    printf "  ${MAGENTA}Standard Port 22 is active. Please fix your config and restart the services.${RESET}\n"
    echo ""
    printf "\n${BOLD_CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
    printf "  ────────────────────────────────────────────────────────────\n"
    printf "  ${BOLD_CYAN}Command:${RESET}  ${BOLD_YELLOW}ssh -p ${RESTORE_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
    echo ""
    exit 1
fi
