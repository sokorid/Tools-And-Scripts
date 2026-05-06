#!/usr/bin/env bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# =================================================================================
#  ssh_key_generator.sh — Quickly generates Ed25519 or RSA keys for your servers
# =================================================================================

SSH_DIR="$HOME/.ssh"

#the current version of The Script
SCRIPT_VERSION="1.2"

# ============================================================
#  COLORS & STYLES
# ============================================================
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"

BOLD_RED="\033[1;31m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_CYAN="\033[1;36m"
BOLD_WHITE="\033[1;37m"
BOLD_MAGENTA="\033[1;35m"

# ============================================================
#  HELPERS
# ============================================================
print_line() {
    echo -e "${DIM}${CYAN} ─────────────────────────────────────────────────────${RESET}"
}

print_header() {
    clear
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔐  SSH Key Generator${RESET}                              ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_header_main() {
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔐  SSH Key Generator${RESET}                              ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

press_enter() {
    echo ""
    echo -e "  ${DIM}Press ${BOLD_WHITE}ENTER${RESET}${DIM} to continue...${RESET}"
    read -r _
}

press_enter_menu() {
    echo ""
    echo -e "  ${DIM}Press ${BOLD_WHITE}ENTER${RESET}${DIM} to return to the menu...${RESET}"
    read -r _
    main_menu
}

# ============================================================
#  MAIN MENU
# ============================================================
main_menu() {
    clear
    echo -e "${BOLD_CYAN}       📦  SSH KEY Generator Script v${SCRIPT_VERSION}${RESET}"
    print_header_main
    echo -e "  ${WHITE}Generates a secure SSH key for connecting to${RESET}"
    echo -e "  ${WHITE}servers without a password and better security.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}Choose your key type:${RESET}"
    echo ""
    echo -e "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Ed25519${RESET}  ${BOLD_GREEN}✅ Recommended${RESET}"
    echo -e "       ${DIM}⚡ Modern, fast, and highly secure.${RESET}"
    echo ""
    echo -e "  ${BOLD_YELLOW}[2]${RESET}  ${BOLD_WHITE}RSA 4096${RESET}"
    echo -e "       ${DIM}🔑 Older standard. Use if Ed25519 is unsupported.${RESET}"
    echo ""
    echo -e "  ${BOLD_CYAN}[3]${RESET}  ${BOLD_WHITE}List Existing Keys${RESET}"
    echo -e "       ${DIM}📋 View any SSH keys already on this machine.${RESET}"
    echo ""
    echo -e "  ${BOLD_RED}[4]${RESET}  ${BOLD_WHITE}Exit${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Your choice (1, 2, 3 or 4):${RESET} ")" choice

    case "$choice" in
        1) gen_ed25519 ;;
        2) gen_rsa ;;
        3) list_keys ;;
        4) exit_script ;;
        *)
            echo ""
            echo -e "  ${BOLD_RED}❌  Invalid choice.${RESET} ${WHITE}Please enter 1, 2, 3 or 4.${RESET}"
            press_enter
            main_menu
            ;;
    esac
}

# ============================================================
#  GENERATE Ed25519
# ============================================================
gen_ed25519() {
    KEY_TYPE="Ed25519"
    KEY_FILE="$SSH_DIR/id_ed25519"
    KEYGEN_ARGS="-t ed25519"
    name_key
}

# ============================================================
#  GENERATE RSA
# ============================================================
gen_rsa() {
    KEY_TYPE="RSA 4096"
    KEY_FILE="$SSH_DIR/id_rsa"
    KEYGEN_ARGS="-t rsa -b 4096"
    name_key
}

# ============================================================
#  LIST EXISTING KEYS
# ============================================================
list_keys() {
    print_header
    echo -e "  ${BOLD_CYAN}📋  Existing SSH Keys${RESET}"
    print_line
    echo ""

    found_keys=0

    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] || continue
        found_keys=1
        echo -e "  ${BOLD_GREEN}🗝️   Key:${RESET} ${BOLD_WHITE}$pub_file${RESET}"
        echo ""
        echo -e "  ${BOLD_YELLOW}📄  Public Key:${RESET}"
        echo -e "  ${CYAN}$(cat "$pub_file")${RESET}"
        echo ""
        echo -e "  ${BOLD_MAGENTA}🔍  Fingerprint:${RESET}"
        echo -e "  ${WHITE}$(ssh-keygen -lf "$pub_file")${RESET}"
        print_line
        echo ""
    done

    if [ "$found_keys" -eq 0 ]; then
        echo -e "  ${BOLD_YELLOW}⚠️   No SSH keys found on this machine.${RESET}"
        echo ""
        print_line
    fi

    press_enter_menu
}

