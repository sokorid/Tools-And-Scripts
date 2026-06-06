#!/bin/bash
# ════════════════════════════════════════════════════════════
# Author:  sokor | github.com/sokorid | codeberg.org/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ════════════════════════════════════════════════════════════
# SSH_Passkey_Manager.sh — SSH Authorized Keys Manager
# ════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_VERSION="1.2"

# ── Temp-file registry — cleaned on exit/interrupt ───────────
TMPFILES=()
_cleanup() { rm -f "${TMPFILES[@]}"; }
trap _cleanup EXIT INT TERM

_mktemp() {
    local f
    f=$(mktemp)
    TMPFILES+=("$f")
    printf '%s' "$f"
}

# ── Colors: strip if non-interactive or dumb terminal ────────
if [[ -t 1 && "$TERM" != "dumb" ]]; then
    RESET=$(printf '\033[0m');  BOLD=$(printf '\033[1m')
    RED=$(printf '\033[0;31m'); GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m'); CYAN=$(printf '\033[0;36m')
    WHITE=$(printf '\033[0;37m'); MAGENTA=$(printf '\033[0;35m')
    BOLD_RED=$(printf '\033[1;31m'); BOLD_GREEN=$(printf '\033[1;32m')
    BOLD_YELLOW=$(printf '\033[1;33m'); BOLD_CYAN=$(printf '\033[1;36m')
    BOLD_WHITE=$(printf '\033[1;37m'); BOLD_MAGENTA=$(printf '\033[1;35m')
else
    RESET="" BOLD=""
    RED="" GREEN="" YELLOW="" CYAN="" WHITE="" MAGENTA=""
    BOLD_RED="" BOLD_GREEN="" BOLD_YELLOW="" BOLD_CYAN="" BOLD_WHITE="" BOLD_MAGENTA=""
fi

# ── UI helpers ───────────────────────────────────────────────
ok()   { printf "  ${BOLD_GREEN}✅  %s${RESET}\n" "$*"; }
info() { printf "  ${BOLD_CYAN}ℹ️   %s${RESET}\n" "$*"; }
warn() { printf "  ${BOLD_YELLOW}⚠️   %s${RESET}\n" "$*"; }
err()  { printf "  ${BOLD_RED}❌  %s${RESET}\n" "$*" >&2; }

header() {
    printf "\n  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n"
    printf "  ${BOLD_WHITE}%s${RESET}\n" "$1"
    printf "  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n\n"
}

rule() { printf "  ${CYAN}────────────────────────────────────────────${RESET}\n"; }

ask_yes_no() {
    local prompt="$1" answer
    while true; do
        printf "  ${BOLD_WHITE}%s [y/n]:${RESET} " "$prompt"
        read -r answer
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     err "Please type y or n (or yes/no)." ;;
        esac
    done
}

_check_nav() { case "${1,,}" in back|exit) return 0 ;; esac; return 1; }

press_enter_menu() {
    printf "\n  ${MAGENTA}Press ENTER to return to the menu...${RESET}\n"
    read -r _
    main_menu
}

# ── Root check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "Please run this script with sudo."
    exit 1
fi

# ── Resolve real user and paths ──────────────────────────────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"

if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    err "Could not determine the real user. Please run via: sudo -u <username> $0"
    err "Do not run directly as root without sudo from a user account."
    exit 1
fi

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
AUTH_KEYS="$USER_HOME/.ssh/authorized_keys"

# ── Symlink guard — never write through a symlink ────────────
if [[ -L "$USER_HOME/.ssh" || -L "$AUTH_KEYS" ]]; then
    err "Security error: .ssh or authorized_keys is a symlink. Aborting."
    exit 1
fi

mkdir -p "$USER_HOME/.ssh"
touch "$AUTH_KEYS"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.ssh" "$AUTH_KEYS"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$AUTH_KEYS"

# ── Count valid keys ─────────────────────────────────────────
count_keys() { grep -cE "^(ssh-|ecdsa-|sk-)" "$AUTH_KEYS" 2>/dev/null || true; }

# ── Exact field-2 match helpers ──────────────────────────────
_key_exists()  { awk -v m="$1" '$2 == m { found=1; exit } END { exit !found }' "$AUTH_KEYS"; }
_key_count()   { awk -v m="$1" '$2 == m { n++ } END { print n+0 }' "$AUTH_KEYS"; }
_key_getline() { awk -v m="$1" '$2 == m { print; exit }' "$AUTH_KEYS"; }
_key_delete()  { awk -v m="$1" '$2 != m' "$AUTH_KEYS"; }

# ── Indexed key list — global, always reset before use ───────
KEY_LIST=()

