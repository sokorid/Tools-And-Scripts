#!/bin/bash
# ════════════════════════════════════════════════════════════
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════
#  ssh_key_generator.sh — Quickly generates Ed25519 or RSA
#  keys for your servers
# ════════════════════════════════════════════════════════════

set -euo pipefail

SSH_DIR="$HOME/.ssh"

# ── Script version ───────────────────────────────────────────
SCRIPT_VERSION="1.3"

# ════════════════════════════════════════════════════════════
#  COLORS & STYLES
# ════════════════════════════════════════════════════════════

# ── Non-interactive terminal fallback: strip all colors ──────
if [ -t 1 ]; then
    RESET=$(printf '\033[0m')
    BOLD=$(printf '\033[1m')

    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m')
    CYAN=$(printf '\033[0;36m')
    WHITE=$(printf '\033[0;37m')
    MAGENTA=$(printf '\033[0;35m')

    BOLD_RED=$(printf '\033[1;31m')
    BOLD_GREEN=$(printf '\033[1;32m')
    BOLD_YELLOW=$(printf '\033[1;33m')
    BOLD_CYAN=$(printf '\033[1;36m')
    BOLD_WHITE=$(printf '\033[1;37m')
    BOLD_MAGENTA=$(printf '\033[1;35m')
else
    RESET="" BOLD=""
    RED="" GREEN="" YELLOW="" CYAN="" WHITE="" MAGENTA=""
    BOLD_RED="" BOLD_GREEN="" BOLD_YELLOW="" BOLD_CYAN="" BOLD_WHITE="" BOLD_MAGENTA=""
fi

# ════════════════════════════════════════════════════════════
#  UI HELPERS
# ════════════════════════════════════════════════════════════

ok()   { printf "  ${BOLD_GREEN}✅  %s${RESET}\n" "$*"; }
info() { printf "  ${BOLD_CYAN}ℹ️   %s${RESET}\n" "$*"; }
warn() { printf "  ${BOLD_YELLOW}⚠️   %s${RESET}\n" "$*"; }
err()  { printf "  ${BOLD_RED}❌  %s${RESET}\n" "$*" >&2; }

# ── Section rule ─────────────────────────────────────────────
header() {
    local title="$1"
    printf "\n  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n"
    printf "  ${BOLD_WHITE}%s${RESET}\n" "$title"
    printf "  ${BOLD_CYAN}════════════════════════════════════════════${RESET}\n\n"
}

# ── Thin rule ────────────────────────────────────────────────
rule() {
    printf "  ${CYAN}────────────────────────────────────────────${RESET}\n"
}

# ── Yes / No prompt ──────────────────────────────────────────
ask_yes_no() {
    local prompt="$1"
    local answer
    while true; do
        printf "  ${BOLD_WHITE}%s [${BOLD_WHITE}y/n${RESET}${BOLD_WHITE}]:${RESET} " "$prompt"
        read -r answer
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     warn "Please enter y or n." ;;
        esac
    done
}

# ── Navigation helpers ───────────────────────────────────────
_check_nav() {
    # ── Returns 0 (go back) if input is "back" or "exit" ────
    case "${1,,}" in back|exit) return 0 ;; esac
    return 1
}

press_enter_menu() {
    printf "\n  ${MAGENTA}Press ENTER to return to the menu...${RESET}\n"
    read -r _
    main_menu
}