# ============================================================
#  NAME THE KEY
# ============================================================
name_key() {
    print_header
    echo -e "  ${BOLD_CYAN}✏️   Key File Name${RESET}"
    print_line
    echo -e "  ${WHITE}You can give your key a custom name, or press${RESET}"
    echo -e "  ${WHITE}ENTER to use the default name.${RESET}"
    echo ""
    echo -e "  ${DIM}Default :${RESET} ${BOLD_WHITE}$KEY_FILE${RESET}"
    echo -e "  ${DIM}Example : my_server  →  $SSH_DIR/my_server${RESET}"
    echo ""
    echo -e "  ${DIM}Type ${BOLD_WHITE}back${RESET}${DIM} or ${BOLD_WHITE}exit${RESET}${DIM} to return to the main menu.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}📋  Existing Key Names${RESET}"
    print_line

    any_keys=0
    for pub_file in "$SSH_DIR"/*.pub; do
        [ -f "$pub_file" ] || continue
        any_keys=1
        echo -e "  ${BOLD_GREEN}🗝️  ${RESET} ${WHITE}$(basename "${pub_file%.pub}")${RESET}"
    done
    [ "$any_keys" -eq 0 ] && echo -e "  ${DIM}None found${RESET}"
 
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Custom name (or press ENTER for default):${RESET} ")" custom_name
 
    if [[ "$custom_name" == "exit" || "$custom_name" == "back" ]]; then
        main_menu
        return
    fi

    if [ -n "$custom_name" ]; then
        echo ""
        print_line
        echo -e "  ${BOLD_CYAN}🏷️   Append Encryption Type?${RESET}"
        print_line
        echo -e "  ${WHITE}Append the encryption type to your key name${RESET}"
        echo -e "  ${WHITE}for easy identification?${RESET}"
        echo ""
        if [ "$KEY_TYPE" = "Ed25519" ]; then
            echo -e "  ${DIM}Example: ${BOLD_WHITE}${custom_name}_ed25519${RESET}"
        else
            echo -e "  ${DIM}Example: ${BOLD_WHITE}${custom_name}_rsa4096${RESET}"
        fi
        echo ""
        echo -e "  ${BOLD_GREEN}[1]${RESET}  ${WHITE}Yes — append encryption type${RESET}"
        echo -e "  ${BOLD_YELLOW}[2]${RESET}  ${WHITE}No  — keep name as typed${RESET}"
        echo ""
        echo -e "  ${DIM}Type ${BOLD_WHITE}back${RESET}${DIM} or ${BOLD_WHITE}exit${RESET}${DIM} to return to the main menu.${RESET}"
        echo ""
        print_line
        echo ""
        read -rp "$(echo -e "  ${BOLD_WHITE}Your choice (1 or 2):${RESET} ")" append_choice

        if [[ "$append_choice" == "exit" || "$append_choice" == "back" ]]; then
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

# ============================================================
#  CHECK IF KEY ALREADY EXISTS
# ============================================================
check_exists() {
    print_header

    if [ -f "$KEY_FILE" ]; then
        show_existing
    else
        generate_key
    fi
}

# ============================================================
#  GENERATE NEW KEY
# ============================================================
generate_key() {
    echo -e "  ${BOLD_CYAN}🔄  Creating a new ${BOLD_WHITE}$KEY_TYPE${RESET}${BOLD_CYAN} key...${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_YELLOW}🔒  About Passphrases${RESET}"
    print_line
    echo -e "  ${WHITE}ssh-keygen will now ask you to set a passphrase.${RESET}"
    echo ""
    echo -e "  ${WHITE}A passphrase is an optional password that protects${RESET}"
    echo -e "  ${WHITE}your key file. If someone steals your key file,${RESET}"
    echo -e "  ${WHITE}they still cannot use it without the passphrase.${RESET}"
    echo ""
    echo -e "  ${BOLD_GREEN}↵${RESET}  ${WHITE}Press ENTER twice to skip (no passphrase)${RESET}"
    echo -e "  ${BOLD_YELLOW}🔐${RESET}  ${WHITE}Or type a strong password to protect your key${RESET}"
    echo ""
    echo -e "  ${DIM}💡 Tip: For automated scripts or servers, skipping${RESET}"
    echo -e "  ${DIM}   the passphrase is common. For personal keys,${RESET}"
    echo -e "  ${DIM}   setting one is strongly recommended.${RESET}"
    print_line
    press_enter

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # shellcheck disable=SC2086
    ssh-keygen $KEYGEN_ARGS -f "$KEY_FILE"

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "  ${BOLD_RED}❌  Key generation failed. Please try again.${RESET}"
        press_enter_menu
        return
    fi

    print_header
    echo -e "  ${BOLD_GREEN}✅  SUCCESS!${RESET} ${WHITE}Your ${BOLD_WHITE}$KEY_TYPE${RESET}${WHITE} key has been created.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}📁  Key Location${RESET}"
    print_line
    echo -e "  ${DIM}🔒 Private key :${RESET} ${BOLD_WHITE}$KEY_FILE${RESET}"
    echo -e "  ${DIM}📄 Public key  :${RESET} ${BOLD_WHITE}${KEY_FILE}.pub${RESET}"
    echo ""
    echo -e "  ${BOLD_RED}🚫  Keep your PRIVATE key secret. Never share it.${RESET}"
    echo -e "  ${BOLD_GREEN}📤  Copy your PUBLIC key to any server you want access to.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_YELLOW}📄  Your Public Key${RESET}"
    print_line
    echo ""
    echo -e "  ${CYAN}$(cat "${KEY_FILE}.pub")${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_MAGENTA}🔍  Key Fingerprint${RESET}"
    print_line
    echo -e "  ${DIM}A fingerprint is a short unique ID for your key.${RESET}"
    echo -e "  ${DIM}Use it to verify the right server, or identify${RESET}"
    echo -e "  ${DIM}which key is which if you have several.${RESET}"
    echo ""
    echo -e "  ${WHITE}$(ssh-keygen -lf "${KEY_FILE}.pub")${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_GREEN}🎉  All done! Copy the public key above to your server.${RESET}"
    print_line

    press_enter_menu
}

# ============================================================
#  SHOW EXISTING KEY
# ============================================================
show_existing() {
    echo -e "  ${BOLD_YELLOW}⚠️   A $KEY_TYPE key already exists.${RESET} ${DIM}No new key was created.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}📁  Key Location${RESET}"
    print_line
    echo -e "  ${DIM}🔒 Private key :${RESET} ${BOLD_WHITE}$KEY_FILE${RESET}"
    echo -e "  ${DIM}📄 Public key  :${RESET} ${BOLD_WHITE}${KEY_FILE}.pub${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_YELLOW}📄  Your Public Key${RESET}"
    print_line
    echo ""
    echo -e "  ${CYAN}$(cat "${KEY_FILE}.pub")${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_MAGENTA}🔍  Key Fingerprint${RESET}"
    print_line
    echo -e "  ${DIM}A fingerprint is a short unique ID for your key.${RESET}"
    echo -e "  ${DIM}Use it to verify the right server, or identify${RESET}"
    echo -e "  ${DIM}which key is which if you have several.${RESET}"
    echo ""
    echo -e "  ${WHITE}$(ssh-keygen -lf "${KEY_FILE}.pub")${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}💡  To generate a key with a different name,${RESET}"
    echo -e "  ${BOLD_CYAN}    run the script again and choose a custom name.${RESET}"
    print_line

    press_enter_menu
}

# ============================================================
#  EXIT
# ============================================================
exit_script() {
    clear
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔐  SSH Key Generator${RESET}                              ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD_WHITE}👋  Goodbye!${RESET}"
    echo ""
    print_line
    echo ""
    exit 0
}

# ============================================================
#  ENTRY POINT
# ============================================================
main_menu
