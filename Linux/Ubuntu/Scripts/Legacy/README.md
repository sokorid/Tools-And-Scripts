# 📦 Legacy Linux Scripts

![Status](https://img.shields.io/badge/Status-Archived-yellow?style=for-the-badge)
![OS](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

> [!IMPORTANT]
> **Legacy Script Vault:** This is a dedicated space for my original scripts that are built for older Ubuntu versions (22.04/24.04).
>
> These versions are **frozen**—I don't plan on updating these specific files as they are confirmed working for their intended OS. I may release entirely new scripts to replace them in the future, but these will stay exactly as they are for anyone who needs them.

---

## 📋 Legacy Overview

| Script | Description |
|:--- | :--- |
| 🌐 Clear_Port_53 | Frees up Port 53 for Pi-hole, AdGuard Home & local DNS |
| 🌐 change_casaos_web_ui_port | Emergency fix for inaccessible CasaOS Web UI ports |

---

## 📜 Archived Scripts

<details>
<summary>🌐 Clear_Port_53</summary>

<br>

`Clear_Port_53.sh` resolves port conflicts by disabling the default `systemd-resolved` service to free up Port 53.

| Feature | Details |
|--------|---------|
| 🔓 Resolve Port Conflicts | Disables `systemd-resolved` to free Port 53 |
| 📡 DNS Ready | Ensures Pi-hole, AdGuard Home, or any local DNS can bind without conflict |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/Legacy/Clear_Port_53.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Legacy/Clear_Port_53.sh)"
```

**[⬆ Back to Legacy Overview](#-legacy-overview)**

---
</details>

<details>
<summary>🌐 change_casaos_web_ui_port</summary>

<br>

`change_casaos_web_ui_port.sh` is an emergency utility to reset your CasaOS dashboard access if the port was set to an unavailable or conflicting value.

| Feature | Details |
|--------|---------|
| 🔓 Port Recovery | Resets the Web UI port to restore dashboard access |
| 🛠️ Configuration Fix | Modifies the CasaOS config files directly via CLI |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Linux/Ubuntu/Scripts/Legacy/change_casaos_web_ui_port.sh)

**⚡ Auto-run command:**
```bash
sudo bash -c "$(wget -qLO - https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Linux/Ubuntu/Scripts/Legacy/change_casaos_web_ui_port.sh)"
```

**[⬆ Back to Legacy Overview](#-legacy-overview)**

---
</details>


