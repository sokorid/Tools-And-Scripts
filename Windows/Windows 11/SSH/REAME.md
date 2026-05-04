# 🔑 Windows SSH Batch Scripts

![Platform](https://img.shields.io/badge/OS-Windows%2011-0078d4?style=for-the-badge&logo=windows&logoColor=white)
![Service](https://img.shields.io/badge/Service-SSH-black?style=for-the-badge&logo=openssh&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

> [!NOTE]
> This repository contains batch scripts (`.bat`) designed to simplify SSH management on Windows, including quick-connect shortcuts and key management.

---

## 📋 Script Overview

| Script | Description |
|--------|-------------|
| 🚀 [Open_SSH](#-open_ssh) | Standard SSH connection launcher for default Port 22 |
| 🔌 [Open_SSH_Port](#-open_ssh_port) | SSH launcher for servers using custom ports |

---

## 📜 Scripts

<details>
<summary>🚀 Open_SSH</summary>

<br>

`Open_SSH.bat` is a template for standard connections. It sets a clean terminal environment and initiates the connection.

| Feature | Details |
|--------|---------|
| 🎨 Visuals | Clears the console and sets a white-on-black theme (`color f`) |
| ⚡ Speed | Launches the connection immediately without extra flags |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/SSH/Open_SSH.bat)

**🛠️ Setup:**
1. Right-click the file and select **Edit**.
2. Replace `UserName@IPAddress` with your actual login info.
3. Save and run.

**[⬆ Back to Overview](#-script-overview)**

---
</details>

<details>
<summary>🔌 Open_SSH_Port</summary>

<br>

`Open_SSH_Port.bat` is designed for hardened servers where the default SSH port (22) has been changed for security.

| Feature | Details |
|--------|---------|
| 🔒 Custom Port | Uses the `-p` flag to target your specific SSH port |
| 🛠️ Compatibility | Ideal for use with my Linux Hardening scripts |

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/SSH/Open_SSH_Port.bat)

**🛠️ Setup:**
1. Right-click the file and select **Edit**.
2. Change `port` to your custom number (e.g., `2222`).
3. Replace `UserName@IPAddress` with your login info.

**[⬆ Back to Overview](#-script-overview)**

---
</details>
