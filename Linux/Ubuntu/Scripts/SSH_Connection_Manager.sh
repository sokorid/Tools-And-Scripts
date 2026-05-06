#!/usr/bin/env bash
# ============================================================
# Author:  sokor
# GitHub:  https://github.com/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================

# ============================================================
#  ssh_connection_manager.sh — Manage and connect to SSH
#                              servers via ~/.ssh/config
# ============================================================

SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"
KNOWN_HOSTS="$SSH_DIR/known_hosts"
SCRIPT_VERSION="1.0"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$CONFIG_FILE"

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
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔒  SSH Connection Manager${RESET}                         ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_header_main() {
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔒  SSH Connection Manager${RESET}                         ${BOLD_CYAN}║${RESET}"
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

# Prompt yes/no — returns 0 for yes, 1 for no
ask_yes_no() {
    local answer="$1"
    case "${answer,,}" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# Read the value of a field from a named Host block in config
# Usage: get_host_field "hostname" "FieldName"
get_host_field() {
    local target_host="$1"
    local field="$2"
    local in_block=0
    local value=""
    while IFS= read -r line; do
        local trimmed
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        if echo "$trimmed" | grep -qi "^Host "; then
            local hname
            hname="$(echo "$trimmed" | awk '{print $2}')"
            if [[ "${hname,,}" == "${target_host,,}" ]]; then
                in_block=1
            else
                in_block=0
            fi
        fi
        if [[ "$in_block" == 1 ]]; then
            local key val
            key="$(echo "$trimmed" | awk '{print $1}')"
            val="$(echo "$trimmed" | awk '{$1=""; print substr($0,2)}')"
            if [[ "${key,,}" == "${field,,}" ]]; then
                value="$val"
            fi
        fi
    done < "$CONFIG_FILE"
    echo "$value"
}

# List all Host names from config into array HOSTS[]
load_hosts() {
    HOSTS=()
    while IFS= read -r line; do
        local trimmed
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        if echo "$trimmed" | grep -qi "^Host "; then
            local hname
            hname="$(echo "$trimmed" | awk '{print $2}')"
            HOSTS+=("$hname")
        fi
    done < "$CONFIG_FILE"
}

# Remove a Host block from config (pure bash/sed, no temp files needed)
remove_host_block() {
    local target="${1,,}"
    local in_block=0
    local output=""
    while IFS= read -r line; do
        local trimmed
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        if echo "$trimmed" | grep -qi "^Host "; then
            local hname
            hname="$(echo "$trimmed" | awk '{print $2}')"
            if [[ "${hname,,}" == "$target" ]]; then
                in_block=1
                continue
            else
                in_block=0
            fi
        fi
        if [[ "$in_block" == 0 ]]; then
            output+="$line"$'\n'
        fi
    done < "$CONFIG_FILE"
    # Strip trailing blank lines and write back
    printf '%s' "${output%$'\n'}" > "$CONFIG_FILE"
}

# Check if a host name already exists in config
host_exists() {
    local target="${1,,}"
    load_hosts
    for h in "${HOSTS[@]}"; do
        [[ "${h,,}" == "$target" ]] && return 0
    done
    return 1
}

# Check if a HostName (IP/domain) already exists in config
ip_exists() {
    local target="${1,,}"
    grep -qi "^[[:space:]]*HostName[[:space:]]\+${target}[[:space:]]*$" "$CONFIG_FILE" && return 0
    return 1
}

# ============================================================
#  MAIN MENU
# ============================================================
main_menu() {
    clear
    echo -e "${BOLD_CYAN}       🔒  SSH Connection Manager v${SCRIPT_VERSION}${RESET}"
    print_header_main
    echo -e "  ${WHITE}Manage and connect to your SSH servers through${RESET}"
    echo -e "  ${WHITE}your local ~/.ssh/config file with ease.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}Choose an option:${RESET}"
    echo ""
    echo -e "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Connect to a Saved Server${RESET}"
    echo -e "       ${DIM}⚡ Pick a server by name and connect instantly.${RESET}"
    echo ""
    echo -e "  ${BOLD_CYAN}[2]${RESET}  ${BOLD_WHITE}Add a New Server${RESET}"
    echo -e "       ${DIM}💾 Save a server so you can connect by name.${RESET}"
    echo ""
    echo -e "  ${BOLD_YELLOW}[3]${RESET}  ${BOLD_WHITE}Connect Manually${RESET}"
    echo -e "       ${DIM}⌨️  Type credentials on the fly, save optionally.${RESET}"
    echo ""
    echo -e "  ${BOLD_MAGENTA}[4]${RESET}  ${BOLD_WHITE}Edit / Remove a Saved Server${RESET}"
    echo -e "       ${DIM}✏️  Update or permanently delete a config entry.${RESET}"
    echo ""
    echo -e "  ${BOLD_RED}[5]${RESET}  ${BOLD_WHITE}Exit${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Your choice (1–5):${RESET} ")" choice

    case "$choice" in
        1) connect_saved ;;
        2) add_server ;;
        3) manual_connect ;;
        4) edit_remove ;;
        5) exit_script ;;
        *)
            echo ""
            echo -e "  ${BOLD_RED}❌  Invalid choice.${RESET} ${WHITE}Please enter 1, 2, 3, 4 or 5.${RESET}"
            press_enter
            main_menu
            ;;
    esac
}

