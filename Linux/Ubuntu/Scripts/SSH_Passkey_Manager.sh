#!/bin/bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# ============================================================
#  SSH_Passkey_Manager.sh — SSH Authorized Keys Manager
# ============================================================
set -euo pipefail

SCRIPT_VERSION="1.0"

# ── Colors and UI ────────────────────────────────────────────
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
WHITE=$(printf '\033[0;37m')
BOLD=$(printf '\033[1m')
DIM=$(printf '\033[0;35m')
BOLD_RED=$(printf '\033[1;31m')
BOLD_GREEN=$(printf '\033[1;32m')
BOLD_YELLOW=$(printf '\033[1;33m')
BOLD_CYAN=$(printf '\033[1;36m')
BOLD_WHITE=$(printf '\033[1;37m')
RESET=$(printf '\033[0m')

if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]]; then
    RED=''; GREEN=''; YELLOW=''; CYAN=''; WHITE=''; BOLD=''; DIM=''
    BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''; BOLD_CYAN=''; BOLD_WHITE=''; RESET=''
fi

# ── UI Components ────────────────────────────────────────────
ok()   { printf "  ${BOLD_GREEN}✅${RESET} %s\n" "$1"; }
info() { printf "  ${BOLD_CYAN}ℹ️${RESET}  %s\n" "$1"; }
warn() { printf "  ${BOLD_YELLOW}⚠️${RESET}  %s\n" "$1"; }
err()  { printf "  ${BOLD_RED}❌${RESET}  %s\n" "$1" >&2; }

header() {
    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  %s${RESET}\n" "$1"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n\n"
}

ask_yes_no() {
    local hint="${2:-y/n}"
    while true; do
        read -rp "  $1 [${BOLD_WHITE}${hint}${RESET}]: " input
        case "$(echo "$input" | tr '[:upper:]' '[:lower:]')" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     err "Please type y or n (or yes/no)." ;;
        esac
    done
}

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "Please run this script with sudo."
    exit 1
fi

# ── Resolve the real user and their authorized_keys path ─────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
AUTH_KEYS="$USER_HOME/.ssh/authorized_keys"

# ── Ensure the .ssh dir and file exist ───────────────────────
mkdir -p "$USER_HOME/.ssh"
touch "$AUTH_KEYS"
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$AUTH_KEYS"

# ── Count valid keys (used in menu and functions) ────────────
count_keys() {
    grep -cE "^(ssh-|ecdsa-|sk-)" "$AUTH_KEYS" 2>/dev/null || true
}

