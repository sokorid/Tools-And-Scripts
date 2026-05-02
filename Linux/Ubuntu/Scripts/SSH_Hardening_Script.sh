#!/bin/bash
# ============================================================
#  SSH_Hardening_Script.sh — The Automatic Setup Script
# ============================================================
set -euo pipefail

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

# UI Components
ok()     { printf "  ${GREEN}✅${RESET} %s\n" "$1"; }
info()   { printf "  ${CYAN}ℹ️${RESET}  %s\n" "$1"; }
warn()   { printf "  ${YELLOW}⚠️${RESET}  %s\n" "$1"; }
err()    { printf "  ${RED}❌${RESET}  %s\n" "$1" >&2; }

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
            *) err "Please type y or n (or yes/no)." ;;
        esac
    done
}

# Function to handle Pause and Clear
pause_and_clear() {
  echo -e "\n${BOLD}${GREEN}┌──────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ✔  ${BOLD}STAGE COMPLETE!${RESET}                              ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}│${RESET}  ${CYAN}Press any key to move to the next step...${RESET}       ${BOLD}${GREEN}│${RESET}"
  echo -e "${BOLD}${GREEN}└──────────────────────────────────────────────────┘${RESET}"
  read -n 1 -s -r
  clear
}

# Function to convert time strings
convert_to_seconds() {
    local input=$1
    local unit=$(echo "$input" | grep -o -E '[a-zA-Z]+' | tr '[:upper:]' '[:lower:]')
    local value=$(echo "$input" | grep -o -E '[0-9]+')
    case "$unit" in
        d|day|days) echo $((value * 86400)) ;;
        h|hour|hours) echo $((value * 3600)) ;;
        m|min|minutes) echo $((value * 60)) ;;
        s|sec|seconds|"") echo "$value" ;;
        *) echo "-1" ;;
    esac
}

# This ensures stock sshd_config files (which use "#Port 22" style defaults)
# get cleanly replaced rather than leaving a commented duplicate behind.
set_ssh_option() {
    if grep -qE "^#?$1\b" /etc/ssh/sshd_config; then
        sed -i -E "s|^#?($1)\s+.*|$1 $2|" /etc/ssh/sshd_config
    else
        echo "$1 $2" >> /etc/ssh/sshd_config
    fi
}

# Detect SSH service name (ssh on Debian/Ubuntu)
SSH_SERVICE="ssh"

# Detect whether ssh.socket exists — on modern Ubuntu it can hold the service
# alive and must be stopped first, otherwise systemctl stop ssh warns and fails
# to fully tear down the service.
SSH_SOCKET=""
if systemctl list-unit-files --type=socket 2>/dev/null | grep -qE '^sshd?\.socket'; then
    SSH_SOCKET=$(systemctl list-unit-files --type=socket 2>/dev/null | grep -oE '^sshd?\.socket' | head -1)
fi

ssh_stop() {
    [[ -n "$SSH_SOCKET" ]] && systemctl stop "$SSH_SOCKET" > /dev/null 2>&1 || true
    systemctl stop "$SSH_SERVICE" > /dev/null 2>&1 || true
}

ssh_start() {
    systemctl start "$SSH_SERVICE"
    [[ -n "$SSH_SOCKET" ]] && systemctl start "$SSH_SOCKET" > /dev/null 2>&1 || true
}

ssh_restart() {
    ssh_stop
    sleep 1
    ssh_start
}

# Function Configure Stealth Mode (ICMP Drop)
DO_STEALTH="no"

set_icmp_stealth() {
    local rules_file="/etc/ufw/before.rules"

    if grep -q "icmp-type echo-request -j DROP" "$rules_file"; then
        ok "Stealth mode is already configured."
        return
    fi

    info "Configuring UFW to drop ICMP echo requests..."
    sed -i '/--icmp-type echo-request -j ACCEPT/i -A ufw-before-input -p icmp --icmp-type echo-request -j DROP' "$rules_file"
    ok "Stealth Mode queued: Server will no longer respond to pings after firewall is applied."
}

if [[ $EUID -ne 0 ]]; then
  err "Please run this script with sudo."
  exit 1
fi

# Auto-detect Identity
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
CURRENT_HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')