# ════════════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════════════
main_menu() {
    clear
    printf "\n  ${BOLD_CYAN}📦  SSH Key Generator  v${SCRIPT_VERSION}${RESET}\n"
    header "🔐  SSH Key Generator"

    printf "  ${WHITE}Generates a secure SSH key for connecting to${RESET}\n"
    printf "  ${WHITE}servers without a password and better security.${RESET}\n\n"
    rule

    printf "  ${BOLD_WHITE}Choose your key type:${RESET}\n\n"

    printf "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Ed25519${RESET}  ${BOLD_GREEN}✅ Recommended${RESET}\n"
    printf "       ${MAGENTA}⚡ Modern, fast, and highly secure.${RESET}\n\n"

    printf "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}RSA 4096${RESET}\n"
    printf "       ${MAGENTA}🔑 Older standard. Use if Ed25519 is unsupported.${RESET}\n\n"

    printf "  ${BOLD_YELLOW}[3]${RESET}  ${BOLD_WHITE}List Existing Keys${RESET}\n"
    printf "       ${MAGENTA}📋 View any SSH keys already on this machine.${RESET}\n\n"

    printf "  ${BOLD_RED}[4]${RESET}  ${BOLD_WHITE}Exit${RESET}\n\n"
    rule
    printf "\n"

    local choice
    printf "  ${BOLD_WHITE}Your choice (1, 2, 3 or 4):${RESET} "
    read -r choice

    case "$choice" in
        1) gen_ed25519 ;;
        2) gen_rsa ;;
        3) list_keys ;;
        4) exit_script ;;
        *)
            printf "\n"
            err "Invalid choice. Please enter 1, 2, 3 or 4."
            press_enter_menu
            ;;
    esac
}

# ════════════════════════════════════════════════════════════
#  GENERATE Ed25519
# ════════════════════════════════════════════════════════════
gen_ed25519() {
    KEY_TYPE="Ed25519"
    KEY_FILE="$SSH_DIR/id_ed25519"
    KEYGEN_ARGS="-t ed25519"
    name_key
}

# ════════════════════════════════════════════════════════════
#  GENERATE RSA
# ════════════════════════════════════════════════════════════
gen_rsa() {
    KEY_TYPE="RSA 4096"
    KEY_FILE="$SSH_DIR/id_rsa"
    KEYGEN_ARGS="-t rsa -b 4096"
    name_key
}

# ════════════════════════════════════════════════════════════
#  LIST EXISTING KEYS
# ════════════════════════════════════════════════════════════
list_keys() {
    clear
    header "📋  Existing SSH Keys"

    # ── Count .pub files ─────────────────────────────────────
    local count=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] && count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        warn "No SSH keys found on this machine."
        printf "\n"
        press_enter_menu
        return
    fi

    info "Found ${BOLD_WHITE}${count}${RESET}${BOLD_CYAN} key(s) in ${BOLD_WHITE}${SSH_DIR}${RESET}${BOLD_CYAN}."
    printf "\n"
    rule

    local index=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] || continue
        index=$((index + 1))

        local KEY_TYPE KEY_COMMENT KEY_MATERIAL FINGERPRINT TMPKEY
        KEY_TYPE=$(awk '{print $1}' "$pub_file")
        KEY_COMMENT=$(awk '{print $3}' "$pub_file")
        KEY_MATERIAL=$(awk '{print $2}' "$pub_file")

        TMPKEY=$(mktemp)
        cp "$pub_file" "$TMPKEY"
        FINGERPRINT=$(ssh-keygen -lf "$TMPKEY" 2>/dev/null || printf "unable to read fingerprint")
        rm -f "$TMPKEY"

        printf "\n  ${BOLD_WHITE}Key #%d${RESET}\n" "$index"
        printf "  ${BOLD_CYAN}Name:${RESET}        ${WHITE}%s${RESET}\n"        "$(basename "${pub_file%.pub}")"
        printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n"        "$KEY_TYPE"
        printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n"        "${KEY_COMMENT:-"(none)"}"
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n"  "$FINGERPRINT"
        printf "  ${BOLD_CYAN}Preview:${RESET}     ${MAGENTA}%s...%s${RESET}\n" \
            "${KEY_MATERIAL:0:20}" "${KEY_MATERIAL: -10}"
        rule
    done

    press_enter_menu
}

