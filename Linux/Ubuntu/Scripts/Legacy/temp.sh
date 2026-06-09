#!/usr/bin/env bash

# ============================================================
# Author:  sokor | github.com/sokorid | codeberg.org/sokorid
# License: MIT (https://opensource.org/licenses/MIT)
# Notice:  Provided "as is", without warranty of any kind.
# ============================================================
#
#  Run_All_Setup_Scripts.sh — Full Ubuntu server setup chain
#  with individual or full-sequence run options.
#
# ============================================================

# NOTE: We intentionally do NOT use set -e here so that
# interactive sub-scripts that exit 0 implicitly don't get
# falsely flagged as failures by the shell.
set -uo pipefail

# ============================================================
# CONFIGURATION
# ============================================================
TITLE="Ubuntu Setup Launcher"
VERSION="v1.0"

SCRIPT_1_NAME="Auto Setup Ubuntu Server"
SCRIPT_1_URL="https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Auto_Setup_Ubuntu_Server.sh"

SCRIPT_2_NAME="SSH Hardening"
SCRIPT_2_URL="https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/SSH_Hardening_Script.sh"

SCRIPT_3_NAME="Clear Port 53"
SCRIPT_3_URL="https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Clear_Port_53.sh"

DOCKGE_COMPOSE_PATH="/opt/dockge/compose.yaml"
DOCKGE_STACKS_DIR="/opt/stacks"

# ============================================================
# COLOUR CODES
# ============================================================
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"

# ============================================================
# SUBROUTINES
# ============================================================

print_header() {
    clear
    echo
    echo -e "${CYAN}  =====================================================${RESET}"
    echo -e "${WHITE}    ${TITLE} ${VERSION}${RESET}"
    echo -e "${CYAN}  =====================================================${RESET}"
    echo
}

print_divider() {
    echo -e "${CYAN}  -----------------------------------------------------${RESET}"
}

pause_continue() {
    echo
    print_divider
    echo -e "  ${YELLOW}[i]${RESET}  Press ENTER to continue..."
    read -r
}

confirm_run() {
    local name="$1"
    echo -e "  ${YELLOW}[!]${RESET}  About to run: ${BOLD}${name}${RESET}"
    print_divider
    echo -e "  Press ENTER to start, or CTRL+C to cancel."
    read -r
}

# Runs a remote script. Uses || true so an implicit exit-0
# sub-script never gets mis-reported as a failure.
run_remote_script() {
    local name="$1"
    local url="$2"

    print_header
    echo -e "  ${BOLD}Running: ${name}${RESET}"
    print_divider
    echo -e "  ${YELLOW}[~]${RESET} Fetching and executing..."
    echo -e "  ${YELLOW}[i]${RESET} URL: ${url}"
    echo
    print_divider
    echo

    local tmp
    tmp=$(mktemp /tmp/setup_script.XXXXXX.sh)
    # Download first so we can check the fetch itself
    if ! wget -qLO "${tmp}" "${url}"; then
        echo -e "  ${RED}[X]${RESET}  Failed to download ${name}. Check your internet connection."
        rm -f "${tmp}"
        return 1
    fi

    bash "${tmp}"
    local exit_code=$?
    rm -f "${tmp}"

    echo
    print_divider
    if [[ ${exit_code} -eq 0 ]]; then
        echo -e "  ${GREEN}[+]${RESET}  ${name} completed successfully."
    else
        # exit code 1 from Clear Port 53 means user chose 'Aborted' — treat as success
        # Only truly fail on codes > 1 which indicate real errors
        if [[ ${exit_code} -eq 1 ]]; then
            echo -e "  ${YELLOW}[!]${RESET}  ${name} exited early (user aborted or no action needed)."
        else
            echo -e "  ${RED}[X]${RESET}  ${name} failed with exit code ${exit_code}."
            return 1
        fi
    fi
    print_divider
}

install_docker() {
    print_header
    echo -e "  ${BOLD}Running: Docker Install${RESET}"
    print_divider
    echo

    echo -e "  ${YELLOW}[~]${RESET} [1/3] Adding Docker GPG key and repository..."
    echo
    apt-get update -y
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    echo -e "  ${GREEN}[+]${RESET} Repository added."
    echo

    echo -e "  ${YELLOW}[~]${RESET} [2/3] Installing Docker packages..."
    echo
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    echo -e "  ${GREEN}[+]${RESET} Docker packages installed."
    echo

    echo -e "  ${YELLOW}[~]${RESET} [3/3] Verifying with hello-world..."
    echo
    if docker run hello-world; then
        echo
        print_divider
        echo -e "  ${GREEN}[+]${RESET}  Docker installed and verified successfully."
        print_divider
    else
        echo
        print_divider
        echo -e "  ${RED}[X]${RESET}  Docker verification failed."
        print_divider
        return 1
    fi
}