_load_key_list() {
    KEY_LIST=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        KEY_LIST+=("$line")
    done < "$AUTH_KEYS"
}

_print_key_list() {
    local i=0
    for line in "${KEY_LIST[@]}"; do
        i=$((i + 1))
        local KEY_TYPE KEY_COMMENT KEY_MATERIAL FINGERPRINT TMPKEY
        KEY_TYPE=$(printf '%s' "$line"     | awk '{print $1}')
        KEY_COMMENT=$(printf '%s' "$line"  | awk '{print $3}')
        KEY_MATERIAL=$(printf '%s' "$line" | awk '{print $2}')

        TMPKEY=$(_mktemp)
        printf '%s\n' "$line" > "$TMPKEY"
        FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY" 2>/dev/null || printf "unable to read fingerprint")

        printf "\n  ${BOLD_WHITE}Key #%d${RESET}\n" "$i"
        printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n"        "$KEY_TYPE"
        printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n"        "${KEY_COMMENT:-"(none)"}"
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n"  "$FINGERPRINT"
        printf "  ${BOLD_CYAN}Preview:${RESET}     ${MAGENTA}%s...%s${RESET}\n" \
            "${KEY_MATERIAL:0:20}" "${KEY_MATERIAL: -10}"
        rule
    done
}

