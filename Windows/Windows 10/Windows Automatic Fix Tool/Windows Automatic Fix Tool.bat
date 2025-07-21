@echo off

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
    IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------   
title Windows Automatic Fix Tool
color f
cls
echo NOTICE: THIS OPEN SOURCE TOOL IS A SCRIPT DESIGNED TO AUTOMATE COMMON TASKS USED BY IT PROFESSIONALS
echo AND PC REPAIR SERVICES. THIS SCRIPT ONLY RUNS COMMANDS BUILT INTO WINDOWS. NO THIRD PARTY APPLICATIONS 
echo OR TOOLS ARE USED BY THIS SCRIPT. BY USING THIS TOOL YOU AGREE THAT sokor CANNOT BE HELD LIABLE 
echo FOR ANY DAMAGE CAUSED BY USING THIS TOOL. IF YOU DO NOT AGREE, CLOSE THIS WINDOW NOW. USE AT YOUR OWN RISK.
echo.
echo.
echo This tool will attempt to fix common Windows issues by running these Windows tasks:
echo.
echo 1.) SYSTEM FILE CHECKER
echo 2.) DEPLOYMENT IMAGE SERVICING AND MANAGEMENT TOOL
echo 3.) TEMP FILE REMOVAL
echo 4.) WINDOWS UPDATE RESET
echo.
echo 5.) OPTIONAL Check Drive for errors and dead sectors
echo.
echo *SFC will scan your system files for corruption and attempt to repair them automatically.
echo *DISM will check your Windows installation image for problems and attempt to repair it automatically.
echo *After these two tasks, the script will try to delete all temporary files to speed up your PC.
echo *After temporary file removal, Windows Update will reset to resolve most update issues.
echo *After Windows Update resets, you'll have a choice to run Check Drive to look for errors and dead sectors,
echo which can speed up your drive.
echo *Check Drive might take anywhere from 1 hour to 2 days. If it takes longer, your drive is likely failing.
echo *Once all tasks are complete, your screen will turn green, and you can reboot your PC.
echo.
@pause
echo Creating a restore point in case something goes wrong...
echo.
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "<Windows Automatic Fix Tool>", 100, 7
echo.
echo Running tasks...
echo.
echo --- SYSTEM FILE CHECKER STARTED ---
echo.
SFC /scannow
echo.
echo Done...
echo.
echo --- DISM SCAN STARTED ---
echo.
DISM /Online /Cleanup-Image /ScanHealth
echo.
echo Done...
echo.
echo --- DISM REPAIR STARTED ---
echo.
DISM /Online /Cleanup-Image /RestoreHealth
echo.
echo Done...
echo.
echo --- Temp File Removal Started ---
echo.
del /s /f /q c:\windows\temp\*.*
rd /s /q c:\windows\temp
md c:\windows\temp
del /s /f /q C:\WINDOWS\Prefetch
del /s /f /q %temp%\*.*
rd /s /q %temp%
md %temp%
rd /s /q c:\windows\tempor~1
del /f /q c:\windows\tempor~1
md c:\windows\tempor~1
rd /s /q c:\windows\temp
del /f /q c:\windows\temp
md c:\windows\temp
rd /s /q c:\windows\tmp
del /f /q c:\windows\tmp
md c:\windows\tmp
rd /s /q c:\windows\ff*.tmp
del /f /q c:\windows\ff*.tmp
md c:\windows\ff*.tmp
rd /s /q c:\windows\history
del /f /q c:\windows\history
md c:\windows\history
rd /s /q c:\windows\cookies
del /f /q c:\windows\cookies
md c:\windows\cookies
rd /s /q c:\windows\recent
del /f /q c:\windows\recent
md c:\windows\recent
echo.
echo Done...
echo.
echo --- Reset Windows Updates Starting ---
echo.
net stop wuauserv
net start wuauserv
echo.
echo Done...
echo.
:-------------------------------------
:OPTIONAL
cls
echo.
echo do you want to do the optional
echo Check Drive for errors or dead sectors
echo Warning, this might take 1 hours to multiple days to complete
echo this is not necessary but might help
echo.
echo If you wish to do it, type y and hit enter
echo if not type n and hit enter
echo.
set /p choice=[Y/N] 

if %choice%==y goto CheckDrive
if %choice%==Y goto CheckDrive
if %choice%==yes goto CheckDrive
if %choice%==YES goto CheckDrive
if %choice%==n goto endall
if %choice%==N goto endall
if %choice%==no goto endall
if %choice%==NO goto endall

goto OPTIONAL
:-------------------------------------
:CheckDrive
echo.
echo --- Check Drive for errors and dead sectors ---
echo.
echo y | chkdsk C: /f /r
:-------------------------------------
:endall
cls
echo.
echo Task completed successfully...
echo.
color 20
echo All tasks have completed successfully!
echo You can press any key to close this window. Reboot your PC.
@pause
exit