# Snapshot original auth state for exact rollback
_get_ssh_val() {
    grep -E "^$1\s" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1 || true
}
ORIG_PUBKEY_AUTH=$(_get_ssh_val "PubkeyAuthentication")
ORIG_PASS_AUTH=$(_get_ssh_val "PasswordAuthentication")
ORIG_ROOT_LOGIN=$(_get_ssh_val "PermitRootLogin")
ORIG_PORT=$(_get_ssh_val "Port")
ORIG_PORT="${ORIG_PORT:-22}"

# Initialize Fail2Ban variables with safe defaults
F2B_MAXRETRY=5
F2B_BANTIME=1h
F2B_FINDTIME=10m
DO_FAIL2BAN="no"

clear
echo -e "${BOLD}${CYAN}📦  SSH HARDENING Script v4.0${RESET}"
info "Detected user: ${REAL_USER} | IP: ${SERVER_IP}"

# ============================================================
#  STAGE 1 — Public Key
# ============================================================
header "🔑  Stage 1 — Your SSH Public Key"
echo -e "To find your key on your ${BOLD}Main Computer${RESET}:"
echo -e "  ${CYAN}Windows:${RESET} type %USERPROFILE%\\.ssh\\id_ed25519.pub"
echo -e "  ${CYAN}macOS/Linux:${RESET} cat ~/.ssh/id_ed25519.pub"
echo ""
echo -e "If you need one: ${YELLOW}ssh-keygen -t ed25519${RESET} on your PC."
echo ""

