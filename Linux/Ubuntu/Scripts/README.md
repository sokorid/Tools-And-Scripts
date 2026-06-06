# 🐧 Ubuntu Scripts

![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

> [!CAUTION]
> **Compatibility:** These scripts are strictly verified for **Ubuntu 26.04**. Use on other versions at your own risk.

---

## 📋 Script Overview

| Script | Description |
|--------|-------------|
| ⚙️ Auto_Setup_Ubuntu_Server | Initial server setup — updates, user creation, static IP, timezone & more |
| 🔒 SSH_Hardening_Script | Secures SSH in 9 guided stages — keys, port, firewall, Fail2Ban & rollback |
| 🌐 Clear_Port_53 | Frees up Port 53 for Pi-hole, AdGuard Home & local DNS |
| 🔒 SSH_Key_Generator | Generates Ed25519 or RSA keys with custom naming, comments, and key management |
| 🖥️ SSH_Connection_Manager | Manages SSH config entries with duplicate protection, manual connect & host cleanup |
| 🔑 SSH_Passkey_Manager | Manages authorized_keys — add, list, and remove SSH public keys |

---

## 📜 Scripts

---

<details>
<summary>⚙️ Auto_Setup_Ubuntu_Server</summary>

<br>

`Auto_Setup_Ubuntu_Server.sh` handles the heavy lifting for your initial server setup across 7 guided steps.

| Feature | Details |
|--------|---------|
| 🖥️ Server Detection | Identifies whether you are on bare metal or a VPS and detects your IP accordingly |
| 🔄 System Updates | Runs a full update and upgrade on all packages with live progress output |
| 🔐 Root & User Setup | Optionally changes the root password and creates a new non-root user with sudo access |
| 🌐 Network Setup | Detects your current interface and guides you through configuring a static IP via Netplan |
| 🔕 Clean Login | Option to disable the SSH welcome message (MOTD) for a cleaner terminal on login |
| 🕐 Local Time | Set your timezone from a preset list or search by city and country |
| 🤖 Hands-Off Maintenance | Configures automatic security updates with optional full-package upgrades and scheduled auto-reboots |
| 🔌 Connection Summary | Prints a copy-paste-ready SSH command at the end so you can reconnect immediately |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/Auto_Setup_Ubuntu_Server.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Auto_Setup_Ubuntu_Server.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>

<details>
<summary>🔒 SSH_Hardening_Script</summary>

<br>

`SSH_Hardening_Script.sh` is a comprehensive 9-stage security utility designed to fortify your server without locking you out.

| Feature | Details |
|--------|---------|
| 🖥️ Server Detection | Identifies bare metal vs VPS and detects your public IP for accurate connection details |
| 🔑 SSH Key Installation | Validates and installs your public key with client OS detection for copy-paste-ready instructions |
| 🌐 Port Configuration | Guides you to a custom SSH port with a port-in-use check and VPS firewall warning |
| ⚙️ SSH Hardening | Configures sshd_config settings — key auth, password auth, root login, idle timeout, and max tries |
| 🛡️ Fail2Ban Protection | Installs and configures Fail2Ban with custom ban time, find time, and optional recidive jail for repeat offenders |
| 👻 Stealth Mode | Optional toggle to disable ping responses and hide the server from network scanners |
| 💾 Config Backup | Backs up sshd_config before any changes are written |
| 🔍 Verification | Lets you test your connection in a live window before committing the new settings |
| ↩️ Automated Rollback | If the connection test fails, automatically restores the original config and resets the firewall |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/SSH_Hardening_Script.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/SSH_Hardening_Script.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>

<details>
<summary>🌐 Clear_Port_53</summary>

<br>

`Clear_Port_53.sh` resolves port conflicts by disabling the default `systemd-resolved` service to free up Port 53.

| Feature | Details |
|--------|---------|
| 🔓 Resolve Port Conflicts | Disables `systemd-resolved` to free Port 53 |
| 📡 DNS Ready | Ensures Pi-hole, AdGuard Home, or any local DNS can bind without conflict |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/Clear_Port_53.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Clear_Port_53.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>

<details>
<summary>🔒 SSH_Key_Generator</summary>

<br>

`SSH_Key_Generator.sh` automates the creation of secure SSH keys and provides a built-in management interface for existing keys.

| Feature | Details |
|:--- | :--- |
| 🔐 **Ed25519 Support** | Generates modern, high-security elliptic curve keys |
| 🔐 **RSA 4096 Support** | Older standard — use if Ed25519 is unsupported |
| 📛 **Custom Naming** | Name your key anything you like, with an optional type suffix appended automatically |
| 💬 **Key Comment** | Set a custom label embedded in your public key for easy identification |
| 📂 **Auto-Saving** | Places keys directly into your `~/.ssh` folder |
| 📋 **Key Management** | List existing keys with name, type, comment, fingerprint, and a key preview |
| 🛡️ **Duplicate Guard** | Detects existing keys before generating — no accidental overwrites |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/SSH_Key_Generator.sh)

