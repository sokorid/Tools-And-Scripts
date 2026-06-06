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
ScriptDownloader is a menu-driven `.bat` utility that lets you browse, preview, and download sokor's Windows 11 scripts directly from GitHub without needing to visit the repository manually.

| Feature | Description |
| :--- | :--- |
| **📋 Script Menu** | Lists all available scripts fetched live from the GitHub registry |
| **👁️ Preview** | Displays a description of each script before you commit to downloading |
| **📥 Download** | Saves scripts to your Desktop or a temporary folder, with overwrite and auto-rename on collision |
| **▶️ Execute** | Optionally runs the script immediately after downloading, with UAC elevation if required |
| **🧩 Companion Files** | Detects and offers secondary scripts that run alongside or after the primary download |
| **🛡️ Safety Checks** | Double-confirms before entering the tool, and warns if a script needs editing before it can run |
| **🧹 Cleanup** | Automatically removes temporary files on exit, with a prompt if downloaded scripts remain |
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
3. **Elevation:** Choose to relaunch as Administrator (recommended) or continue without.
4. **Accept Notice:** Read the on-screen disclaimer and confirm twice to continue.
5. **Browse:** Select a script from the menu by entering its number.
6. **Preview:** Review the script description shown on screen.
7. **Download:** Choose to save to Desktop or Temp, and handle any file conflicts.
8. **Execute:** Optionally run the script immediately elevation will be requested if required.
9. **Exit:** When done, choose whether to keep or delete any downloaded scripts.

---

## 📁 Save Locations

When downloading a script you will be asked where to save it:

| Option | Location | Notes |
| :--- | :--- | :--- |
| **Desktop** | `%USERPROFILE%\Desktop` | Kept after exit |
| **Temp** | `%TEMP%\Sokor_Script_Downloader` | If scripts remain on exit, you will be asked whether to delete them otherwise cleaned up automatically |

---

## 🔗 Repository

Browse all available scripts directly on GitHub:
[Windows 11 Scripts](https://github.com/sokorid/Tools-And-Scripts/tree/main/Windows/Windows%2011)

---

[⬆ Back to Top](#️-scriptdownloader)
