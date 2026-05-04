# 🛠️ Windows Automatic Fix Tool

![Platform](https://img.shields.io/badge/OS-Windows%2011-0078d4?style=for-the-badge&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

> [!WARNING]
> **LEGAL NOTICE & DISCLAIMER**
> This open-source tool is designed to automate common tasks used by IT professionals and PC repair services. 
> 
> This script only runs commands built into Windows; no third-party applications or tools are used. By using this tool, you agree that **sokor** cannot be held liable for any damage caused. If you do not agree, close the script window immediately. **Use at your own risk.**

---

## 📋 Tool Overview

This utility automates system maintenance to resolve common performance issues and update errors.

| Task | Description |
| :--- | :--- |
| **🚫 Disable SysMain** | Stops SysMain to prevent background disk thrashing and slowdowns |
| **🔍 SFC Scan** | Runs System File Checker to repair corrupted OS files |
| **🛠️ DISM Repair** | Services the Windows Image to fix deep-level system corruption |
| **🧹 Temp Cleanup** | Purges temporary files to reclaim space and speed up the OS |
| **🔄 Update Reset** | Resets Windows Update components to fix stuck downloads |
| **💾 Disk Check** | (Optional) Scans for drive errors and dead sectors (requires reboot) |

---

## 📜 Instructions

1. **Download:** [Windows Automatic Fix Tool.bat](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/Windows%20Automatic%20Fix%20Tool/Windows%20Automatic%20Fix%20Tool.bat)
2. **Run:** Right-click the `.bat` file and **Run as Administrator**.
3. **Accept Notice:** Read the on-screen disclaimer. Press any key to continue or close the window to cancel.
4. **Completion:** When the window turns **GREEN**, the tasks are finished.
5. **Optional Scan:** Choose `Y` or `N` for the Disk Check. *Note: This can take 1 hour to 2 days depending on drive health.*
6. **Final Step:** Reboot your PC.

---

## 🔄 Re-Enable SysMain

If you prefer to have SysMain running after the fix is complete, use this secondary script to restore default settings.

**Instructions:**
1. **Download:** [ReEnable SYSMAIN.bat](https://github.com/sokorid/Tools-And-Scripts/blob/main/Windows/Windows%2011/Windows%20Automatic%20Fix%20Tool/ReEnable%20SYSMAIN.bat)
2. **Run:** Execute the script and follow the on-screen prompts.
3. **Success:** Once you see `"TASK COMPLETED SUCCESSFULLY"`, the service is restored.

[⬆ Back to Top](#️-windows-automatic-fix-tool)
