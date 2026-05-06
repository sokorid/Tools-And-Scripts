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
| 🚀 Open_SSH | Standard SSH connection launcher for default Port 22 |
| 🔌 Open_SSH_Port | SSH launcher for servers using custom ports |
| 🔒 SSH_Key_Generator | Quickly generates Ed25519 or RSA keys for your servers |

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

🔗 [View Script](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/SSH/SSH_Key_Generator.bat)

**⚡ How to use:**
1. Download the `.bat` file.
2. Run it as a normal user (no Admin required for SSH keys).
3. Follow the prompts to name your key.

**[⬆ Back to Overview](#-script-overview)**

---
</details>