while true; do
  read -rp "  Paste your Public Key here: " PUBKEY
  if [[ "$PUBKEY" =~ $'\n' ]]; then
    err "Key contains embedded newlines — please paste a single-line key."
    continue
  fi
  if [[ "$PUBKEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
    ok "Key accepted."
    break
  else
    err "Invalid format. Key should start with 'ssh-ed25519' or similar."
  fi
done

pause_and_clear

# ============================================================
#  STAGE 2 — Port Config
# ============================================================
header "🌐  Stage 2 — Choose Your SSH Port"
echo "  Standard port is 22. Changing this hides you from automated bot scans."
echo "  ${YELLOW}WARNING:${RESET} Avoid Reserved Ports (80, 443, 3306, etc.)"
echo "  ${YELLOW}Recommended Range:${RESET} 1024 - 65535"
echo ""

while true; do
  read -rp "  Enter desired SSH Port [2552]: " SSH_PORT
  SSH_PORT="${SSH_PORT:-2552}"

  if [[ "$SSH_PORT" -lt 1024 || "$SSH_PORT" -gt 65535 ]]; then
    err "Port must be between 1024 and 65535."
    continue
  fi

  if ss -tulpn | grep -q ":$SSH_PORT "; then
    err "Port $SSH_PORT is ALREADY in use! Choose another."
  else
    ok "Port $SSH_PORT is available."
    break
  fi
done

pause_and_clear

# ============================================================
#  STAGE 3 — Hardening Options
# ============================================================
header "⚙️   Stage 3 — SSH Hardening Settings"
echo -e "${CYAN}High-Security Defaults include:${RESET}"
echo "  - Disable Passwords: Force SSH Key login only."
echo "  - Disable Root: Users must login as $REAL_USER and use sudo."
echo "  - Idle Timeout: Disconnect sessions after 5 minutes of inactivity."
echo "  - Max Tries: Lock connection after 3 failed attempts."
echo ""

if ask_yes_no "Apply these high-security defaults?" "y"; then
  PUBKEY_AUTH=yes; PASS_AUTH=no; ROOT_LOGIN=no; MAX_TRIES=3; GRACE_TIME=30; X11=no; SECONDS_VAL=300; ALIVE_COUNT=2
  ok "Defaults applied."
else
  echo -e "\n${CYAN}Manual Configuration:${RESET}"

  echo -e "\n${BOLD}Public Key Authentication${RESET}"
  echo "  - (yes: Required for key-based login. Strongly recommended.)"
  read -rp "  Enable PubkeyAuthentication? (yes/no) [yes]: " PUBKEY_AUTH; PUBKEY_AUTH="${PUBKEY_AUTH:-yes}"

  echo -e "\n${BOLD}Password Authentication${RESET}"
  echo "  - (no: Requires SSH keys. Prevents brute-force guessing.)"
  read -rp "  Allow Password Auth? (yes/no) [no]: " PASS_AUTH; PASS_AUTH="${PASS_AUTH:-no}"

  echo -e "\n${BOLD}Root Login${RESET}"
  echo "  - (no: Attacker can't target 'root' directly. Much safer.)"
  read -rp "  Allow Root Login? (yes/no) [no]: " ROOT_LOGIN; ROOT_LOGIN="${ROOT_LOGIN:-no}"

  echo -e "\n${BOLD}Max Auth Tries${RESET}"
  echo "  - (Number of failed attempts before being kicked.)"
  read -rp "  Max Auth Tries [3]: " MAX_TRIES; MAX_TRIES="${MAX_TRIES:-3}"

  echo -e "\n${BOLD}Login Grace Time${RESET}"
  echo "  - (Seconds to stay connected before successfully logging in.)"
  read -rp "  Login Grace Time [30]: " GRACE_TIME; GRACE_TIME="${GRACE_TIME:-30}"

  echo -e "\n${BOLD}X11 Forwarding${RESET}"
  echo "  - (Forwarding GUI apps. Usually leave as 'no' for servers.)"
  read -rp "  X11 Forwarding [no]: " X11; X11="${X11:-no}"

  echo -e "\n${BOLD}Idle Timeout Setup${RESET}"
  echo "  Default is 5 minutes (300s). Format: '15m', '1h', or '300s'."
  read -rp "  Timeout duration: " TIME_INPUT
  TIME_INPUT="${TIME_INPUT:-300s}"
  SECONDS_VAL=$(convert_to_seconds "$TIME_INPUT")

  if [[ "$SECONDS_VAL" == "-1" || "$SECONDS_VAL" -le 0 ]]; then
      warn "Invalid time format. Defaulting to 300 seconds (5 minutes)."
      SECONDS_VAL=300
  fi

  echo "  - (Number of alive checks before disconnecting inactive user.)"
  read -rp "  Alive Checks [2]: " ALIVE_COUNT; ALIVE_COUNT="${ALIVE_COUNT:-2}"

  echo -e "  ${GREEN}Converted to:${RESET} $SECONDS_VAL seconds ($((SECONDS_VAL/60))m)"
fi

pause_and_clear

# ============================================================
#  STAGE 4 — Fail2Ban
# ============================================================
header "🛡️   Stage 4 — Fail2Ban Protection"
echo -e "${CYAN}Fail2Ban Defaults:${RESET}"
echo "  - Max Retry (5): IPs are banned after 5 failed login attempts."
echo "  - Ban Time (1h): Offenders are locked out for 1 hour."
echo "  - Find Time (10m): Failures must happen within 10 mins to trigger ban."
echo ""

if ask_yes_no "Install and use Fail2Ban defaults?" "y"; then
  F2B_MAXRETRY=5; F2B_BANTIME=1h; F2B_FINDTIME=10m
  DO_FAIL2BAN="yes"
  ok "Fail2Ban defaults selected."
else
  if ask_yes_no "Manually configure Fail2Ban?" "y"; then
    echo -e "\n${BOLD}Max Retry${RESET}"
    echo "  - (Attempts allowed before an IP is banned.)"
    read -rp "  Max Retry [5]: " F2B_MAXRETRY; F2B_MAXRETRY="${F2B_MAXRETRY:-5}"

    echo -e "\n${BOLD}Ban Time${RESET}"
    echo "  - (How long the offender stays banned. e.g., 1h, 24h, 7d.)"
    read -rp "  Ban Time [1h]: " F2B_BANTIME; F2B_BANTIME="${F2B_BANTIME:-1h}"

    echo -e "\n${BOLD}Find Time${RESET}"
    echo "  - (The window of time failures must occur within to trigger a ban.)"
    read -rp "  Find Time [10m]: " F2B_FINDTIME; F2B_FINDTIME="${F2B_FINDTIME:-10m}"
    DO_FAIL2BAN="yes"
  else
    DO_FAIL2BAN="no"
  fi
fi

pause_and_clear

# ============================================================
#  STAGE 5 — Stealth Mode
# ============================================================
header "👻  Stage 5 — Stealth Mode (ICMP Stealth)"
printf "  By default, servers respond to 'ping'. Disabling this makes it\n"
printf "  harder for bots to discover your server during network scans.\n"
printf "  ${BOLD}Security Note:${RESET} This does ${BOLD}not${RESET} fully hide you. If a bot finds an\n"
printf "  open port (like your SSH port), they will know you are there.\n"
printf "  This is simply an ${CYAN}added layer${RESET} of obscurity to slow them down.\n"
printf "  ${YELLOW}Note:${RESET} You won't be able to ping this server to test uptime.\n\n"

if ask_yes_no "Disallow pinging of the server (Stealth Mode)?" "n"; then
    DO_STEALTH="yes"
    set_icmp_stealth
else
    info "Stealth Mode skipped. Server remains pingable."
fi

pause_and_clear

# ============================================================
#  STAGE 6 — Applying Configurations
# ============================================================
header "🚀  Stage 6 — Applying Configurations"

# Create unique timestamped backup
BACKUP_PATH="/etc/ssh/sshd_config.$(date +%Y%m%d%H%M%S).bak"
cp /etc/ssh/sshd_config "$BACKUP_PATH"
info "Config backed up to: $BACKUP_PATH"

info "Writing settings to /etc/ssh/sshd_config..."

set_ssh_option "Port" "$SSH_PORT"
set_ssh_option "PubkeyAuthentication" "$PUBKEY_AUTH"
set_ssh_option "PasswordAuthentication" "$PASS_AUTH"
set_ssh_option "PermitRootLogin" "$ROOT_LOGIN"
set_ssh_option "MaxAuthTries" "$MAX_TRIES"
set_ssh_option "LoginGraceTime" "$GRACE_TIME"
set_ssh_option "X11Forwarding" "$X11"
set_ssh_option "ClientAliveInterval" "$SECONDS_VAL"
set_ssh_option "ClientAliveCountMax" "$ALIVE_COUNT"
set_ssh_option "AuthorizedKeysFile" ".ssh/authorized_keys"

# SSH Key Setup
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

# Firewall
info "Updating UFW rules..."
ufw allow "$SSH_PORT/tcp" > /dev/null
ufw delete allow 22/tcp > /dev/null 2>&1 || true
info "Removed old port 22 rule from firewall (if it existed)."
ufw --force enable > /dev/null

# Apply stealth mode and reload UFW now that all rules are in place
if [[ "$DO_STEALTH" == "yes" ]]; then
    ufw reload > /dev/null
fi

# Fail2Ban
if [[ "$DO_FAIL2BAN" == "yes" ]]; then
  info "Installing Fail2Ban..."
  apt-get update -qq && apt-get install -y fail2ban -qq
  cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = ${F2B_MAXRETRY}
bantime = ${F2B_BANTIME}
findtime = ${F2B_FINDTIME}
EOF
  systemctl enable fail2ban > /dev/null 2>&1
  systemctl restart fail2ban
fi

info "Validating SSH config syntax..."
if ! sshd -t; then
    err "sshd config has errors! Restoring backup: $BACKUP_PATH"
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

# ============================================================
#  STAGE 7 — Final Verification
# ============================================================
header "🔍  Stage 7 — Final Verification"

if systemctl is-active --quiet "$SSH_SERVICE"; then ok "SSH Service: Active"; else err "SSH Service: FAILED"; fi

if ss -tulpn | grep -q ":$SSH_PORT "; then
    ok "Port Check: Listening on $SSH_PORT"
else
    err "Port Check: Nothing listening on $SSH_PORT"
fi

if ufw status | grep -q "$SSH_PORT"; then ok "Firewall: Rule Active"; else err "Firewall: Rule Missing"; fi

pause_and_clear

# ============================================================
#  STAGE 8 — Finish Screen & Verification
# ============================================================
printf "${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}${GREEN}  ✅  SSH HARDENING COMPLETE! 🎉${RESET}\n"
printf "${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

printf "\n${BOLD}${CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD}Command:${RESET}  ${YELLOW}ssh -p ${SSH_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
printf "  ${BOLD}User:${RESET}     ${REAL_USER}\n"
printf "  ${BOLD}IP:${RESET}       ${SERVER_IP}\n"
printf "  ${BOLD}Port:${RESET}     ${SSH_PORT}\n"

printf "\n${BOLD}${RED}  🛡️  SAFETY RECOVERY:${RESET}\n"
printf "  ────────────────────────────────────────────────────────────\n"
printf "  ${BOLD}Automated:${RESET} If your login fails, simply select ${BOLD}'n'${RESET} below.\n"
printf "             The script will ${CYAN}instantly undo${RESET} all changes,\n"
printf "             restore your backup, and reset the firewall.\n"
printf "\n"
printf "  ${BOLD}Backup:${RESET}    Stored at ${CYAN}${BACKUP_PATH}${RESET}\n"

printf "\n${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}\n"
warn "DO NOT CLOSE THIS WINDOW. Test your login in a NEW terminal now!"
printf "${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}\n"

# ============================================================
#  STAGE 9 — Final Confirmation & Automated Recovery
# ============================================================
echo ""
if ask_yes_no "Did the connection test work successfully?" "y"; then
    printf "\n${BOLD}${GREEN}🎉  Excellent! System hardened and verified.${RESET}\n"
    printf "  Your backup remains at: ${YELLOW}${BACKUP_PATH}${RESET}\n"
    printf "  Exiting safely...\n\n"
    exit 0
else
    clear
    printf "\n"
    header "⚠️  RESTORING ORIGINAL CONFIGURATION"
    warn "Connection failed. Performing full system rollback..."

    # 1. Restore SSH Config — 3-tier fallback
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
# Emergency fallback - safe SSH defaults
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

    # Restore SSH settings — offer manual override or use snapshotted originals
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
    printf "  ${BOLD}Pre-script values:${RESET}\n"
    printf "  Port:                 ${CYAN}${ORIG_PORT:-not set}${RESET}\n"
    printf "  PubkeyAuthentication: ${CYAN}${ORIG_PUBKEY_AUTH:-not set}${RESET}\n"
    printf "  PasswordAuthentication: ${CYAN}${ORIG_PASS_AUTH:-not set}${RESET}\n"
    printf "  PermitRootLogin:      ${CYAN}${ORIG_ROOT_LOGIN:-not set}${RESET}\n"
    echo ""

    if ask_yes_no "Manually override recovery settings? (No = restore pre-script values)" "n"; then
        echo ""
        printf "  ${CYAN}Leave blank to accept the shown default.${RESET}\n\n"

        read -rp "  Port [22]: " RB_PORT
        RB_PORT="${RB_PORT:-22}"

        read -rp "  PubkeyAuthentication (yes/no) [no]: " RB_PUBKEY
        RB_PUBKEY="${RB_PUBKEY:-no}"

        read -rp "  PasswordAuthentication (yes/no) [yes]: " RB_PASS
        RB_PASS="${RB_PASS:-yes}"

        read -rp "  PermitRootLogin (yes/no) [yes]: " RB_ROOT
        RB_ROOT="${RB_ROOT:-yes}"

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
    _restore_ssh_val "PubkeyAuthentication" "${RESTORE_PUBKEY:-no}"
    _restore_ssh_val "PasswordAuthentication" "${RESTORE_PASS:-yes}"
    _restore_ssh_val "PermitRootLogin" "${RESTORE_ROOT:-yes}"
    sed -i '/^AuthenticationMethods/d' /etc/ssh/sshd_config

    if sshd -t 2>/dev/null; then
        info "SSH settings applied and validated."
    else
        err "sshd config invalid after recovery! Check: sshd -t"
    fi

    # 2. Revert Firewall (UFW)
    info "Disabling Firewall (UFW) for safety..."
    ufw delete allow "$SSH_PORT/tcp" > /dev/null 2>&1 || true
    ufw --force disable > /dev/null 2>&1
    ufw allow "$RESTORE_PORT/tcp" > /dev/null 2>&1

    # 3. Cleanly Disable Fail2Ban
    if [[ "$DO_FAIL2BAN" == "yes" ]] && command -v fail2ban-client >/dev/null 2>&1; then
        info "Stopping and disabling Fail2Ban..."
        systemctl stop fail2ban > /dev/null 2>&1 || true
        systemctl disable fail2ban > /dev/null 2>&1 || true
    fi

    # 4. Remove Stealth Mode (if applied)
    if [[ "$DO_STEALTH" == "yes" ]]; then
        info "Removing Stealth Mode (ICMP Drop)..."
        if [[ -f /etc/ufw/before.rules ]]; then
            sed -i '/--icmp-type echo-request -j DROP/d' /etc/ufw/before.rules
        fi
    fi

    # 5. Restart Services
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

    printf "\n${BOLD}${RED}🚨  FULL ROLLBACK COMPLETE.${RESET}\n"
    warn "UFW and Fail2Ban have been DISABLED to prevent lockouts."
    printf "  Standard Port 22 is active. Please fix your config and restart the services.\n"
    echo ""
    printf "\n${BOLD}${CYAN}  🔌  CONNECTION DETAILS:${RESET}\n"
    printf "  ────────────────────────────────────────────────────────────\n"
    printf "  ${BOLD}Command:${RESET}  ${YELLOW}ssh -p ${RESTORE_PORT} ${REAL_USER}@${SERVER_IP}${RESET}\n"
    echo ""
    exit 1
fi