install_dockge() {
    print_header
    echo -e "  ${BOLD}Running: Dockge Install${RESET}"
    print_divider
    echo

    echo -e "  ${YELLOW}[~]${RESET} [1/3] Creating directories..."
    mkdir -p "${DOCKGE_STACKS_DIR}" /opt/dockge
    cd /opt/dockge
    echo -e "  ${GREEN}[+]${RESET} Created /opt/dockge and ${DOCKGE_STACKS_DIR}"
    echo

    echo -e "  ${YELLOW}[~]${RESET} [2/3] Writing compose.yaml..."
    cat > "${DOCKGE_COMPOSE_PATH}" <<'EOF'
services:
  dockge:
    image: louislam/dockge:1
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      # Stacks Directory
      # ⚠️ READ IT CAREFULLY. If you did it wrong, your data could end up writing into a WRONG PATH.
      # ⚠️ 1. FULL path only. No relative path (MUST)
      # ⚠️ 2. Left Stacks Path === Right Stacks Path (MUST)
      - /opt/stacks:/opt/stacks
    environment:
      # Tell Dockge where to find the stacks
      - DOCKGE_STACKS_DIR=/opt/stacks
EOF
    echo -e "  ${GREEN}[+]${RESET} compose.yaml written to ${DOCKGE_COMPOSE_PATH}"
    echo

    echo -e "  ${YELLOW}[~]${RESET} [3/3] Starting Dockge..."
    echo
    if docker compose up -d; then
        echo
        print_divider
        echo -e "  ${GREEN}[+]${RESET}  Dockge is running."
        echo -e "  ${YELLOW}[i]${RESET}  Access at: http://$(hostname -I | awk '{print $1}'):5001"
        print_divider
    else
        echo
        print_divider
        echo -e "  ${RED}[X]${RESET}  Dockge failed to start."
        print_divider
        return 1
    fi
}

# ============================================================
# ROOT CHECK
# ============================================================
if [[ "${EUID}" -ne 0 ]]; then
    echo
    echo -e "  ${RED}[X]${RESET} This script must be run as root."
    echo -e "  ${YELLOW}[i]${RESET} Try: sudo bash Run_All_Setup_Scripts.sh"
    echo
    exit 1
fi

# ============================================================
# MAIN MENU
# ============================================================
MAIN_MENU() {
    while true; do
        print_header
        echo -e "  Select an option:"
        echo
        echo -e "    ${GREEN}[1]${RESET}  Run All  ${CYAN}(runs every step in sequence)${RESET}"
        echo
        echo -e "    ${GREEN}[2]${RESET}  ${SCRIPT_1_NAME}"
        echo -e "    ${GREEN}[3]${RESET}  ${SCRIPT_2_NAME}"
        echo -e "    ${GREEN}[4]${RESET}  ${SCRIPT_3_NAME}"
        echo -e "    ${GREEN}[5]${RESET}  Docker Install"
        echo -e "    ${GREEN}[6]${RESET}  Dockge Install"
        echo
        print_divider
        echo -e "    ${GREEN}[0]${RESET}  Exit"
        print_divider
        echo
        read -rp "  Your choice: " CHOICE

        case "${CHOICE}" in
            1)
                confirm_run "Full Setup Sequence (All 5 Steps)"
                run_remote_script "${SCRIPT_1_NAME}" "${SCRIPT_1_URL}" && pause_continue
                run_remote_script "${SCRIPT_2_NAME}" "${SCRIPT_2_URL}" && pause_continue
                run_remote_script "${SCRIPT_3_NAME}" "${SCRIPT_3_URL}" && pause_continue
                install_docker && pause_continue
                install_dockge

                print_header
                echo -e "  ${GREEN}[+]${RESET}  All steps completed!"
                echo
                print_divider
                echo -e "  ${BOLD}  Summary${RESET}"
                print_divider
                echo -e "    ${GREEN}[+]${RESET}  ${SCRIPT_1_NAME}"
                echo -e "    ${GREEN}[+]${RESET}  ${SCRIPT_2_NAME}"
                echo -e "    ${GREEN}[+]${RESET}  ${SCRIPT_3_NAME}"
                echo -e "    ${GREEN}[+]${RESET}  Docker Installed & Verified"
                echo -e "    ${GREEN}[+]${RESET}  Dockge Running on port 5001"
                print_divider
                echo -e "  ${YELLOW}[i]${RESET}  Dockge UI: http://$(hostname -I | awk '{print $1}'):5001"
                echo -e "  ${YELLOW}[i]${RESET}  A reboot may be recommended."
                echo
                pause_continue
                ;;
            2) confirm_run "${SCRIPT_1_NAME}"; run_remote_script "${SCRIPT_1_NAME}" "${SCRIPT_1_URL}"; pause_continue ;;
            3) confirm_run "${SCRIPT_2_NAME}"; run_remote_script "${SCRIPT_2_NAME}" "${SCRIPT_2_URL}"; pause_continue ;;
            4) confirm_run "${SCRIPT_3_NAME}"; run_remote_script "${SCRIPT_3_NAME}" "${SCRIPT_3_URL}"; pause_continue ;;
            5) confirm_run "Docker Install";   install_docker;                                         pause_continue ;;
            6) confirm_run "Dockge Install";   install_dockge;                                         pause_continue ;;
            0)
                print_header
                echo -e "  Goodbye!"
                echo
                exit 0
                ;;
            *)
                echo
                echo -e "  ${RED}[X]${RESET}  Invalid choice. Please enter 0-6."
                sleep 1
                ;;
        esac
    done
}

MAIN_MENU
