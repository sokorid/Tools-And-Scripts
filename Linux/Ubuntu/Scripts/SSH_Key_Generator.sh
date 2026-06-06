#!/bin/bash
# ════════════════════════════════════════════════════════════
# Author:  sokor | github.com/sokorid | codeberg.org/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ════════════════════════════════════════════════════════════
# ssh_key_generator.sh — Generates Ed25519 or RSA keys
# ════════════════════════════════════════════════════════════

set -euo pipefail

SSH_DIR="$HOME/.ssh"
SCRIPT_VERSION="1.4"

# ── Colors: strip if non-interactive ────────────────────────
if [ -t 1 ]; then
    RESET=$(printf '\033[0m');   BOLD=$(printf '\033[1m')
    RED=$(printf '\033[0;31m');  GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m'); CYAN=$(printf '\033[0;36m')
    WHITE=$(printf '\033[0;37m'); MAGENTA=$(printf '\033[0;35m')
    BOLD_RED=$(printf '\033[1;31m');   BOLD_GREEN=$(printf '\033[1;32m')
    BOLD_YELLOW=$(printf '\033[1;33m'); BOLD_CYAN=$(printf '\033[1;36m')
    BOLD_WHITE=$(printf '\033[1;37m'); BOLD_MAGENTA=$(printf '\033[1;35m')
else
    RESET="" BOLD="" RED="" GREEN="" YELLOW="" CYAN="" WHITE="" MAGENTA=""
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

# Returns 0 if input is "back" or "exit"
_check_nav() { case "${1,,}" in back|exit) return 0 ;; esac; return 1; }

_validate_name() {
    local name="$1"
    if [[ "$name" == .* ]]; then
        err "Name cannot start with a dot."
        return 1
    fi
    if [[ "$name" =~ [^a-zA-Z0-9_.\-] ]]; then
        err "Name can only contain letters, numbers, hyphens, underscores, and dots."
        return 1
    fi
    return 0
}

_sanitize_comment() {
    printf '%s' "$1" | tr -d '\000-\037\177'
}

# ════════════════════════════════════════════════════════════
#  MAIN LOOP
# ════════════════════════════════════════════════════════════
_NEXT_ACTION="main_menu"

_run_loop() {
    while true; do
        case "$_NEXT_ACTION" in
            main_menu)   _NEXT_ACTION="main_menu"; main_menu ;;
            exit_script) exit_script ;;
            *)           _NEXT_ACTION="main_menu" ;;
        esac
    done
}

_return_to_menu() {
    printf "\n  ${MAGENTA}Press ENTER to return to the menu...${RESET}\n"
    read -r _
    _NEXT_ACTION="main_menu"
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
    printf "\n  ${BOLD_WHITE}Your choice (1, 2, 3 or 4):${RESET} "
    local choice
    read -r choice

    case "$choice" in
        1) gen_ed25519 ;;
        2) gen_rsa ;;
        3) list_keys ;;
        4) _NEXT_ACTION="exit_script" ;;
        *) printf "\n"; err "Invalid choice. Please enter 1, 2, 3 or 4."; _return_to_menu ;;
    esac
}

# ════════════════════════════════════════════════════════════
#  KEY TYPE SETUP
# ════════════════════════════════════════════════════════════
gen_ed25519() {
    KEY_TYPE="Ed25519"
    KEY_FILE="$SSH_DIR/id_ed25519"
    KEYGEN_ARGS=(-t ed25519)
    name_key
}

gen_rsa() {
    KEY_TYPE="RSA 4096"
    KEY_FILE="$SSH_DIR/id_rsa"
    KEYGEN_ARGS=(-t rsa -b 4096)
    name_key
}