| ℹ️ **Note** |
| :--- |
| **Run as a normal user:** No administrative privileges or "sudo" required to manage your SSH keys. |

**⚡ Auto-run command:**
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/SSH_Key_Generator.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>

<details>
<summary>🖥️ SSH_Connection_Manager</summary>

<br>

`SSH_Connection_Manager.sh` provides a high-visibility terminal interface to manage your `~/.ssh/config` file and streamline server connections.

| Feature | Details |
|:--- | :--- |
| 🎨 **ANSI Styling** | Uses Unicode box-drawing and colors for a modern, readable terminal look |
| ⚡ **Fast List** | Displays all saved servers as `alias → user@ip:port` for instant reference |
| 🖥️ **Manual Connect** | Connect to any server on the spot without saving it first — with the option to save after the session ends |
| 🛠️ **Key Validation** | Checks that your chosen identity file exists before saving to prevent broken connections |
| 🛡️ **Duplicate Check** | Prevents saving two servers with the same alias or IP address |
| 💾 **Safe Writes** | Config changes are written atomically via a temp file — the original is never touched until the new version is verified |
| 🚫 **Stealth Cleanup** | Integrated `ssh-keygen -R` logic to safely remove host keys by IP address |
| ⚠️ **Directive Guard** | Detects Match/Include directives in your config and warns that they are preserved but not managed by this tool |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/SSH_Connection_Manager.sh)

| ℹ️ **Note** |
| :--- |
| **No Sudo Required:** This script manages your local user config. It does not touch system-wide files, making it safe to run without administrative privileges. |

**⚡ Auto-run command:**
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/main/Linux/Ubuntu/Scripts/SSH_Connection_Manager.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>

<details>
<summary>🔑 SSH_Passkey_Manager</summary>

<br>

`SSH_Passkey_Manager.sh` provides a menu-driven interface to manage your server's `~/.ssh/authorized_keys` file safely and securely.

| Feature | Details |
|:--- | :--- |
| ➕ **Add Keys** | Paste, validate, and store new SSH public keys with cryptographic verification |
| 📋 **List Keys** | View all authorized keys with type, comment, fingerprint, and preview |
| 🗑️ **Remove Keys** | Delete keys by number from the indexed list or by pasting the full key, with lockout warning if removing the last key |
| 🛡️ **Duplicate Guard** | Detects and blocks duplicate keys before they are written |
| ✅ **Crypto Validation** | Runs `ssh-keygen -l` on every key to catch truncated or corrupted input |
| 🔗 **Symlink Guard** | Refuses to run if `.ssh` or `authorized_keys` is a symlink — prevents writes through unsafe paths |
| 🎨 **ANSI Styling** | Color-coded terminal UI with Unicode box-drawing for clear readability |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/SSH_Passkey_Manager.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/main/Linux/Ubuntu/Scripts/SSH_Passkey_Manager.sh)"
```

**[⬆ Back to Script Overview](#-script-overview)**

---
</details>