# ============================================================
#  OPTION 1 — CONNECT TO A SAVED SERVER
# ============================================================
connect_saved() {
    print_header
    echo -e "  ${BOLD_CYAN}⚡  Connect to a Saved Server${RESET}"
    print_line
    echo -e "  ${WHITE}These are the servers saved in your SSH config file.${RESET}"
    echo -e "  ${WHITE}Each name is an alias you assigned when adding the${RESET}"
    echo -e "  ${WHITE}server. Type the name exactly as shown to connect.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}Saved Servers${RESET}"
    print_line
    echo ""

    load_hosts

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        echo -e "  ${BOLD_YELLOW}⚠️   No saved servers found.${RESET}"
        echo -e "  ${DIM}Use option 2 to add a server first.${RESET}"
        press_enter_menu
        return
    fi

    for h in "${HOSTS[@]}"; do
        local ip user port
        ip="$(get_host_field "$h" "HostName")"
        user="$(get_host_field "$h" "User")"
        port="$(get_host_field "$h" "Port")"
        echo -e "  ${BOLD_GREEN}🖥️   ${BOLD_WHITE}$h${RESET}  ${DIM}→ ${user}@${ip}:${port}${RESET}"
    done

    echo ""
    print_line
    echo -e "  ${DIM}Type ${BOLD_WHITE}back${RESET}${DIM} or ${BOLD_WHITE}exit${RESET}${DIM} to return to the main menu.${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Server name to connect to:${RESET} ")" server_name

    [[ "$server_name" == "back" || "$server_name" == "exit" ]] && main_menu && return
    [[ -z "$server_name" ]] && connect_saved && return

    if ! host_exists "$server_name"; then
        echo ""
        echo -e "  ${BOLD_RED}❌  Server \"${server_name}\" not found in your config.${RESET}"
        press_enter
        connect_saved
        return
    fi

    clear
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔒  SSH Connection Manager${RESET}                         ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD_CYAN}🔗  Connecting to ${BOLD_WHITE}${server_name}${RESET}${BOLD_CYAN} ...${RESET}"
    print_line
    echo ""
    ssh "$server_name"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}✅  Session ended.${RESET}"
    print_line
    press_enter_menu
}

