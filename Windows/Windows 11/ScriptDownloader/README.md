<!-- PRIMARY: ScriptDownloader.bat | RE:no,RA:no,DO:yes -->

# ⬇️ ScriptDownloader

![Platform](https://img.shields.io/badge/OS-Windows%2011-0078d4?style=for-the-badge&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Beta-orange?style=for-the-badge)

> [!WARNING]
> **LEGAL NOTICE & DISCLAIMER**
> This open-source tool downloads and executes scripts from the internet.
>
> Always review any script before running it. By using this tool, you agree that **sokor** cannot be held liable for any damage caused. If you do not agree, close the script window immediately. **Use at your own risk.**

---

## 📋 Overview
<!-- DISPLAY_START -->
ScriptDownloader is a menu-driven `.bat` utility that lets you browse, preview, and download sokor Windows 11 scripts directly from GitHub — without needing to visit the repository manually.

| Feature | Description |
| :--- | :--- |
| **📋 Script Menu** | Lists all available scripts fetched from the GitHub registry |
| **👁️ Preview** | Displays a description of each script before you download |
| **📥 Download** | Saves scripts to your Desktop or a temporary folder |
| **▶️ Execute** | Optionally runs the script immediately after downloading |
| **🧹 Cleanup** | Automatically removes temporary files on exit |
<!-- DISPLAY_END -->
---

## ⚙️ Requirements

- Windows 11
- Internet connection
- PowerShell (built into Windows)
- `curl` (built into Windows 10/11)

---

## 🚀 How to Use

1. **Download:** [ScriptDownloader.bat](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/ScriptDownloader/ScriptDownloader.bat)
2. **Run:** Double-click `ScriptDownloader.bat`.
3. **Accept Notice:** Read the on-screen disclaimer and confirm to continue.
4. **Browse:** Select a script from the menu by entering its number.
5. **Preview:** Review the script description shown on screen.
6. **Download:** Choose to download and optionally execute the script.
7. **Exit:** When done, choose whether to keep or delete any downloaded scripts.

---

## 📁 Save Locations

When downloading a script you will be asked where to save it:

| Option | Location | Notes |
| :--- | :--- | :--- |
| **Desktop** | `%USERPROFILE%\Desktop` | Kept after exit |
| **Temp** | `%TEMP%\Sokor_Script_Downloader` | You will be asked on exit whether to delete |

---

## 🔗 Repository

Browse all available scripts directly on GitHub:
[Windows 11 Scripts](https://github.com/sokorid/Tools-And-Scripts/tree/main/Windows/Windows%2011)

---

[⬆ Back to Top](#️-scriptdownloader)
