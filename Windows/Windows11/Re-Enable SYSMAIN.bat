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
title Re-Enable SYSMAIN
color f
cls
echo NOTICE: THIS OPEN-SOURCE SCRIPT SIMPLY JUST RE-ENABLES SYSMAIN THIS SCRIPT ONLY RUNS COMMANDS BUILT INTO WINDOWS.
echo NO THIRD PARTY APPLICATIONS. OR TOOLS ARE USED BY THIS SCRIPT. BY USING THIS TOOL YOU AGREE THAT sokor CANNOT BE HELD LIABLE 
echo FOR ANY DAMAGE CAUSED BY USING THIS TOOL. IF YOU DO NOT AGREE, CLOSE THIS WINDOW NOW. USE AT YOUR OWN RISK.
echo.
echo.
echo This script will attempt to Re-Enable SYSMAIN.
echo.
echo This script is a continuation of my Windows Automatic Fix Tool.
echo I know some people may want to re-enable this so that's why I made this SCRIPT.
echo.
@pause
echo Creating a restore point in case something goes wrong...
echo.
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "<Re-Enable SYSMAIN>", 100, 7
echo.
echo.
echo --- Re-Enabling AND Re-Starting SYSMAIN ---
echo.
sc config sysmain start=auto
net start sysmain
echo.
echo Done...
echo.
@pause
exit