# ============================================================
#  OPTION 2 — ADD A NEW SERVER
# ============================================================
add_server() {
    print_header
    echo -e "  ${BOLD_CYAN}💾  Add a New Server${RESET}"
    print_line
    echo -e "  ${WHITE}This saves a server to your ~/.ssh/config file so${RESET}"
    echo -e "  ${WHITE}you can connect to it by name from option 1.${RESET}"
    echo -e "  ${WHITE}Type ${BOLD_WHITE}back${RESET}${WHITE} or ${BOLD_WHITE}exit${RESET}${WHITE} at any prompt to cancel.${RESET}"
    echo ""
    print_line

    # ── Alias ──────────────────────────────────────────────
    echo -e "  ${BOLD_WHITE}🏷️   Server Alias / Name${RESET}"
    echo -e "  ${DIM}This is the shortcut name you will type to connect.${RESET}"
    echo -e "  ${DIM}Example: homeserver, vps1, work-box  (no spaces)${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Server alias:${RESET} ")" new_name
    [[ "$new_name" == "back" || "$new_name" == "exit" ]] && main_menu && return
    [[ -z "$new_name" ]] && add_server && return

    # ── IP / Hostname ───────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🌐  Server IP / Hostname${RESET}"
    echo -e "  ${DIM}The IP address or domain name of the server.${RESET}"
    echo -e "  ${DIM}Example: 192.168.1.10  or  myserver.example.com${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Hostname or IP:${RESET} ")" new_ip
    [[ "$new_ip" == "back" || "$new_ip" == "exit" ]] && main_menu && return
    [[ -z "$new_ip" ]] && add_server && return

    # ── Duplicate check ─────────────────────────────────────
    if host_exists "$new_name"; then
        echo ""
        echo -e "  ${BOLD_YELLOW}⚠️   A server named \"${new_name}\" already exists.${RESET}"
        echo ""
        echo -e "  ${BOLD_GREEN}[1]${RESET}  ${WHITE}Edit the existing entry${RESET}"
        echo -e "  ${BOLD_YELLOW}[2]${RESET}  ${WHITE}Go back to main menu${RESET}"
        echo ""
        print_line
        echo ""
        read -rp "$(echo -e "  ${BOLD_WHITE}Your choice (1 or 2):${RESET} ")" dupe_choice
        if [[ "$dupe_choice" == "1" ]]; then
            ER_NAME="$new_name"
            do_edit
        else
            main_menu
        fi
        return
    fi

    if ip_exists "$new_ip"; then
        echo ""
        echo -e "  ${BOLD_YELLOW}⚠️   A server with hostname \"${new_ip}\" already exists.${RESET}"
        press_enter
        add_server
        return
    fi

    # ── Username ────────────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}👤  Username${RESET}"
    echo -e "  ${DIM}The account name you log in with on the remote server.${RESET}"
    echo -e "  ${DIM}Example: root, admin, ubuntu, pi${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Username:${RESET} ")" new_user
    [[ "$new_user" == "back" || "$new_user" == "exit" ]] && main_menu && return

    # ── Port ────────────────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔌  Custom Port${RESET}"
    echo -e "  ${DIM}SSH uses port 22 by default. Most servers use this.${RESET}"
    echo -e "  ${DIM}Only say yes if your server uses a different port.${RESET}"
    echo -e "  ${DIM}If unsure, say no and port 22 will be used.${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Use a custom port? (yes/no):${RESET} ")" use_port
    new_port="22"
    if ask_yes_no "$use_port"; then
        read -rp "$(echo -e "  ${BOLD_WHITE}Port number:${RESET} ")" new_port
        [[ -z "$new_port" ]] && new_port="22"
    fi

    # ── Identity File ───────────────────────────────────────
    new_key=""
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔑  Identity File / SSH Key${RESET}"
    echo -e "  ${DIM}A private key lets you log in without a password.${RESET}"
    echo -e "  ${DIM}If you use key authentication, say yes and pick a key.${RESET}"
    echo -e "  ${DIM}If you log in with a password, say no.${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Use a private key? (yes/no):${RESET} ")" use_key
    if ask_yes_no "$use_key"; then
        pick_key "new_key"
        [[ $? -ne 0 ]] && main_menu && return
    fi

    # ── Write to config ─────────────────────────────────────
    {
        echo ""
        echo "Host $new_name"
        echo "    HostName $new_ip"
        [[ -n "$new_user" ]] && echo "    User $new_user"
        echo "    Port $new_port"
        [[ -n "$new_key" ]] && echo "    IdentityFile ~/.ssh/$new_key"
    } >> "$CONFIG_FILE"

    print_header
    echo -e "  ${BOLD_GREEN}✅  SUCCESS!${RESET} ${WHITE}Server \"${BOLD_WHITE}${new_name}${RESET}${WHITE}\" has been saved.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}📋  Saved Entry${RESET}"
    print_line
    echo -e "  ${DIM}Alias    :${RESET} ${BOLD_WHITE}$new_name${RESET}"
    echo -e "  ${DIM}Host     :${RESET} ${BOLD_WHITE}$new_ip${RESET}"
    [[ -n "$new_user" ]] && echo -e "  ${DIM}User     :${RESET} ${BOLD_WHITE}$new_user${RESET}"
    echo -e "  ${DIM}Port     :${RESET} ${BOLD_WHITE}$new_port${RESET}"
    [[ -n "$new_key" ]] && echo -e "  ${DIM}Key      :${RESET} ${BOLD_WHITE}~/.ssh/$new_key${RESET}"
    print_line

    press_enter_menu
}

