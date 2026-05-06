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
| ⚙️ Auto_Setup_Ubuntu_Server | Initial server setup — updates, static IP, timezone & more |
| 🔒 SSH_Hardening_Script | Secures SSH — keys, firewall, Fail2Ban & stealth mode |
| 🌐 Clear_Port_53 | Frees up Port 53 for Pi-hole, AdGuard Home & local DNS |
| 🔒 SSH_Key_Generator | Quickly generates Ed25519 or RSA keys for your servers |

---

## 📜 Scripts

---

<details>
<summary>⚙️ Auto_Setup_Ubuntu_Server</summary>

<br>

`Auto_Setup_Ubuntu_Server.sh` handles the heavy lifting for your initial system setup.

| Feature | Details |
|--------|---------|
| 🔄 System Updates | Runs a full update and upgrade on all packages |
| 🌐 Network Setup | Guides you through configuring a static IP address |
| 🔕 Clean Login | Option to hide the cluttered SSH welcome message |
| 🕐 Local Time | Helps you set your preferred time zone quickly |
| 🤖 Hands-Off Maintenance | Optionally sets up automatic updates and scheduled reboots |

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

`SSH_Hardening_Script.sh` is a comprehensive security utility designed to fortify your server.

| Feature | Details |
|--------|---------|
| 🔑 SSH Key Management | Sets up public SSH keys for secure, passwordless authentication |
| 🛡️ Port & Firewall Reconfiguration | Changes the default SSH port and updates UFW to close Port 22 |
| 🔐 Security Hardening | Configures the SSH daemon to strengthen the server's defensive posture |
| 🚫 Intrusion Prevention | Installs and configures Fail2Ban to block malicious login attempts |
| 👻 ICMP Management (Stealth Mode) | Optional toggle to disable pings and hide from network scanners |
| ✅ Integrity Check & Recovery | Validates all settings with a built-in recovery routine to prevent lockouts |

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

`SSH_Key_Generator.bat` automates the creation of secure SSH keys and provides a built-in management interface for existing keys.

| Feature | Details |
|--------|---------|
| 🔐 Ed25519 Support | Generates modern, high-security elliptic curve keys |
| 🔐 RSA 4096 Support | Older standard, Use if Ed25519 is unsupported |
| 📂 Auto-Saving | Places keys directly into your `user/.ssh` folder |
| 📋 Key Management | List existing keys, view fingerprints, and display public keys |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/SSH_Key_Generator.sh)

> [!NOTE]
> **Run as a normal user:** No administrative privileges or "sudo" required to manage your personal SSH keys.

**⚡ Auto-run command:**
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/SSH_Key_Generator.sh)"
```

**[⬆ Back to Overview](#-script-overview)**

---
</details>