# ============================================================
#  OPTION 1 — Add a Public Key
# ============================================================
add_key() {
    clear
    header "🔑  Add SSH Public Key"
    echo -e "  ${WHITE}To find your key on your ${BOLD_WHITE}Main Computer${RESET}${WHITE}:${RESET}"
    echo -e "  ${BOLD_CYAN}Windows:${RESET}     ${DIM}type %USERPROFILE%\\.ssh\\id_ed25519.pub${RESET}"
    echo -e "  ${BOLD_CYAN}macOS/Linux:${RESET} ${DIM}cat ~/.ssh/id_ed25519.pub${RESET}"
    echo ""
    echo -e "  ${WHITE}If you need one: ${BOLD_YELLOW}ssh-keygen -t ed25519${RESET} ${WHITE}on your PC.${RESET}"
    echo ""
    info "You can add one key at a time. Run this option again to add more."
    info "Type ${BOLD_WHITE}exit${RESET}${BOLD_CYAN} at any prompt to return to the main menu."
    echo ""

    while true; do
        read -rp "  ${BOLD_WHITE}Paste your Public Key here:${RESET} " PUBKEY

        [[ "$PUBKEY" == "exit" || "$PUBKEY" == "back" ]] && main_menu && return

        # ── Guard: blank ──────────────────────────────────────
        if [[ -z "$PUBKEY" ]]; then
            err "No key entered. Please paste a valid SSH public key."
            echo ""
            continue
        fi

        # ── Guard: no embedded newlines ───────────────────────
        if [[ "$PUBKEY" =~ $'\n' ]]; then
            err "Key contains embedded newlines — please paste a single-line key."
            echo ""
            continue
        fi

        # ── Guard: structural prefix check ───────────────────
        if [[ ! "$PUBKEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519|sk-ecdsa-sha2-nistp256) ]]; then
            err "Invalid format. Key must start with a valid type (e.g. ${BOLD_WHITE}ssh-ed25519${RESET}, ${BOLD_WHITE}ssh-rsa${RESET})."
            echo ""
            continue
        fi

        # ── Guard: cryptographic validation ──────────────────
        TMPKEY=$(mktemp)
        echo "$PUBKEY" > "$TMPKEY"
        if ! ssh-keygen -l -f "$TMPKEY" &>/dev/null; then
            rm -f "$TMPKEY"
            err "Key failed cryptographic validation. It may be truncated or corrupted."
            echo ""
            continue
        fi
        rm -f "$TMPKEY"

        # ── Guard: duplicate check ────────────────────────────
        NEW_KEY_MATERIAL=$(echo "$PUBKEY" | awk '{print $2}')
        if grep -q "$NEW_KEY_MATERIAL" "$AUTH_KEYS" 2>/dev/null; then
            echo ""
            warn "This key already exists in authorized_keys — duplicate not added."
            echo ""
            if ask_yes_no "Would you like to add a different key?" "yes/no"; then
                echo ""
                continue
            else
                main_menu
                return
            fi
        fi

        # ── All checks passed — append ────────────────────────
        printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
        echo ""
        ok "Key accepted, cryptographically validated, and added to authorized_keys."

        TMPKEY=$(mktemp)
        echo "$PUBKEY" > "$TMPKEY"
        FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY" 2>/dev/null)
        rm -f "$TMPKEY"
        info "Fingerprint: ${BOLD_YELLOW}${FINGERPRINT}${RESET}"
        echo ""
        break
    done

    # ── Offer to add another ──────────────────────────────────
    echo ""
    if ask_yes_no "Would you like to add another key?" "yes/no"; then
        echo ""
        add_key
    else
        main_menu
    fi
}

# ============================================================
#  OPTION 2 — List All Keys
# ============================================================
list_keys() {
    clear
    header "📋  Current Authorized Keys"

    local count
    count=$(count_keys)

    if [[ "$count" -eq 0 ]]; then
        warn "No keys found in authorized_keys."
        echo ""
        read -rp "  ${DIM}Press Enter to return to the main menu...${RESET}" _
        main_menu
        return
    fi

    info "Found ${BOLD_WHITE}${count}${RESET} key(s) for user ${BOLD_WHITE}${REAL_USER}${RESET}:"
    echo ""
    printf "  ${BOLD_CYAN}────────────────────────────────────────────────────────────${RESET}\n"

    local index=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        index=$((index + 1))
        KEY_TYPE=$(echo "$line"    | awk '{print $1}')
        KEY_COMMENT=$(echo "$line" | awk '{print $3}')
        KEY_MATERIAL=$(echo "$line" | awk '{print $2}')

        TMPKEY=$(mktemp)
        echo "$line" > "$TMPKEY"
        FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY" 2>/dev/null || echo "unable to read fingerprint")
        rm -f "$TMPKEY"

        printf "\n  ${BOLD_WHITE}Key #%d${RESET}\n" "$index"
        printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n" "$KEY_TYPE"
        printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n" "${KEY_COMMENT:-"(none)"}"
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n" "$FINGERPRINT"
        printf "  ${BOLD_CYAN}Preview:${RESET}     ${DIM}%s...%s${RESET}\n" \
            "${KEY_MATERIAL:0:20}" "${KEY_MATERIAL: -10}"
        printf "  ${BOLD_CYAN}────────────────────────────────────────────────────────────${RESET}\n"
    done < "$AUTH_KEYS"

    echo ""
    read -rp "  ${DIM}Press Enter to return to the main menu...${RESET}" _
    main_menu
}

# ============================================================
#  OPTION 3 — Remove a Key
# ============================================================
remove_key() {
    clear
    header "🗑️   Remove an Authorized Key"

    local count
    count=$(count_keys)

    if [[ "$count" -eq 0 ]]; then
        warn "No keys found in authorized_keys. Nothing to remove."
        echo ""
        read -rp "  ${DIM}Press Enter to return to the main menu...${RESET}" _
        main_menu
        return
    fi

    echo -e "  ${WHITE}Paste the exact public key you wish to remove.${RESET}"
    echo -e "  ${BOLD_CYAN}Tip:${RESET} ${DIM}Use Option 2 to view and copy the key first.${RESET}"
    info "Type ${BOLD_WHITE}exit${RESET}${BOLD_CYAN} to return to the main menu."
    echo ""

    while true; do
        read -rp "  ${BOLD_WHITE}Paste the key to remove:${RESET} " DEL_KEY

        [[ "$DEL_KEY" == "exit" || "$DEL_KEY" == "back" ]] && main_menu && return

        if [[ -z "$DEL_KEY" ]]; then
            err "No key entered. Please paste the key you wish to remove."
            echo ""
            continue
        fi

        DEL_KEY_MATERIAL=$(echo "$DEL_KEY" | awk '{print $2}')

        if [[ -z "$DEL_KEY_MATERIAL" ]]; then
            err "Could not parse the key. Make sure you paste the full public key."
            echo ""
            continue
        fi

        # ── Check the key actually exists ────────────────────
        if ! grep -q "$DEL_KEY_MATERIAL" "$AUTH_KEYS" 2>/dev/null; then
            echo ""
            err "That key was not found in authorized_keys."
            warn "Make sure you pasted the full key exactly as it appears."
            echo ""
            if ask_yes_no "Try again?" "yes/no"; then
                echo ""
                continue
            else
                main_menu
                return
            fi
        fi

        # ── Key found — show details and confirm ──────────────
        MATCHED_LINE=$(grep "$DEL_KEY_MATERIAL" "$AUTH_KEYS")
        TMPKEY=$(mktemp)
        echo "$MATCHED_LINE" > "$TMPKEY"
        FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY" 2>/dev/null || echo "unable to read fingerprint")
        rm -f "$TMPKEY"

        KEY_TYPE=$(echo "$MATCHED_LINE"    | awk '{print $1}')
        KEY_COMMENT=$(echo "$MATCHED_LINE" | awk '{print $3}')

        echo ""
        printf "  ${BOLD_YELLOW}══════════════════════════════════════════════════════════${RESET}\n"
        printf "  ${BOLD_YELLOW}  ⚠️   KEY FOUND — REVIEW BEFORE DELETING${RESET}\n"
        printf "  ${BOLD_YELLOW}══════════════════════════════════════════════════════════${RESET}\n"
        echo ""
        printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n" "$KEY_TYPE"
        printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n" "${KEY_COMMENT:-"(none)"}"
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n" "$FINGERPRINT"
        echo ""

        if [[ "$count" -eq 1 ]]; then
            printf "  ${BOLD_RED}🚨  WARNING: This is the ONLY key in authorized_keys!${RESET}\n"
            printf "  ${RED}   Removing it may lock you out of the server entirely\n"
            printf "       if password authentication is disabled.${RESET}\n"
            echo ""
        fi

        printf "  ${BOLD_RED}You may lose access to this server if this is your only\n"
        printf "  method of access. This action cannot be undone.${RESET}\n"
        echo ""

        if ! ask_yes_no "Are you absolutely sure you want to delete this key?" "yes/no"; then
            echo ""
            info "Deletion cancelled. No changes were made."
            echo ""
            read -rp "  ${DIM}Press Enter to return to the main menu...${RESET}" _
            main_menu
            return
        fi

        # ── Atomic delete ─────────────────────────────────────
        TMPFILE=$(mktemp)
        grep -v "$DEL_KEY_MATERIAL" "$AUTH_KEYS" > "$TMPFILE" || true
        mv "$TMPFILE" "$AUTH_KEYS"
        chown "$REAL_USER:$REAL_USER" "$AUTH_KEYS"
        chmod 600 "$AUTH_KEYS"

        echo ""
        ok "Key removed successfully from authorized_keys."
        info "Fingerprint of removed key: ${BOLD_YELLOW}${FINGERPRINT}${RESET}"
        echo ""
        break
    done

    read -rp "  ${DIM}Press Enter to return to the main menu...${RESET}" _
    main_menu
}

# ============================================================
#  OPTION 4 — Exit
# ============================================================
exit_script() {
    clear
    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  🔑  SSH Passkey Manager v${SCRIPT_VERSION}${RESET}\n"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    echo ""
    ok "Goodbye!"
    echo ""
    exit 0
}

# ============================================================
#  Main Menu
# ============================================================
main_menu() {
    clear
    printf "${BOLD_CYAN}🔑  SSH Passkey Manager v${SCRIPT_VERSION}${RESET}\n"

    local KEY_COUNT
    KEY_COUNT=$(count_keys)

    printf "\n${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD_CYAN}  ${WHITE}Managing keys for:${RESET} ${BOLD_WHITE}%s${RESET}  ${BOLD_CYAN}│${RESET}  ${WHITE}Keys stored:${RESET} ${BOLD_WHITE}%s${RESET}\n" \
        "$REAL_USER" "$KEY_COUNT"
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n\n"

    printf "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}🔑  Add a new SSH Public Key${RESET}\n"
    printf "       ${DIM}Paste, validate, and store a new key.${RESET}\n"
    echo ""
    printf "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}📋  List all keys in authorized_keys${RESET}\n"
    printf "       ${DIM}View every key currently on file.${RESET}\n"
    echo ""
    printf "  ${BOLD_YELLOW}[3]${RESET}  ${BOLD_WHITE}🗑️  Remove a key from authorized_keys${RESET}\n"
    printf "       ${DIM}Permanently delete a stored key.${RESET}\n"
    echo ""
    printf "  ${BOLD_RED}[4]${RESET}  ${BOLD_WHITE}🚪  Exit${RESET}\n"
    echo ""
    printf "${BOLD_CYAN}════════════════════════════════════════════════════════════${RESET}\n"
    echo ""

    read -rp "  Enter your choice [${BOLD_WHITE}1-4${RESET}]: " CHOICE

    case "$CHOICE" in
        1) add_key ;;
        2) list_keys ;;
        3) remove_key ;;
        4) exit_script ;;
        *)
            echo ""
            err "Invalid choice. Please enter 1, 2, 3, or 4."
            sleep 1
            main_menu
            ;;
    esac
}

# ── Entry point ───────────────────────────────────────────────
main_menu