# ════════════════════════════════════════════════════════════
#  LIST EXISTING KEYS
# ════════════════════════════════════════════════════════════
list_keys() {
    clear
    header "📋  Existing SSH Keys"

    local count=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] && count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        warn "No SSH keys found on this machine."
        printf "\n"
        _return_to_menu
        return
    fi

    info "Found ${BOLD_WHITE}${count}${RESET}${BOLD_CYAN} key(s) in ${BOLD_WHITE}${SSH_DIR}${RESET}${BOLD_CYAN}."
    printf "\n"
    rule

    local index=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] || continue
        index=$((index + 1))

        local KEY_TYPE KEY_COMMENT KEY_MATERIAL FINGERPRINT
        KEY_TYPE=$(awk '{print $1}' "$pub_file")
        KEY_COMMENT=$(awk '{print $3}' "$pub_file")
        KEY_MATERIAL=$(awk '{print $2}' "$pub_file")
        FINGERPRINT=$(ssh-keygen -lf "$pub_file" 2>/dev/null || printf "unable to read fingerprint")

        printf "\n  ${BOLD_WHITE}Key #%d${RESET}\n" "$index"
        printf "  ${BOLD_CYAN}Name:${RESET}        ${WHITE}%s${RESET}\n"        "$(basename "${pub_file%.pub}")"
        printf "  ${BOLD_CYAN}Type:${RESET}        ${WHITE}%s${RESET}\n"        "$KEY_TYPE"
        printf "  ${BOLD_CYAN}Comment:${RESET}     ${WHITE}%s${RESET}\n"        "${KEY_COMMENT:-"(none)"}"
        printf "  ${BOLD_CYAN}Fingerprint:${RESET} ${BOLD_YELLOW}%s${RESET}\n"  "$FINGERPRINT"
        printf "  ${BOLD_CYAN}Preview:${RESET}     ${MAGENTA}%s...%s${RESET}\n" \
            "${KEY_MATERIAL:0:20}" "${KEY_MATERIAL: -10}"
        rule
    done

    _return_to_menu
}

# ════════════════════════════════════════════════════════════
#  NAME THE KEY
# ════════════════════════════════════════════════════════════
name_key() {
    while true; do
        clear
        header "✏️   Key File Name"
        printf "  ${WHITE}Give your key a custom name, or press ENTER for the default.${RESET}\n\n"
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
        printf "\n  ${BOLD_WHITE}Custom name (or press ENTER for default):${RESET} "
        local custom_name
        read -r custom_name

        if _check_nav "$custom_name"; then _NEXT_ACTION="main_menu"; return; fi

        # Use default name
        if [ -z "$custom_name" ]; then
            break
        fi

        # Validate name before accepting
        if ! _validate_name "$custom_name"; then
            printf "\n"
            warn "Please try again."
            printf "\n  ${MAGENTA}Press ENTER to retry...${RESET}\n"
            read -r _
            continue
        fi

        # Offer to append encryption type
        printf "\n"
        rule
        printf "  ${BOLD_CYAN}Append Encryption Type?${RESET}\n"
        rule
        printf "  ${WHITE}Append the encryption type to your key name for easy identification?${RESET}\n\n"
        if [ "$KEY_TYPE" = "Ed25519" ]; then
            printf "  ${MAGENTA}Example: ${BOLD_WHITE}%s_ed25519${RESET}\n\n" "$custom_name"
        else
            printf "  ${MAGENTA}Example: ${BOLD_WHITE}%s_rsa4096${RESET}\n\n" "$custom_name"
        fi
        printf "  ${BOLD_GREEN}[1]${RESET}  ${WHITE}Yes — append encryption type${RESET}\n"
        printf "  ${BOLD_YELLOW}[2]${RESET}  ${WHITE}No  — keep name as typed${RESET}\n\n"
        printf "  ${MAGENTA}Type ${BOLD_WHITE}back${RESET}${MAGENTA} or ${BOLD_WHITE}exit${RESET}${MAGENTA} to return to the main menu.${RESET}\n\n"
        rule
        printf "\n  ${BOLD_WHITE}Your choice (1 or 2):${RESET} "
        local append_choice
        read -r append_choice

        if _check_nav "$append_choice"; then _NEXT_ACTION="main_menu"; return; fi

        if [ "$append_choice" = "1" ]; then
            [ "$KEY_TYPE" = "Ed25519" ] && custom_name="${custom_name}_ed25519" || custom_name="${custom_name}_rsa4096"
        fi

        KEY_FILE="$SSH_DIR/$custom_name"
        break
    done

    check_exists
}

# ════════════════════════════════════════════════════════════
#  CHECK IF KEY ALREADY EXISTS
# ════════════════════════════════════════════════════════════
check_exists() {
    clear
    [ -f "$KEY_FILE" ] && show_existing || generate_key
}