# ════════════════════════════════════════════════════════════
#  NAME THE KEY
# ════════════════════════════════════════════════════════════
name_key() {
    clear
    header "✏️   Key File Name"

    printf "  ${WHITE}You can give your key a custom name, or press${RESET}\n"
    printf "  ${WHITE}ENTER to use the default name.${RESET}\n\n"

    printf "  ${BOLD_CYAN}Default:${RESET}  ${WHITE}%s${RESET}\n" "$KEY_FILE"
    printf "  ${BOLD_CYAN}Example:${RESET}  ${MAGENTA}my_server  →  %s/my_server${RESET}\n\n" "$SSH_DIR"
    printf "  ${MAGENTA}Type ${BOLD_WHITE}back${RESET}${MAGENTA} or ${BOLD_WHITE}exit${RESET}${MAGENTA} to return to the main menu.${RESET}\n\n"

    rule
    printf "  ${BOLD_CYAN}Existing Key Names${RESET}\n"
    rule

    local any_keys=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] || continue
        any_keys=1
        printf "  ${BOLD_GREEN}🗝️   ${WHITE}%s${RESET}\n" "$(basename "${pub_file%.pub}")"
    done
    [ "$any_keys" -eq 0 ] && printf "  ${MAGENTA}None found${RESET}\n"

    printf "\n"
    rule
    printf "\n"

    local custom_name
    printf "  ${BOLD_WHITE}Custom name (or press ENTER for default):${RESET} "
    read -r custom_name

    if _check_nav "$custom_name"; then
        main_menu
        return
    fi

    if [ -n "$custom_name" ]; then
        printf "\n"
        rule
        printf "  ${BOLD_CYAN}Append Encryption Type?${RESET}\n"
        rule
        printf "  ${WHITE}Append the encryption type to your key name${RESET}\n"
        printf "  ${WHITE}for easy identification?${RESET}\n\n"

        if [ "$KEY_TYPE" = "Ed25519" ]; then
            printf "  ${MAGENTA}Example: ${BOLD_WHITE}%s_ed25519${RESET}\n\n" "$custom_name"
        else
            printf "  ${MAGENTA}Example: ${BOLD_WHITE}%s_rsa4096${RESET}\n\n" "$custom_name"
        fi

        printf "  ${BOLD_GREEN}[1]${RESET}  ${WHITE}Yes — append encryption type${RESET}\n"
        printf "  ${BOLD_YELLOW}[2]${RESET}  ${WHITE}No  — keep name as typed${RESET}\n\n"
        printf "  ${MAGENTA}Type ${BOLD_WHITE}back${RESET}${MAGENTA} or ${BOLD_WHITE}exit${RESET}${MAGENTA} to return to the main menu.${RESET}\n\n"
        rule
        printf "\n"

        local append_choice
        printf "  ${BOLD_WHITE}Your choice (1 or 2):${RESET} "
        read -r append_choice

        if _check_nav "$append_choice"; then
            main_menu
            return
        fi

        if [ "$append_choice" = "1" ]; then
            if [ "$KEY_TYPE" = "Ed25519" ]; then
                custom_name="${custom_name}_ed25519"
            else
                custom_name="${custom_name}_rsa4096"
            fi
        fi

        KEY_FILE="$SSH_DIR/$custom_name"
    fi

    check_exists
}

# ════════════════════════════════════════════════════════════
#  CHECK IF KEY ALREADY EXISTS
# ════════════════════════════════════════════════════════════
check_exists() {
    clear

    if [ -f "$KEY_FILE" ]; then
        show_existing
    else
        generate_key
    fi
}