# ============================================================
#  OPTION 3 — MANUAL CONNECT
# ============================================================
manual_connect() {
    print_header
    echo -e "  ${BOLD_CYAN}⌨️   Connect Manually${RESET}"
    print_line
    echo -e "  ${WHITE}Connect to a server right now without saving it first.${RESET}"
    echo -e "  ${WHITE}You will be asked for the connection details below.${RESET}"
    echo -e "  ${WHITE}At the end you can choose to save it for future use.${RESET}"
    echo -e "  ${WHITE}Type ${BOLD_WHITE}back${RESET}${WHITE} or ${BOLD_WHITE}exit${RESET}${WHITE} at any prompt to cancel.${RESET}"
    echo ""
    print_line

    # ── Username ────────────────────────────────────────────
    echo -e "  ${BOLD_WHITE}👤  Username${RESET}"
    echo -e "  ${DIM}Example: root, admin, ubuntu, pi${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Username:${RESET} ")" man_user
    [[ "$man_user" == "back" || "$man_user" == "exit" ]] && main_menu && return
    [[ -z "$man_user" ]] && manual_connect && return

    # ── IP / Hostname ───────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🌐  Server IP / Hostname${RESET}"
    echo -e "  ${DIM}Example: 192.168.1.10  or  myserver.example.com${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Hostname or IP:${RESET} ")" man_ip
    [[ "$man_ip" == "back" || "$man_ip" == "exit" ]] && main_menu && return
    [[ -z "$man_ip" ]] && manual_connect && return

    # ── Port ────────────────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔌  Custom Port${RESET}"
    echo -e "  ${DIM}SSH uses port 22 by default. Say no if unsure.${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Use a custom port? (yes/no):${RESET} ")" use_port
    man_port="22"
    if ask_yes_no "$use_port"; then
        read -rp "$(echo -e "  ${BOLD_WHITE}Port number:${RESET} ")" man_port
        [[ -z "$man_port" ]] && man_port="22"
    fi

    # ── Identity File ───────────────────────────────────────
    man_key=""
    man_key_flag=""
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔑  Identity File / SSH Key${RESET}"
    echo -e "  ${DIM}Say yes to use a private key, no for password login.${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Use a private key? (yes/no):${RESET} ")" use_key
    if ask_yes_no "$use_key"; then
        pick_key "man_key"
        if [[ $? -eq 0 && -n "$man_key" ]]; then
            man_key_flag="-i $SSH_DIR/$man_key"
        fi
    fi

    # ── Connect ─────────────────────────────────────────────
    clear
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔒  SSH Connection Manager${RESET}                         ${BOLD_CYAN}║${RESET}"
    echo -e "${BOLD_CYAN} ╚═════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD_CYAN}🔗  Connecting to ${BOLD_WHITE}${man_user}@${man_ip}${RESET}${BOLD_CYAN} on port ${BOLD_WHITE}${man_port}${RESET}${BOLD_CYAN} ...${RESET}"
    print_line
    echo ""
    # shellcheck disable=SC2086
    ssh -p "$man_port" $man_key_flag "${man_user}@${man_ip}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}✅  Session ended.${RESET}"
    print_line

    # ── Save? ───────────────────────────────────────────────
    echo ""
    echo -e "  ${BOLD_CYAN}💾  Save This Server?${RESET}"
    print_line
    echo -e "  ${WHITE}Say yes to save these details to your SSH config${RESET}"
    echo -e "  ${WHITE}so you can connect by name next time (option 1).${RESET}"
    echo -e "  ${WHITE}Say no to discard — nothing will be saved.${RESET}"
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Save to config? (yes/no):${RESET} ")" do_save
    if ! ask_yes_no "$do_save"; then
        press_enter_menu
        return
    fi

    # ── Alias ───────────────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🏷️   Server Alias / Name${RESET}"
    echo -e "  ${DIM}Choose a short nickname — this is what you will type${RESET}"
    echo -e "  ${DIM}to connect next time. No spaces. Example: vps1${RESET}"
    echo ""
    while true; do
        read -rp "$(echo -e "  ${BOLD_WHITE}Alias:${RESET} ")" man_alias
        [[ "$man_alias" == "back" || "$man_alias" == "exit" ]] && main_menu && return
        [[ -z "$man_alias" ]] && echo -e "  ${BOLD_RED}❌  Alias cannot be blank.${RESET}" && continue
        host_exists "$man_alias" && echo -e "  ${BOLD_YELLOW}⚠️   That name already exists. Choose another.${RESET}" && continue
        break
    done

    {
        echo ""
        echo "Host $man_alias"
        echo "    HostName $man_ip"
        echo "    User $man_user"
        echo "    Port $man_port"
        [[ -n "$man_key" ]] && echo "    IdentityFile ~/.ssh/$man_key"
    } >> "$CONFIG_FILE"

    echo ""
    echo -e "  ${BOLD_GREEN}✅  Server \"${BOLD_WHITE}${man_alias}${RESET}${BOLD_GREEN}\" saved successfully.${RESET}"
    press_enter_menu
}