# ════════════════════════════════════════════════════════════
#  CHOOSE KEY COMMENT
# ════════════════════════════════════════════════════════════
choose_comment() {
    _NEXT_ACTION="proceed"
    clear
    header "🏷️   Key Comment (-C)"
    printf "  ${WHITE}A comment is a label embedded in your public key to help identify it.${RESET}\n"
    printf "  ${WHITE}It has no effect on security.${RESET}\n\n"
    rule
    printf "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Default${RESET}  ${BOLD_GREEN}✅ Recommended${RESET}\n"
    printf "       ${MAGENTA}Uses your username and machine name — best for personal use.${RESET}\n"
    printf "       ${MAGENTA}Example: ${BOLD_WHITE}$(whoami)@$(hostname)${RESET}\n\n"
    printf "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}Custom comment${RESET}\n"
    printf "       ${MAGENTA}Type any label. Best for GitHub or shared services.${RESET}\n"
    printf "       ${MAGENTA}Common examples: your@email.com, work-laptop, github-personal${RESET}\n\n"
    printf "  ${MAGENTA}Type ${BOLD_WHITE}back${RESET}${MAGENTA} or ${BOLD_WHITE}exit${RESET}${MAGENTA} to return to the main menu.${RESET}\n\n"
    rule
    printf "\n  ${BOLD_WHITE}Your choice (1 or 2):${RESET} "
    local comment_choice
    read -r comment_choice

    if _check_nav "$comment_choice"; then _NEXT_ACTION="main_menu"; return; fi

    if [ "$comment_choice" = "1" ]; then
        KEY_COMMENT="$(whoami)@$(hostname)"
        return
    fi

    printf "\n  ${BOLD_WHITE}Enter your comment:${RESET} "
    local custom_comment
    read -r custom_comment

    if _check_nav "$custom_comment"; then _NEXT_ACTION="main_menu"; return; fi

    # Sanitize: strip control characters and newlines
    local sanitized
    sanitized=$(_sanitize_comment "$custom_comment")

    [ -z "$sanitized" ] && KEY_COMMENT="$(whoami)@$(hostname)" || KEY_COMMENT="$sanitized"
}

# ════════════════════════════════════════════════════════════
#  GENERATE NEW KEY
# ════════════════════════════════════════════════════════════
generate_key() {
    info "Creating a new ${KEY_TYPE} key..."
    printf "\n"
    choose_comment

    # If user navigated back during choose_comment, abort key gen
    [ "$_NEXT_ACTION" = "main_menu" ] && return

    clear
    rule
    printf "  ${BOLD_CYAN}🔒  About Passphrases${RESET}\n"
    rule
    printf "  ${WHITE}ssh-keygen will ask you to set a passphrase — an optional password${RESET}\n"
    printf "  ${WHITE}that protects your key file if it's ever stolen.${RESET}\n\n"
    printf "  ${BOLD_GREEN}↵${RESET}  ${WHITE}Press ENTER twice to skip (no passphrase)${RESET}\n"
    printf "  ${BOLD_YELLOW}🔐${RESET}  ${WHITE}Or type a strong password to protect your key${RESET}\n\n"
    printf "  ${MAGENTA}💡 For automated scripts/servers, skipping is common.${RESET}\n"
    printf "  ${MAGENTA}   For personal keys, a passphrase is strongly recommended.${RESET}\n"
    rule
    printf "\n  ${MAGENTA}Press ENTER to continue...${RESET}\n"
    read -r _

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    if ! ssh-keygen "${KEYGEN_ARGS[@]}" -f "$KEY_FILE" -C "$KEY_COMMENT"; then
        printf "\n"
        err "Key generation failed. Please try again."
        _return_to_menu
        return
    fi

    clear
    header "✅  Key Created Successfully"
    ok "Your ${KEY_TYPE} key has been created."
    printf "\n"
    _show_key_info
    _return_to_menu
}

# ════════════════════════════════════════════════════════════
#  SHOW EXISTING KEY
# ════════════════════════════════════════════════════════════
show_existing() {
    header "⚠️   Key Already Exists"
    warn "A ${KEY_TYPE} key already exists. No new key was created."
    printf "\n"
    _show_key_info
    rule
    info "To generate a key with a different name, run the script again and choose a custom name."
    rule
    _return_to_menu
}

# ── Shared key display block (used by generate_key + show_existing) ──
_show_key_info() {
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
    printf "  ${MAGENTA}A short unique ID for your key — use it to verify servers${RESET}\n"
    printf "  ${MAGENTA}or identify which key is which when you have several.${RESET}\n\n"
    printf "  ${BOLD_YELLOW}%s${RESET}\n\n" "$(ssh-keygen -lf "${KEY_FILE}.pub")"
    rule
    ok "All done! Copy the public key above to your server."
    rule
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

# ── Entry point ──────────────────────────────────────────────
_run_loop