# ════════════════════════════════════════════════════════════
#  OPTION 1 — Add a Public Key
# ════════════════════════════════════════════════════════════
add_key() {
    clear
    header "🔑  Add SSH Public Key"

    printf "  ${WHITE}To find your key on your ${BOLD_WHITE}Main Computer${RESET}${WHITE}:${RESET}\n"
    printf "  ${BOLD_CYAN}Windows:${RESET}     ${MAGENTA}type %%USERPROFILE%%\\.ssh\\id_ed25519.pub${RESET}\n"
    printf "  ${BOLD_CYAN}macOS/Linux:${RESET} ${MAGENTA}cat ~/.ssh/id_ed25519.pub${RESET}\n\n"
    printf "  ${WHITE}If you need one: ${BOLD_YELLOW}ssh-keygen -t ed25519${RESET}${WHITE} on your PC.${RESET}\n\n"
    info "You can add one key at a time. Run this option again to add more."
    info "Type ${BOLD_WHITE}exit${RESET}${BOLD_CYAN} at any prompt to return to the main menu."
    printf "\n"

    while true; do
        printf "  ${BOLD_WHITE}Paste your Public Key here:${RESET} "
        read -r PUBKEY

        if _check_nav "$PUBKEY"; then main_menu; return; fi

        if [[ -z "$PUBKEY" ]]; then
            err "No key entered. Please paste a valid SSH public key."; printf "\n"; continue
        fi

        if [[ ${#PUBKEY} -gt 8192 ]]; then
            err "Input too long. Please paste a single valid SSH public key."; printf "\n"; continue
        fi

        if [[ "$PUBKEY" =~ $'\n' ]]; then
            err "Key contains embedded newlines — please paste a single-line key."; printf "\n"; continue
        fi

        if [[ ! "$PUBKEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519|sk-ecdsa-sha2-nistp256) ]]; then
            err "Invalid format. Key must start with a valid type (e.g. ${BOLD_WHITE}ssh-ed25519${RESET}, ${BOLD_WHITE}ssh-rsa${RESET})."; printf "\n"; continue
        fi

        local TMPKEY
        TMPKEY=$(_mktemp)
        printf '%s\n' "$PUBKEY" > "$TMPKEY"
        if ! ssh-keygen -l -f "$TMPKEY" &>/dev/null; then
            err "Key failed cryptographic validation. It may be truncated or corrupted."; printf "\n"; continue
        fi

        local NEW_KEY_MATERIAL
        NEW_KEY_MATERIAL=$(printf '%s' "$PUBKEY" | awk '{print $2}')

        if _key_exists "$NEW_KEY_MATERIAL"; then
            printf "\n"
            warn "This key already exists in authorized_keys — duplicate not added."
            printf "\n"
            if ask_yes_no "Would you like to add a different key?"; then
                printf "\n"; continue
            else
                main_menu; return
            fi
        fi

        printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
        printf "\n"
        ok "Key accepted, cryptographically validated, and added to authorized_keys."

        local TMPKEY2 FINGERPRINT
        TMPKEY2=$(_mktemp)
        printf '%s\n' "$PUBKEY" > "$TMPKEY2"
        FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY2" 2>/dev/null)
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n\n" "$FINGERPRINT"
        break
    done

    printf "\n"
    if ask_yes_no "Would you like to add another key?"; then
        printf "\n"; add_key
    else
        main_menu
    fi
}

# ════════════════════════════════════════════════════════════
#  OPTION 2 — List All Keys
# ════════════════════════════════════════════════════════════
list_keys() {
    clear
    header "📋  Current Authorized Keys"

    local count
    count=$(count_keys)

    if [[ "$count" -eq 0 ]]; then
        warn "No keys found in authorized_keys."; printf "\n"; press_enter_menu; return
    fi

    _load_key_list
    info "Found ${BOLD_WHITE}${count}${RESET}${BOLD_CYAN} key(s) for user ${BOLD_WHITE}${REAL_USER}${RESET}${BOLD_CYAN}."
    printf "\n"
    rule
    _print_key_list

    press_enter_menu
}

# ════════════════════════════════════════════════════════════
#  OPTION 3 — Remove a Key
# ════════════════════════════════════════════════════════════

# ── Confirm and perform deletion; returns 0 on delete, 1 on cancel ──
_confirm_and_delete() {
    local MATCHED_LINE="$1"
    local count="$2"

    local TMPKEY FINGERPRINT KEY_TYPE KEY_COMMENT DEL_KEY_MATERIAL
    KEY_TYPE=$(printf '%s' "$MATCHED_LINE"         | awk '{print $1}')
    KEY_COMMENT=$(printf '%s' "$MATCHED_LINE"      | awk '{print $3}')
    DEL_KEY_MATERIAL=$(printf '%s' "$MATCHED_LINE" | awk '{print $2}')

    TMPKEY=$(_mktemp)
    printf '%s\n' "$MATCHED_LINE" > "$TMPKEY"
    FINGERPRINT=$(ssh-keygen -l -f "$TMPKEY" 2>/dev/null || printf "unable to read fingerprint")

    printf "\n"
    printf "  ${BOLD_YELLOW}════════════════════════════════════════════${RESET}\n"
    printf "  ${BOLD_YELLOW}  ⚠️   KEY FOUND — REVIEW BEFORE DELETING${RESET}\n"
    printf "  ${BOLD_YELLOW}════════════════════════════════════════════${RESET}\n\n"
    printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n"       "$KEY_TYPE"
    printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n"       "${KEY_COMMENT:-"(none)"}"
    printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n" "$FINGERPRINT"
    printf "\n"

    if [[ "$count" -eq 1 ]]; then
        printf "  ${BOLD_RED}🚨  WARNING: This is the ONLY key in authorized_keys!${RESET}\n"
        printf "  ${RED}    Removing it may lock you out of the server entirely${RESET}\n"
        printf "  ${RED}    if password authentication is disabled.${RESET}\n\n"
    fi

    printf "  ${BOLD_RED}You may lose access to this server if this is your only${RESET}\n"
    printf "  ${BOLD_RED}method of access. This action cannot be undone.${RESET}\n\n"

    if ! ask_yes_no "Are you absolutely sure you want to delete this key?"; then
        printf "\n"; info "Deletion cancelled. No changes were made."; printf "\n"
        return 1
    fi

    local TMPFILE
    TMPFILE=$(_mktemp)
    _key_delete "$DEL_KEY_MATERIAL" > "$TMPFILE"
    mv "$TMPFILE" "$AUTH_KEYS"
    chown "$REAL_USER:$REAL_USER" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    printf "\n"
    ok "Key removed successfully from authorized_keys."
    printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n\n" "$FINGERPRINT"
    return 0
}

remove_key() {
    clear
    header "🗑️   Remove an Authorized Key"

    local count
    count=$(count_keys)

    if [[ "$count" -eq 0 ]]; then
        warn "No keys found in authorized_keys. Nothing to remove."; printf "\n"; press_enter_menu; return
    fi

    _load_key_list

    info "Found ${BOLD_WHITE}${count}${RESET}${BOLD_CYAN} key(s) for user ${BOLD_WHITE}${REAL_USER}${RESET}${BOLD_CYAN}."
    printf "\n"
    rule
    _print_key_list
    printf "\n"

    printf "  ${BOLD_CYAN}How would you like to select the key to remove?${RESET}\n\n"
    printf "  ${BOLD_GREEN}[#]${RESET}   ${BOLD_WHITE}Type a key number${RESET} ${WHITE}(e.g. ${BOLD_YELLOW}1${RESET}${WHITE}, ${BOLD_YELLOW}2${RESET}${WHITE}, ${BOLD_YELLOW}3${RESET}${WHITE}...)${RESET}\n"
    printf "  ${BOLD_CYAN}[key]${RESET} ${BOLD_WHITE}Paste the full public key${RESET}\n"
    info "Type ${BOLD_WHITE}exit${RESET}${BOLD_CYAN} to return to the main menu."
    printf "\n"

    local mat_count
    while true; do
        printf "  ${BOLD_WHITE}Your choice (number or key):${RESET} "
        read -r INPUT

        if _check_nav "$INPUT"; then main_menu; return; fi

        if [[ -z "$INPUT" ]]; then
            err "No input. Type a key number or paste the full public key."; printf "\n"; continue
        fi

        if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
            local idx
            idx=$(( INPUT - 1 ))
            if [[ "$idx" -lt 0 || "$idx" -ge "${#KEY_LIST[@]}" ]]; then
                err "Invalid number. Please enter a number between 1 and ${#KEY_LIST[@]}."; printf "\n"; continue
            fi

            local MATCHED_LINE="${KEY_LIST[$idx]}"
            mat_count=$(_key_count "$(printf '%s' "$MATCHED_LINE" | awk '{print $2}')")
            if [[ "$mat_count" -gt 1 ]]; then
                err "Ambiguous match: ${mat_count} entries share that key material. File may be corrupt."
                err "Please inspect authorized_keys manually before proceeding."
                printf "\n"; press_enter_menu; return
            fi

            _confirm_and_delete "$MATCHED_LINE" "$count" || true
            break

        else
            if [[ ${#INPUT} -gt 8192 ]]; then
                err "Input too long. Please paste a single valid SSH public key."; printf "\n"; continue
            fi

            local DEL_KEY_MATERIAL
            DEL_KEY_MATERIAL=$(printf '%s' "$INPUT" | awk '{print $2}')

            if [[ -z "$DEL_KEY_MATERIAL" ]]; then
                err "Could not parse the key. Make sure you paste the full public key."; printf "\n"; continue
            fi

            if ! _key_exists "$DEL_KEY_MATERIAL"; then
                printf "\n"
                err "That key was not found in authorized_keys."
                warn "Make sure you pasted the full key exactly as it appears."
                printf "\n"
                if ask_yes_no "Try again?"; then printf "\n"; continue; else main_menu; return; fi
            fi

            mat_count=$(_key_count "$DEL_KEY_MATERIAL")
            if [[ "$mat_count" -gt 1 ]]; then
                err "Ambiguous match: ${mat_count} entries share that key material. File may be corrupt."
                err "Please inspect authorized_keys manually before proceeding."
                printf "\n"; press_enter_menu; return
            fi

            local MATCHED_LINE
            MATCHED_LINE=$(_key_getline "$DEL_KEY_MATERIAL")
            _confirm_and_delete "$MATCHED_LINE" "$count" || true
            break
        fi
    done

    press_enter_menu
}

# ════════════════════════════════════════════════════════════
#  OPTION 4 — Exit
# ════════════════════════════════════════════════════════════
exit_script() {
    clear; header "🔑  SSH Passkey Manager"
    ok "Goodbye!"; printf "\n"; exit 0
}

# ════════════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════════════
main_menu() {
    clear
    local KEY_COUNT
    KEY_COUNT=$(count_keys)

    printf "\n  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n"
    printf "  ${BOLD_WHITE}🔑  SSH Passkey Manager  v%s${RESET}\n" "$SCRIPT_VERSION"
    printf "  ${BOLD_CYAN}────────────────────────────────────────────${RESET}\n"
    printf "  ${WHITE}User:${RESET}  ${BOLD_WHITE}%-13s${RESET} ${BOLD_CYAN}│${RESET} ${WHITE}Keys stored:${RESET}  ${BOLD_WHITE}%s${RESET}\n" \
        "$REAL_USER" "$KEY_COUNT"
    printf "  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n\n"
    printf "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Add a new SSH Public Key${RESET}\n"
    printf "       ${MAGENTA}Paste, validate, and store a new key.${RESET}\n\n"
    printf "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}List all keys in authorized_keys${RESET}\n"
    printf "       ${MAGENTA}View every key currently on file.${RESET}\n\n"
    printf "  ${BOLD_YELLOW}[3]${RESET}  ${BOLD_WHITE}Remove a key from authorized_keys${RESET}\n"
    printf "       ${MAGENTA}Select by number or paste the full key.${RESET}\n\n"
    printf "  ${BOLD_RED}[4]${RESET}  ${BOLD_WHITE}Exit${RESET}\n\n"
    printf "  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n\n"
    printf "  ${BOLD_WHITE}Your choice (1-4):${RESET} "
    read -r CHOICE

    case "$CHOICE" in
        1) add_key ;;
        2) list_keys ;;
        3) remove_key ;;
        4) exit_script ;;
        *)
            printf "\n"
            err "Invalid choice. Please enter 1, 2, 3, or 4."
            sleep 1; main_menu ;;
    esac
}

# ── Entry point ───────────────────────────────────────────────
main_menu