# ============================================================
#  OPTION 4 — EDIT / REMOVE
# ============================================================
edit_remove() {
    print_header
    echo -e "  ${BOLD_MAGENTA}✏️   Edit / Remove a Saved Server${RESET}"
    print_line
    echo -e "  ${WHITE}Your saved servers are listed below. Type the name${RESET}"
    echo -e "  ${WHITE}of the server you want to change or delete.${RESET}"
    echo ""
    echo -e "  ${DIM}Edit   — update any of its saved details${RESET}"
    echo -e "  ${DIM}Remove — permanently delete it from your config${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}Saved Servers${RESET}"
    print_line
    echo ""

    load_hosts

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        echo -e "  ${BOLD_YELLOW}⚠️   No saved servers found. Nothing to edit or remove.${RESET}"
        press_enter_menu
        return
    fi

    for h in "${HOSTS[@]}"; do
        local ip user port
        ip="$(get_host_field "$h" "HostName")"
        user="$(get_host_field "$h" "User")"
        port="$(get_host_field "$h" "Port")"
        echo -e "  ${BOLD_GREEN}🖥️   ${BOLD_WHITE}$h${RESET}  ${DIM}→ ${user}@${ip}:${port}${RESET}"
    done

    echo ""
    print_line
    echo -e "  ${DIM}Type ${BOLD_WHITE}back${RESET}${DIM} or ${BOLD_WHITE}exit${RESET}${DIM} to return to the main menu.${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Server name to edit or remove:${RESET} ")" ER_NAME

    [[ "$ER_NAME" == "back" || "$ER_NAME" == "exit" ]] && main_menu && return
    [[ -z "$ER_NAME" ]] && edit_remove && return

    if ! host_exists "$ER_NAME"; then
        echo ""
        echo -e "  ${BOLD_RED}❌  Server \"${ER_NAME}\" was not found in your config.${RESET}"
        press_enter
        edit_remove
        return
    fi

    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}What would you like to do with \"${BOLD_CYAN}${ER_NAME}${RESET}${BOLD_WHITE}\"?${RESET}"
    print_line
    echo ""
    echo -e "  ${BOLD_GREEN}[1]${RESET}  ${BOLD_WHITE}Edit this server${RESET}"
    echo -e "       ${DIM}Update the name, IP, username, port, or key.${RESET}"
    echo ""
    echo -e "  ${BOLD_RED}[2]${RESET}  ${BOLD_WHITE}Remove this server${RESET}"
    echo -e "       ${DIM}Permanently delete it from your SSH config.${RESET}"
    echo -e "       ${DIM}This cannot be undone.${RESET}"
    echo ""
    echo -e "  ${BOLD_YELLOW}[3]${RESET}  ${BOLD_WHITE}Go back${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Your choice (1, 2 or 3):${RESET} ")" er_choice

    case "$er_choice" in
        1) do_edit ;;
        2) do_remove ;;
        3) edit_remove ;;
        *) main_menu ;;
    esac
}

