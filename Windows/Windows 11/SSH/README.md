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
| 🖥️ SSH_Connection_Manager | Automates SSH config entries with duplicate protection and host cleanup. |

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
1. Download the `.bat` file.
2. Right-click the file and select **Edit**.
3. Replace `UserName@IPAddress` with your actual login info.
4. Save and run.

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
1. Download the `.bat` file.
2. Right-click the file and select **Edit**.
3. Change `port` to your custom number (e.g., `2222`).
4. Replace `UserName@IPAddress` with your login info.
5. Save and run.

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

| ℹ️ **Note** |
| :--- |
| **Run as a normal user:** No administrator privileges required to manage your SSH keys. |


**🛠️ The Manual Way:**
1. Download the `.bat` file.
2. Run it as a normal user (no Admin required for SSH keys).
3. Follow the prompts to name your key.

**⚡ Auto-run command:**
*Search for **CMD**, open it, and right-click to paste the following:*
```bash
curl -s -o %temp%\SSH_Key_Generator.bat https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Windows/Windows%2011/SSH/SSH_Key_Generator.bat && call %temp%\SSH_Key_Generator.bat && del %temp%\SSH_Key_Generator.bat
```

**[⬆ Back to Overview](#-script-overview)**

---
</details>

<details>
<summary>🖥️ SSH_Connection_Manager </summary>

<br>

`SSH_Connection_Manager.bat` is a native Windows utility to manage your local `user/.ssh/config` file and quickly connect to servers without needing to remember IP addresses, custom ports, or usernames.

| Feature | Details |
|:--- | :--- |
| 🗂️ **Config Sync** | Automatically reads, adds, and edits your Windows SSH config file |
| 🛡️ **Duplicate Check** | Prevents saving two servers with the same nickname or IP address |
| 🔑 **Key Discovery** | Scans your `.ssh` folder and lets you pick keys from a list |
| 🧹 **Known_Hosts Fix** | When removing a server, it offers to clean up old fingerprints |
| 📋 **Quick Connect** | Select a saved alias to launch an SSH session immediately |

<br>

| ℹ️ **Note** |
| :--- |
| **Execution Policy:** This script uses a tiny PowerShell helper for config block deletion. It automatically bypasses execution policies temporarily to ensure it runs seamlessly. |

<br>

### 🛠️ The Manual Way
1. **Download:** Grab the `SSH_Connection_Manager.bat` file from your Windows repository directory.
2. **Execute:** Double-click the file to run. No Admin rights or sudo required.
3. **Follow Prompts:** Choose whether to connect to an existing server, add a new one, edit an entry, or remove a server.

---

### ⚡ The Automated Way (One-Liner)
*Search for **CMD**, open it, and right-click to paste the following:*
```bash
curl -s -o %temp%\SSH_Connection_Manager.bat https://raw.githubusercontent.com/sokorid/Tools-And-Scripts/refs/heads/main/Windows/Windows%2011/SSH/SSH_Connection_Manager.bat && call %temp%\SSH_Connection_Manager.bat && del %temp%\SSH_Connection_Manager.bat
```

**[⬆ Back to Overview](#-script-overview)**

---
</details>