# ════════════════════════════════════════════════════════════
#  GENERATE NEW KEY
# ════════════════════════════════════════════════════════════
generate_key() {
    info "Creating a new ${KEY_TYPE} key..."
    printf "\n"
    rule
    printf "  ${BOLD_CYAN}🔒  About Passphrases${RESET}\n"
    rule
    printf "  ${WHITE}ssh-keygen will now ask you to set a passphrase.${RESET}\n\n"
    printf "  ${WHITE}A passphrase is an optional password that protects${RESET}\n"
    printf "  ${WHITE}your key file. If someone steals your key file,${RESET}\n"
    printf "  ${WHITE}they still cannot use it without the passphrase.${RESET}\n\n"
    printf "  ${BOLD_GREEN}↵${RESET}  ${WHITE}Press ENTER twice to skip (no passphrase)${RESET}\n"
    printf "  ${BOLD_YELLOW}🔐${RESET}  ${WHITE}Or type a strong password to protect your key${RESET}\n\n"
    printf "  ${MAGENTA}💡 Tip: For automated scripts or servers, skipping${RESET}\n"
    printf "  ${MAGENTA}   the passphrase is common. For personal keys,${RESET}\n"
    printf "  ${MAGENTA}   setting one is strongly recommended.${RESET}\n"
    rule

    printf "\n  ${MAGENTA}Press ENTER to continue...${RESET}\n"
    read -r _

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # shellcheck disable=SC2086
    if ! ssh-keygen $KEYGEN_ARGS -f "$KEY_FILE"; then
        printf "\n"
        err "Key generation failed. Please try again."
        press_enter_menu
        return
    fi

    clear
    header "✅  Key Created Successfully"

    ok "Your ${KEY_TYPE} key has been created."
    printf "\n"
    rule
    printf "  ${BOLD_CYAN}Key Location${RESET}\n"
    rule
    printf "  ${BOLD_CYAN}Private key:${RESET}  ${WHITE}%s${RESET}\n" "$KEY_FILE"
    printf "  ${BOLD_CYAN}Public key:${RESET}   ${WHITE}%s.pub${RESET}\n\n" "$KEY_FILE"
    printf "  ${BOLD_RED}🚫  Keep your PRIVATE key secret. Never share it.${RESET}\n"
    printf "  ${BOLD_GREEN}📤  Copy your PUBLIC key to any server you want access to.${RESET}\n\n"

    rule
    printf "  ${BOLD_CYAN}Public Key${RESET}\n"
    rule
    printf "\n  ${WHITE}%s${RESET}\n\n" "$(cat "${KEY_FILE}.pub")"

    rule
    printf "  ${BOLD_CYAN}Fingerprint${RESET}\n"
    rule
    printf "  ${MAGENTA}A fingerprint is a short unique ID for your key.${RESET}\n"
    printf "  ${MAGENTA}Use it to verify the right server, or identify${RESET}\n"
    printf "  ${MAGENTA}which key is which if you have several.${RESET}\n\n"
    printf "  ${BOLD_YELLOW}%s${RESET}\n\n" "$(ssh-keygen -lf "${KEY_FILE}.pub")"
    rule
    ok "All done! Copy the public key above to your server."
    rule

    press_enter_menu
}

# ════════════════════════════════════════════════════════════
#  SHOW EXISTING KEY
# ════════════════════════════════════════════════════════════
show_existing() {
    header "⚠️   Key Already Exists"

    warn "A ${KEY_TYPE} key already exists. No new key was created."
    printf "\n"
    rule
    printf "  ${BOLD_CYAN}Key Location${RESET}\n"
    rule
    printf "  ${BOLD_CYAN}Private key:${RESET}  ${WHITE}%s${RESET}\n" "$KEY_FILE"
    printf "  ${BOLD_CYAN}Public key:${RESET}   ${WHITE}%s.pub${RESET}\n\n" "$KEY_FILE"

    rule
    printf "  ${BOLD_CYAN}Public Key${RESET}\n"
    rule
    printf "\n  ${WHITE}%s${RESET}\n\n" "$(cat "${KEY_FILE}.pub")"

    rule
    printf "  ${BOLD_CYAN}Fingerprint${RESET}\n"
    rule
    printf "  ${MAGENTA}A fingerprint is a short unique ID for your key.${RESET}\n"
    printf "  ${MAGENTA}Use it to verify the right server, or identify${RESET}\n"
    printf "  ${MAGENTA}which key is which if you have several.${RESET}\n\n"
    printf "  ${BOLD_YELLOW}%s${RESET}\n\n" "$(ssh-keygen -lf "${KEY_FILE}.pub")"

    rule
    info "To generate a key with a different name,"
    info "run the script again and choose a custom name."
    rule

    press_enter_menu
}

# ════════════════════════════════════════════════════════════
#  EXIT
# ════════════════════════════════════════════════════════════
exit_script() {
    clear
    header "🔐  SSH Key Generator"
    printf "  ${BOLD_WHITE}👋  Goodbye!${RESET}\n\n"
    rule
    printf "\n"
    exit 0
}

# ════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════
main_menu