# ============================================================
#  DO EDIT
# ============================================================
do_edit() {
    # Read current values
    local cur_hostname cur_user cur_port cur_key
    cur_hostname="$(get_host_field "$ER_NAME" "HostName")"
    cur_user="$(get_host_field "$ER_NAME" "User")"
    cur_port="$(get_host_field "$ER_NAME" "Port")"
    cur_key="$(get_host_field "$ER_NAME" "IdentityFile")"
    [[ -z "$cur_port" ]] && cur_port="22"

    print_header
    echo -e "  ${BOLD_MAGENTA}✏️   Edit Server: ${BOLD_WHITE}${ER_NAME}${RESET}"
    print_line
    echo -e "  ${BOLD_CYAN}📋  Current Values${RESET}"
    print_line
    echo -e "  ${DIM}Alias    :${RESET} ${BOLD_WHITE}$ER_NAME${RESET}"
    echo -e "  ${DIM}Host     :${RESET} ${BOLD_WHITE}$cur_hostname${RESET}"
    echo -e "  ${DIM}User     :${RESET} ${BOLD_WHITE}$cur_user${RESET}"
    echo -e "  ${DIM}Port     :${RESET} ${BOLD_WHITE}$cur_port${RESET}"
    echo -e "  ${DIM}Key      :${RESET} ${BOLD_WHITE}${cur_key:-none}${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}✏️   Edit Fields${RESET}"
    print_line
    echo -e "  ${DIM}Press ENTER to keep the current value. Type ${BOLD_WHITE}back${RESET}${DIM} to cancel.${RESET}"
    echo ""
    print_line
    echo ""

    # ── New values ───────────────────────────────────────────
    read -rp "$(echo -e "  ${BOLD_WHITE}New alias       ${DIM}(blank = keep '${ER_NAME}'):${RESET} ")" edit_name
    [[ "$edit_name" == "back" || "$edit_name" == "exit" ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return

    read -rp "$(echo -e "  ${BOLD_WHITE}New IP/hostname ${DIM}(blank = keep '${cur_hostname}'):${RESET} ")" edit_ip
    [[ "$edit_ip" == "back" || "$edit_ip" == "exit" ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return

    read -rp "$(echo -e "  ${BOLD_WHITE}New username    ${DIM}(blank = keep '${cur_user}'):${RESET} ")" edit_user
    [[ "$edit_user" == "back" || "$edit_user" == "exit" ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return

    read -rp "$(echo -e "  ${BOLD_WHITE}New port        ${DIM}(blank = keep '${cur_port}'):${RESET} ")" edit_port
    [[ "$edit_port" == "back" || "$edit_port" == "exit" ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return

    # ── Identity file ────────────────────────────────────────
    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔑  Identity File (SSH Key)${RESET}"
    print_line
    echo -e "  ${DIM}Current key: ${BOLD_WHITE}${cur_key:-none}${RESET}"
    echo ""
    echo -e "  ${BOLD_GREEN}yes${RESET}   ${DIM}= choose a new key from your ~/.ssh folder${RESET}"
    echo -e "  ${BOLD_RED}no${RESET}    ${DIM}= remove the key (you will log in by password)${RESET}"
    echo -e "  ${DIM}ENTER = keep the current key as-is (no change)${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Change identity file? (yes/no/Enter to skip):${RESET} ")" key_action
    [[ "$key_action" == "back" || "$key_action" == "exit" ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return

    edit_key="__KEEP__"
    if [[ "${key_action,,}" == "no" ]]; then
        edit_key=""
    elif ask_yes_no "$key_action"; then
        local picked_key=""
        pick_key "picked_key"
        [[ $? -ne 0 ]] && echo -e "  ${BOLD_YELLOW}⚠️   Edit cancelled.${RESET}" && press_enter && main_menu && return
        edit_key="~/.ssh/$picked_key"
    fi

    # ── Fill blanks with current values ─────────────────────
    [[ -z "$edit_name" ]]     && edit_name="$ER_NAME"
    [[ -z "$edit_ip" ]]       && edit_ip="$cur_hostname"
    [[ -z "$edit_user" ]]     && edit_user="$cur_user"
    [[ -z "$edit_port" ]]     && edit_port="$cur_port"
    [[ "$edit_key" == "__KEEP__" ]] && edit_key="$cur_key"

    # ── Remove old block, write new one ──────────────────────
    remove_host_block "$ER_NAME"

    {
        echo ""
        echo "Host $edit_name"
        echo "    HostName $edit_ip"
        [[ -n "$edit_user" ]] && echo "    User $edit_user"
        echo "    Port $edit_port"
        [[ -n "$edit_key" ]] && echo "    IdentityFile $edit_key"
    } >> "$CONFIG_FILE"

    print_header
    echo -e "  ${BOLD_GREEN}✅  Server \"${BOLD_WHITE}${edit_name}${RESET}${BOLD_GREEN}\" updated successfully.${RESET}"
    echo ""
    print_line
    echo -e "  ${BOLD_CYAN}📋  Updated Entry${RESET}"
    print_line
    echo -e "  ${DIM}Alias    :${RESET} ${BOLD_WHITE}$edit_name${RESET}"
    echo -e "  ${DIM}Host     :${RESET} ${BOLD_WHITE}$edit_ip${RESET}"
    [[ -n "$edit_user" ]] && echo -e "  ${DIM}User     :${RESET} ${BOLD_WHITE}$edit_user${RESET}"
    echo -e "  ${DIM}Port     :${RESET} ${BOLD_WHITE}$edit_port${RESET}"
    [[ -n "$edit_key" ]] && echo -e "  ${DIM}Key      :${RESET} ${BOLD_WHITE}$edit_key${RESET}"
    print_line

    press_enter_menu
}

# ============================================================
#  DO REMOVE
# ============================================================
do_remove() {
    # Get the IP before we delete the block
    local remove_ip
    remove_ip="$(get_host_field "$ER_NAME" "HostName")"

    remove_host_block "$ER_NAME"

    print_header
    echo -e "  ${BOLD_RED}🗑️   Server Removed${RESET}"
    print_line
    echo -e "  ${BOLD_WHITE}[-]${RESET} ${WHITE}\"${BOLD_WHITE}${ER_NAME}${RESET}${WHITE}\" has been removed from your config.${RESET}"
    echo ""

    # ── Known hosts cleanup ──────────────────────────────────
    print_line
    echo -e "  ${BOLD_CYAN}🔍  Known Hosts Cleanup${RESET}"
    print_line
    echo -e "  ${WHITE}Your known_hosts file stores the fingerprint of${RESET}"
    echo -e "  ${WHITE}every server you have connected to. If you are${RESET}"
    echo -e "  ${WHITE}permanently removing this server, it is good practice${RESET}"
    echo -e "  ${WHITE}to also remove its fingerprint entry so it does not${RESET}"
    echo -e "  ${WHITE}leave stale data behind.${RESET}"
    echo ""

    if [[ -z "$remove_ip" ]]; then
        echo -e "  ${BOLD_YELLOW}⚠️   Could not determine server IP.${RESET}"
        echo -e "  ${DIM}known_hosts cleanup is not available for this entry.${RESET}"
        press_enter_menu
        return
    fi

    echo -e "  ${DIM}Server IP :${RESET} ${BOLD_WHITE}$remove_ip${RESET}"
    echo ""
    print_line
    echo ""
    read -rp "$(echo -e "  ${BOLD_WHITE}Also remove from known_hosts? (yes/no):${RESET} ")" kh_choice

    if ! ask_yes_no "$kh_choice"; then
        echo ""
        echo -e "  ${DIM}ℹ️   known_hosts left unchanged.${RESET}"
        press_enter_menu
        return
    fi

    echo ""
    echo -e "  ${BOLD_CYAN}🔄  Removing fingerprint for ${BOLD_WHITE}${remove_ip}${RESET}${BOLD_CYAN} ...${RESET}"
    if ssh-keygen -R "$remove_ip" > /dev/null 2>&1; then
        echo -e "  ${BOLD_GREEN}✅  Fingerprint for \"${remove_ip}\" removed from known_hosts.${RESET}"
    else
        echo -e "  ${BOLD_YELLOW}⚠️   Entry not found in known_hosts or ssh-keygen failed.${RESET}"
        echo -e "  ${DIM}This is normal if you never connected to this server.${RESET}"
    fi

    print_line
    press_enter_menu
}

# ============================================================
#  PICK KEY — shared subroutine
#  Sets the variable named by $1 to the chosen key name (no path).
#  Returns 0 on success, 1 on back/exit/cancel.
# ============================================================
pick_key() {
    local __result_var="$1"
    local key_count=0
    local key_names=()

    # Collect keys
    for pub_file in "$SSH_DIR"/*.pub; do
        [[ -f "$pub_file" ]] || continue
        key_names+=("$(basename "${pub_file%.pub}")")
        (( key_count++ ))
    done

    echo ""
    print_line
    echo -e "  ${BOLD_WHITE}🔑  Available Keys in ~/.ssh${RESET}"
    print_line
    echo -e "  ${DIM}Names shown without .pub — the private key file${RESET}"
    echo -e "  ${DIM}will be used automatically for authentication.${RESET}"
    echo ""

    if [[ "$key_count" -eq 0 ]]; then
        echo -e "  ${BOLD_YELLOW}⚠️   No key pairs found in ${SSH_DIR}.${RESET}"
        echo -e "  ${DIM}Skipping key selection.${RESET}"
        print_line
        printf -v "$__result_var" ''
        return 0
    fi

    for k in "${key_names[@]}"; do
        echo -e "  ${BOLD_GREEN}🗝️   ${RESET}${BOLD_WHITE}$k${RESET}"
    done

    echo ""
    print_line
    echo ""

    while true; do
        read -rp "$(echo -e "  ${BOLD_WHITE}Enter key name from list above:${RESET} ")" key_input
        [[ "$key_input" == "back" || "$key_input" == "exit" ]] && return 1
        [[ -z "$key_input" ]] && echo -e "  ${BOLD_RED}❌  Name cannot be blank. Type ${BOLD_WHITE}back${RESET}${BOLD_RED} to cancel.${RESET}" && continue
        if [[ ! -f "$SSH_DIR/$key_input" ]]; then
            echo -e "  ${BOLD_RED}❌  Key \"${key_input}\" not found in ${SSH_DIR}. Check the name.${RESET}"
            continue
        fi
        break
    done

    printf -v "$__result_var" '%s' "$key_input"
    return 0
}

# ============================================================
#  EXIT
# ============================================================
exit_script() {
    clear
    echo ""
    echo -e "${BOLD_CYAN} ╔═════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD_CYAN} ║${RESET}  ${BOLD_WHITE}🔒  SSH Connection Manager${RESET}                         ${BOLD_CYAN}║${RESET}"
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
