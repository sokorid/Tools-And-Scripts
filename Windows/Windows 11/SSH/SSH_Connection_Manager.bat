@echo off
setlocal enabledelayedexpansion
title SSH Connection Manager
color f

:: ============================================================
:: Author:  sokor | github.com/sokorid | codeberg.org/sokorid
:: License: MIT (https://opensource.org/licenses/MIT)
:: Notice:  Provided "as is", without warranty of any kind.
:: ============================================================
::  SSH_Connection_Manager.bat Manage and connect to SSH servers
::                    via your ~/.ssh/config file
:: ============================================================

:: ============================================================
:: CONFIGURATION
:: ============================================================
set "TITLE=SSH Connection Manager"
set "VERSION=v1.8"
set "SSH_DIR=%USERPROFILE%\.ssh"
set "CONFIG_FILE=%SSH_DIR%\config"

if not exist "%SSH_DIR%"     mkdir "%SSH_DIR%"
if not exist "%CONFIG_FILE%" type nul > "%CONFIG_FILE%"


:: ============================================================
:MAIN_MENU
:: ============================================================
call :PRINT_HEADER
echo    Manage and connect to your SSH servers through
echo    your local ~/.ssh/config file with ease.
echo.
echo  -----------------------------------------------------
echo    Choose an option:
echo.
echo    [1]  Connect to a Saved Server
echo         Connect instantly by name no IPs or usernames needed.
echo.
echo    [2]  Add a New Server to Config
echo         Save a server (name, IP, user, port, key) to reuse anytime.
echo.
echo    [3]  Connect to a Server Manually
echo         Type connection details now, with the option to save after.
echo.
echo    [4]  Edit / Remove a Saved Server
echo         Update or delete a saved server from your config.
echo.
echo    [5]  Exit
echo.
echo  -----------------------------------------------------
echo.
set /p "MAIN_CHOICE=  Your choice (1, 2, 3, 4 or 5): "

if "%MAIN_CHOICE%"=="1" goto CONNECT_SAVED
if "%MAIN_CHOICE%"=="2" goto ADD_SERVER
if "%MAIN_CHOICE%"=="3" goto MANUAL_CONNECT
if "%MAIN_CHOICE%"=="4" goto EDIT_REMOVE
if "%MAIN_CHOICE%"=="5" goto EXIT_SCRIPT

echo.
echo  [X] Invalid choice. Please enter 1, 2, 3, 4 or 5.
echo.
pause & goto MAIN_MENU


:: ============================================================
:CONNECT_SAVED
:: ============================================================
call :PRINT_HEADER
echo  =====================================================
echo    Connect to a Saved Server
echo  =====================================================
echo.
echo    These are the servers saved in your SSH config file.
echo    Type the name exactly as shown to connect.
echo.
echo  -----------------------------------------------------
echo    SAVED SERVERS
echo  -----------------------------------------------------
echo.

call :LIST_HOSTS

if "%HOST_COUNT%"=="0" (
    echo.
    echo  [!] No saved servers found. Use option 2 to add one first.
    echo.
    echo  =====================================================
    echo.
    pause
    goto MAIN_MENU
)

echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "SERVER_NAME=  Server name to connect to: "

if /i "%SERVER_NAME%"=="b"    goto MAIN_MENU
if /i "%SERVER_NAME%"=="back" goto MAIN_MENU
if /i "%SERVER_NAME%"=="m"    goto MAIN_MENU
if /i "%SERVER_NAME%"=="main" goto MAIN_MENU
if /i "%SERVER_NAME%"=="menu" goto MAIN_MENU
if /i "%SERVER_NAME%"=="e"    goto EXIT_SCRIPT
if /i "%SERVER_NAME%"=="exit" goto EXIT_SCRIPT
if "%SERVER_NAME%"==""        goto CONNECT_SAVED

call :HOST_EXISTS "%SERVER_NAME%"
if "%HOST_FOUND%"=="0" (
    echo.
    echo  [X] Server "%SERVER_NAME%" was not found in your config.
    echo.
    pause
    goto CONNECT_SAVED
)

call :PRINT_HEADER
echo  =====================================================
echo    Connecting...
echo  =====================================================
echo.
echo  [~] Connecting to %SERVER_NAME% ...
echo.
echo  =====================================================
echo.
ssh "%SERVER_NAME%"
echo.
echo  =====================================================
echo  [i] Session ended.
echo  =====================================================
echo.
pause
goto MAIN_MENU


:: ============================================================
:ADD_SERVER
:: ============================================================
call :PRINT_HEADER
echo  =====================================================
echo    Add a New Server to Config
echo  =====================================================
echo.
echo    This saves a server to your ~/.ssh/config file so
echo    you can connect to it by name from option 1.
echo    Fill in each field below. Type "back" or "exit" to cancel.
echo.
echo  -----------------------------------------------------
echo    SERVER DETAILS
echo  -----------------------------------------------------
echo.

set "NEW_NAME=" & set "NEW_IP=" & set "NEW_USER=" & set "NEW_PORT=22" & set "NEW_KEY="

echo    SERVER ALIAS / NAME
echo    Shortcut name you will type to connect. No spaces.
echo    Example: homeserver, vps1, work-box
echo.
set /p "NEW_NAME=  Server alias / name: "
if /i "%NEW_NAME%"=="back" goto MAIN_MENU
if /i "%NEW_NAME%"=="exit" goto MAIN_MENU
if "%NEW_NAME%"=="" goto ADD_SERVER
call :SANITIZE_CHECK "%NEW_NAME%"
if "%SANITIZE_FAIL%"=="1" (
    echo.
    echo  [X] Name cannot contain special characters ^(^& ^| ^> ^<^).
    echo.
    goto ADD_SERVER
)

echo.
echo    SERVER IP / HOSTNAME
echo    The IP address or domain name of the server.
echo    Example: 192.168.1.10  or  myserver.example.com
echo.
set /p "NEW_IP=  Server IP or hostname: "
if /i "%NEW_IP%"=="back" goto MAIN_MENU
if /i "%NEW_IP%"=="exit" goto MAIN_MENU
if "%NEW_IP%"=="" goto ADD_SERVER
call :SANITIZE_CHECK "%NEW_IP%"
if "%SANITIZE_FAIL%"=="1" (
    echo.
    echo  [X] Hostname cannot contain special characters ^(^& ^| ^> ^<^).
    echo.
    goto ADD_SERVER
)

call :CHECK_DUPLICATE "%NEW_NAME%" "%NEW_IP%"
if "%DUPE_FOUND%"=="1" goto DUPE_PROMPT_ADD

echo.
echo    USERNAME
echo    The account name you log in with on the remote server.
echo    Example: root, admin, ubuntu, pi
echo.
set /p "NEW_USER=  Username: "
if /i "%NEW_USER%"=="back" goto MAIN_MENU
if /i "%NEW_USER%"=="exit" goto MAIN_MENU

echo.
echo  -----------------------------------------------------
echo    CUSTOM PORT
echo  -----------------------------------------------------
echo    SSH uses port 22 by default. Say yes only if your
echo    server uses a different port (e.g. 2222, 8022).
echo    If unsure, say no port 22 will be used.
echo  -----------------------------------------------------
echo.
set /p "CUSTOM_PORT=  Use a custom port? (yes/no): "
call :YES_CHECK "%CUSTOM_PORT%"
if "%IS_YES%"=="1" (
:ADD_PORT_LOOP
    set /p "NEW_PORT=  Port number: "
    call :VALIDATE_PORT "%NEW_PORT%"
    if "%PORT_VALID%"=="0" (
        echo  [X] Invalid port. Enter a number between 1 and 65535.
        goto ADD_PORT_LOOP
    )
)

echo.
echo  -----------------------------------------------------
echo    IDENTITY FILE / PASSKEY
echo  -----------------------------------------------------
echo    A private key lets you log in without a password.
echo    If you use SSH key auth on this server, say yes.
echo    If you log in with a password, say no.
echo.
echo    Keys listed are from your ~/.ssh folder. Enter the
echo    name shown exactly (without .pub).
echo  -----------------------------------------------------
echo.
set /p "USE_KEY=  Use a private key / passkey? (yes/no): "
call :YES_CHECK "%USE_KEY%"
if "%IS_YES%"=="1" call :PICK_ADD_KEY

echo.>> "%CONFIG_FILE%"
echo Host %NEW_NAME%>> "%CONFIG_FILE%"
echo     HostName %NEW_IP%>> "%CONFIG_FILE%"
if not "%NEW_USER%"=="" echo     User %NEW_USER%>> "%CONFIG_FILE%"
echo     Port %NEW_PORT%>> "%CONFIG_FILE%"
if not "%NEW_KEY%"==""  echo     IdentityFile ~/.ssh/%NEW_KEY%>> "%CONFIG_FILE%"

call :PRINT_HEADER
echo  [+] SUCCESS! Server "%NEW_NAME%" has been saved to config.
echo.
echo  -----------------------------------------------------
echo    SAVED ENTRY
echo  -----------------------------------------------------
echo    Alias    : %NEW_NAME%
echo    Host     : %NEW_IP%
echo    User     : %NEW_USER%
echo    Port     : %NEW_PORT%
if not "%NEW_KEY%"=="" echo    Key      : %SSH_DIR%\%NEW_KEY%
echo.
echo  =====================================================
echo.
pause
goto MAIN_MENU

:DUPE_PROMPT_ADD
echo.
echo  -----------------------------------------------------
echo  [!] A server with that name or IP already exists.
echo  -----------------------------------------------------
echo.
echo    [1]  Edit the existing entry
echo    [2]  Go back to the main menu
echo.
echo  -----------------------------------------------------
echo.
set /p "DUPE_CHOICE=  Your choice (1 or 2): "
if "%DUPE_CHOICE%"=="1" ( set "EDIT_TARGET=%NEW_NAME%" & goto DO_EDIT )
goto MAIN_MENU


:: ============================================================
:MANUAL_CONNECT
:: ============================================================
call :PRINT_HEADER
echo  =====================================================
echo    Connect to a Server Manually
echo  =====================================================
echo.
echo    Connect to a server right now without saving it.
echo    You will have the option to save it afterwards.
echo    Type "back" or "exit" at any prompt to cancel.
echo.
echo  -----------------------------------------------------
echo    SERVER DETAILS
echo  -----------------------------------------------------
echo.

set "MAN_USER=" & set "MAN_IP=" & set "MAN_PORT=22" & set "MAN_KEY_NAME=" & set "MAN_KEY_PATH=" & set "MAN_ALIAS="

echo    USERNAME
echo    The account name you log in with on the remote server.
echo    Example: root, admin, ubuntu, pi
echo.
set /p "MAN_USER=  Username: "
if /i "%MAN_USER%"=="back" goto MAIN_MENU
if /i "%MAN_USER%"=="exit" goto MAIN_MENU
if "%MAN_USER%"=="" goto MANUAL_CONNECT

echo.
echo    SERVER IP / HOSTNAME
echo    The IP address or domain name of the server.
echo    Example: 192.168.1.10  or  myserver.example.com
echo.
set /p "MAN_IP=  Server IP or hostname: "
if /i "%MAN_IP%"=="back" goto MAIN_MENU
if /i "%MAN_IP%"=="exit" goto MAIN_MENU
if "%MAN_IP%"=="" goto MANUAL_CONNECT

echo.
echo  -----------------------------------------------------
echo    CUSTOM PORT
echo  -----------------------------------------------------
echo    SSH uses port 22 by default. Say yes only if your
echo    server uses a different port. If unsure, say no.
echo  -----------------------------------------------------
echo.
set /p "MAN_CUSTOM_PORT=  Use a custom port? (yes/no): "
call :YES_CHECK "%MAN_CUSTOM_PORT%"
if "%IS_YES%"=="1" (
:MAN_PORT_LOOP
    set /p "MAN_PORT=  Port number: "
    call :VALIDATE_PORT "%MAN_PORT%"
    if "%PORT_VALID%"=="0" (
        echo  [X] Invalid port. Enter a number between 1 and 65535.
        goto MAN_PORT_LOOP
    )
)

echo.
echo  -----------------------------------------------------
echo    IDENTITY FILE / PASSKEY
echo  -----------------------------------------------------
echo    A private key lets you log in without a password.
echo    If you use SSH key auth on this server, say yes.
echo    Keys listed are from your ~/.ssh folder. Enter the
echo    name shown exactly (without .pub).
echo  -----------------------------------------------------
echo.
set /p "MAN_USE_KEY=  Use a private key / passkey? (yes/no): "
call :YES_CHECK "%MAN_USE_KEY%"
if "%IS_YES%"=="1" call :PICK_MAN_KEY

call :PRINT_HEADER
echo  [~] Connecting to %MAN_USER%@%MAN_IP% on port %MAN_PORT% ...
echo.
echo  =====================================================
echo.
if not "%MAN_KEY_PATH%"=="" (
    ssh -p "%MAN_PORT%" -i "%MAN_KEY_PATH%" "%MAN_USER%@%MAN_IP%"
) else (
    ssh -p "%MAN_PORT%" "%MAN_USER%@%MAN_IP%"
)
echo.
echo  =====================================================
echo  [i] Session ended.
echo  =====================================================
echo.

echo  -----------------------------------------------------
echo    SAVE THIS SERVER?
echo  -----------------------------------------------------
echo    Say yes to save these details to your SSH config
echo    so you can connect by name next time (option 1).
echo    Say no to discard nothing will be saved.
echo  -----------------------------------------------------
echo.
set /p "MAN_SAVE=  Save this server to config? (yes/no): "
call :YES_CHECK "%MAN_SAVE%"
if "%IS_YES%"=="0" goto MAIN_MENU

echo.
echo  -----------------------------------------------------
echo    SERVER NAME / ALIAS
echo  -----------------------------------------------------
echo    Choose a short nickname for this server.
echo    Example: homeserver, vps1, work-box. No spaces.
echo  -----------------------------------------------------
echo.

:MAN_ALIAS_PROMPT
set /p "MAN_ALIAS=  Alias / name for this server: "
if /i "%MAN_ALIAS%"=="back" goto MAIN_MENU
if /i "%MAN_ALIAS%"=="exit" goto MAIN_MENU
if "%MAN_ALIAS%"=="" (
    echo  [!] Name cannot be blank.
    goto MAN_ALIAS_PROMPT
)
call :SANITIZE_CHECK "%MAN_ALIAS%"
if "%SANITIZE_FAIL%"=="1" (
    echo  [X] Name cannot contain special characters ^(^& ^| ^> ^<^).
    goto MAN_ALIAS_PROMPT
)

call :CHECK_DUPLICATE "%MAN_ALIAS%" "%MAN_IP%"
if "%DUPE_FOUND%"=="1" (
    echo.
    echo  [!] A server with that name or IP already exists. Not saving.
    echo.
    pause
    goto MAIN_MENU
)

echo.>> "%CONFIG_FILE%"
echo Host %MAN_ALIAS%>> "%CONFIG_FILE%"
echo     HostName %MAN_IP%>> "%CONFIG_FILE%"
echo     User %MAN_USER%>> "%CONFIG_FILE%"
echo     Port %MAN_PORT%>> "%CONFIG_FILE%"
if not "%MAN_KEY_NAME%"=="" echo     IdentityFile ~/.ssh/%MAN_KEY_NAME%>> "%CONFIG_FILE%"

call :PRINT_HEADER
echo  [+] SUCCESS! Server "%MAN_ALIAS%" has been saved to config.
echo.
echo  =====================================================
echo.
pause
goto MAIN_MENU


:: ============================================================
:EDIT_REMOVE
:: ============================================================
call :PRINT_HEADER
echo  =====================================================
echo    Edit / Remove a Saved Server
echo  =====================================================
echo.
echo    Type the name of the server you want to change or delete.
echo    Edit update its saved details.
echo    Remove permanently delete it from your config.
echo.
echo  -----------------------------------------------------
echo    SAVED SERVERS
echo  -----------------------------------------------------
echo.

call :LIST_HOSTS

if "%HOST_COUNT%"=="0" (
    echo.
    echo  [!] No saved servers found. Nothing to edit or remove.
    echo.
    echo  =====================================================
    echo.
    pause
    goto MAIN_MENU
)

echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "ER_NAME=  Server name to edit or remove: "

if /i "%ER_NAME%"=="b"    goto MAIN_MENU
if /i "%ER_NAME%"=="back" goto MAIN_MENU
if /i "%ER_NAME%"=="m"    goto MAIN_MENU
if /i "%ER_NAME%"=="main" goto MAIN_MENU
if /i "%ER_NAME%"=="menu" goto MAIN_MENU
if /i "%ER_NAME%"=="e"    goto EXIT_SCRIPT
if /i "%ER_NAME%"=="exit" goto EXIT_SCRIPT
if "%ER_NAME%"==""        goto EDIT_REMOVE

call :HOST_EXISTS "%ER_NAME%"
if "%HOST_FOUND%"=="0" (
    echo.
    echo  [X] Server "%ER_NAME%" was not found in your config.
    echo.
    pause
    goto EDIT_REMOVE
)

echo.
echo  -----------------------------------------------------
echo    What would you like to do with "%ER_NAME%"?
echo  -----------------------------------------------------
echo.
echo    [1]  Edit this server
echo         Update the name, IP, username, port, or key.
echo.
echo    [2]  Remove this server
echo         Permanently delete it from your SSH config.
echo.
echo    [3]  Go back
echo.
echo  -----------------------------------------------------
echo.
set /p "ER_CHOICE=  Your choice (1, 2 or 3): "

if "%ER_CHOICE%"=="1" ( set "EDIT_TARGET=%ER_NAME%" & goto DO_EDIT )
if "%ER_CHOICE%"=="2" goto DO_REMOVE
goto MAIN_MENU


:: ============================================================
:DO_EDIT
:: ============================================================
set "CUR_HOSTNAME=" & set "CUR_USER=" & set "CUR_PORT=22" & set "CUR_KEY=" & set "IN_BLOCK=0"

for /f "usebackq tokens=1,* delims= " %%A in ("%CONFIG_FILE%") do (
    set "T1=%%A" & set "T2=%%B"
    if /i "!T1!"=="Host" (
        if /i "!T2!"=="%EDIT_TARGET%" ( set "IN_BLOCK=1" ) else ( set "IN_BLOCK=0" )
    )
    if "!IN_BLOCK!"=="1" (
        if /i "!T1!"=="HostName"     set "CUR_HOSTNAME=!T2!"
        if /i "!T1!"=="User"         set "CUR_USER=!T2!"
        if /i "!T1!"=="Port"         set "CUR_PORT=!T2!"
        if /i "!T1!"=="IdentityFile" set "CUR_KEY=!T2!"
    )
)

call :PRINT_HEADER
echo  =====================================================
echo    Edit Server: %EDIT_TARGET%
echo  =====================================================
echo.
echo  -----------------------------------------------------
echo    CURRENT VALUES
echo  -----------------------------------------------------
echo    Alias    : %EDIT_TARGET%
echo    Host     : %CUR_HOSTNAME%
echo    User     : %CUR_USER%
echo    Port     : %CUR_PORT%
echo    Key      : %CUR_KEY%
echo.
echo  -----------------------------------------------------
echo    EDIT FIELDS
echo  -----------------------------------------------------
echo    Press ENTER to keep current value, or type a new one.
echo    Type "back" to cancel.
echo.
echo  -----------------------------------------------------
echo.

set "EDIT_NAME=" & set "EDIT_IP=" & set "EDIT_USER=" & set "EDIT_PORT=" & set "EDIT_KEY="

set /p "EDIT_NAME=  New alias/name       (blank = keep '%EDIT_TARGET%'): "
if /i "%EDIT_NAME%"=="back" goto EDIT_ABORT
if /i "%EDIT_NAME%"=="exit" goto EDIT_ABORT

set /p "EDIT_IP=  New IP / hostname    (blank = keep '%CUR_HOSTNAME%'): "
if /i "%EDIT_IP%"=="back" goto EDIT_ABORT
if /i "%EDIT_IP%"=="exit" goto EDIT_ABORT

set /p "EDIT_USER=  New username         (blank = keep '%CUR_USER%'): "
if /i "%EDIT_USER%"=="back" goto EDIT_ABORT
if /i "%EDIT_USER%"=="exit" goto EDIT_ABORT

set /p "EDIT_PORT=  New port             (blank = keep '%CUR_PORT%'): "
if /i "%EDIT_PORT%"=="back" goto EDIT_ABORT
if /i "%EDIT_PORT%"=="exit" goto EDIT_ABORT

echo.
echo  -----------------------------------------------------
echo    IDENTITY FILE (SSH KEY)
echo  -----------------------------------------------------
echo    Current key: %CUR_KEY%
echo.
echo    yes   = choose a new key from your ~/.ssh folder
echo    no    = remove the key (log in by password instead)
echo    Enter = keep the current key unchanged
echo  -----------------------------------------------------
echo.
set "EDIT_KEY_ACTION="
set /p "EDIT_KEY_ACTION=  Change identity file? (yes/no/Enter to skip): "
if /i "!EDIT_KEY_ACTION!"=="back" goto EDIT_ABORT
if /i "!EDIT_KEY_ACTION!"=="exit" goto EDIT_ABORT
if /i "!EDIT_KEY_ACTION!"=="no" set "EDIT_KEY=__REMOVE__"
call :YES_CHECK "!EDIT_KEY_ACTION!"
if "!IS_YES!"=="1" call :PICK_EDIT_KEY
if "!EDIT_KEY_ABORT!"=="1" goto EDIT_ABORT

if "%EDIT_NAME%"=="" set "EDIT_NAME=%EDIT_TARGET%"
if "%EDIT_IP%"==""   set "EDIT_IP=%CUR_HOSTNAME%"
if "%EDIT_USER%"=="" set "EDIT_USER=%CUR_USER%"
if "%EDIT_PORT%"=="" set "EDIT_PORT=%CUR_PORT%"
if "%EDIT_KEY%"==""           set "EDIT_KEY=%CUR_KEY%"
if "%EDIT_KEY%"=="__REMOVE__" set "EDIT_KEY="

call :REMOVE_HOST "%EDIT_TARGET%"

echo.>> "%CONFIG_FILE%"
echo Host %EDIT_NAME%>> "%CONFIG_FILE%"
echo     HostName %EDIT_IP%>> "%CONFIG_FILE%"
if not "%EDIT_USER%"=="" echo     User %EDIT_USER%>> "%CONFIG_FILE%"
echo     Port %EDIT_PORT%>> "%CONFIG_FILE%"
if not "%EDIT_KEY%"==""  echo     IdentityFile %EDIT_KEY%>> "%CONFIG_FILE%"

call :PRINT_HEADER
echo  [+] Server "%EDIT_NAME%" has been updated successfully.
echo.
echo  -----------------------------------------------------
echo    UPDATED ENTRY
echo  -----------------------------------------------------
echo    Alias    : %EDIT_NAME%
echo    Host     : %EDIT_IP%
echo    User     : %EDIT_USER%
echo    Port     : %EDIT_PORT%
if not "%EDIT_KEY%"=="" echo    Key      : %EDIT_KEY%
echo.
echo  =====================================================
echo.
pause
goto MAIN_MENU

:EDIT_ABORT
echo.
echo  [!] Edit cancelled. No changes were made.
echo.
pause
goto MAIN_MENU


:: ============================================================
:DO_REMOVE
:: ============================================================
set "REMOVE_IP=" & set "IN_BLOCK=0"
for /f "usebackq tokens=1,* delims= " %%A in ("%CONFIG_FILE%") do (
    set "T1=%%A" & set "T2=%%B"
    if /i "!T1!"=="Host" (
        if /i "!T2!"=="%ER_NAME%" ( set "IN_BLOCK=1" ) else ( set "IN_BLOCK=0" )
    )
    if "!IN_BLOCK!"=="1" if /i "!T1!"=="HostName" set "REMOVE_IP=!T2!"
)

call :REMOVE_HOST "%ER_NAME%"

call :PRINT_HEADER
echo  [-] Server "%ER_NAME%" has been removed from config.
echo.
echo  -----------------------------------------------------
echo    KNOWN HOSTS CLEANUP
echo  -----------------------------------------------------
echo    Your known_hosts file stores the fingerprint of
echo    every server you have connected to. If you are
echo    permanently removing this server, it is good
echo    practice to also remove its fingerprint entry.
echo.
if not "%REMOVE_IP%"=="" (
    echo    Server IP: %REMOVE_IP%
) else (
    echo    [!] Could not determine server IP - known_hosts
    echo        cleanup is not available for this entry.
)
echo  -----------------------------------------------------
echo.

if "%REMOVE_IP%"=="" (
    pause
    goto MAIN_MENU
)

set /p "KH_CHOICE=  Also remove from known_hosts? (yes/no): "
call :YES_CHECK "%KH_CHOICE%"
if "%IS_YES%"=="0" (
    echo.
    echo  [i] known_hosts left unchanged.
    echo.
    pause
    goto MAIN_MENU
)

echo.
echo  [~] Removing "%REMOVE_IP%" from known_hosts...
ssh-keygen -R "%REMOVE_IP%" >nul 2>&1
if errorlevel 1 (
    echo  [!] Could not remove from known_hosts. The entry may
    echo      not exist, or ssh-keygen was not found.
) else (
    echo  [+] Fingerprint for "%REMOVE_IP%" removed from known_hosts.
)
echo.
echo  =====================================================
echo.
pause
goto MAIN_MENU


:: ============================================================
::  SUBROUTINES
:: ============================================================

:: Clears screen and prints the standard script header
:PRINT_HEADER
cls
echo.
echo           %TITLE% %VERSION%
echo.
echo  =====================================================
echo    %TITLE%
echo  =====================================================
echo.
exit /b 0


:: Sets IS_YES=1 for y/yes, 0 otherwise
:YES_CHECK
set "IS_YES=0"
if /i "%~1"=="y"   set "IS_YES=1"
if /i "%~1"=="yes" set "IS_YES=1"
goto :EOF


:: Sets SANITIZE_FAIL=1 if value contains shell-special characters
:SANITIZE_CHECK
set "SANITIZE_FAIL=0"
set "_SC=%~1"
echo !_SC! | findstr /r "[&|<>]" >nul 2>&1
if not errorlevel 1 set "SANITIZE_FAIL=1"
exit /b 0


:: Prints all Host entries from config; sets HOST_COUNT
:LIST_HOSTS
set "HOST_COUNT=0"
for /f "tokens=2" %%H in ('findstr /b /i "Host " "%CONFIG_FILE%"') do (
    echo    %%H
    set /a HOST_COUNT+=1
)
if "%HOST_COUNT%"=="0" echo    (none)
exit /b 0


:: Sets HOST_FOUND=1 if name found in config
:HOST_EXISTS
set "HOST_FOUND=0"
for /f "tokens=2" %%H in ('findstr /b /i "Host " "%CONFIG_FILE%"') do (
    if /i "%%H"=="%~1" set "HOST_FOUND=1"
)
exit /b 0


:: Sets DUPE_FOUND=1 if name or IP already exists in config
:CHECK_DUPLICATE
set "DUPE_FOUND=0"
for /f "tokens=2" %%H in ('findstr /b /i "Host " "%CONFIG_FILE%"') do (
    if /i "%%H"=="%~1" set "DUPE_FOUND=1"
)
for /f "tokens=2" %%I in ('findstr /i "HostName" "%CONFIG_FILE%"') do (
    if /i "%%I"=="%~2" set "DUPE_FOUND=1"
)
exit /b 0


:: Lists .pub files in SSH_DIR without extension; sets KEY_COUNT
:LIST_KEYS
set "KEY_COUNT=0"
echo.
echo  -----------------------------------------------------
echo    AVAILABLE KEYS in %SSH_DIR%
echo  -----------------------------------------------------
echo    Names shown without .pub - the private key will
echo    be used automatically for authentication.
echo  -----------------------------------------------------
echo.
for %%F in ("%SSH_DIR%\*.pub") do (
    echo    %%~nF
    set /a KEY_COUNT+=1
)
if "%KEY_COUNT%"=="0" echo    (no key pairs found in %SSH_DIR%)
echo.
echo  -----------------------------------------------------
echo.
exit /b 0


:: Removes a Host block from config via PowerShell temp script
:REMOVE_HOST
set "RH_TARGET=%~1"
set "PS_SCRIPT=%TEMP%\SSH_Connection_Manager_Remove.ps1"
if exist "%PS_SCRIPT%" del "%PS_SCRIPT%"

echo $target = $args[0].ToLower()                                           >> "%PS_SCRIPT%"
echo $cfg    = $args[1]                                                     >> "%PS_SCRIPT%"
echo $lines  = [System.IO.File]::ReadAllLines($cfg)                        >> "%PS_SCRIPT%"
echo $out    = [System.Collections.Generic.List[string]]::new()            >> "%PS_SCRIPT%"
echo $skip   = $false                                                       >> "%PS_SCRIPT%"
echo foreach ($line in $lines) {                                            >> "%PS_SCRIPT%"
echo     $t = $line.Trim().ToLower()                                        >> "%PS_SCRIPT%"
echo     if ($t -match '^host\s+(\S+)') {                                   >> "%PS_SCRIPT%"
echo         $skip = ($matches[1] -eq $target)                              >> "%PS_SCRIPT%"
echo     }                                                                  >> "%PS_SCRIPT%"
echo     if (-not $skip) { $out.Add($line) }                               >> "%PS_SCRIPT%"
echo }                                                                      >> "%PS_SCRIPT%"
echo while ($out.Count -gt 0 -and $out[$out.Count-1].Trim() -eq '') {      >> "%PS_SCRIPT%"
echo     $out.RemoveAt($out.Count-1)                                        >> "%PS_SCRIPT%"
echo }                                                                      >> "%PS_SCRIPT%"
echo [System.IO.File]::WriteAllLines($cfg, $out, [System.Text.Encoding]::UTF8) >> "%PS_SCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" "%RH_TARGET%" "%CONFIG_FILE%"
if errorlevel 1 (
    echo.
    echo  [X] ERROR: Failed to remove entry. PowerShell returned an error.
    echo.
    pause
)
del "%PS_SCRIPT%" 2>nul
exit /b 0


:: Key picker for ADD_SERVER; sets NEW_KEY
:PICK_ADD_KEY
call :LIST_KEYS
if "!KEY_COUNT!"=="0" ( echo  [!] No key files found in %SSH_DIR%. Skipping. & exit /b 0 )
:ADD_KEY_LOOP
set "NEW_KEY="
set /p "NEW_KEY=  Enter key name from list above: "
if /i "!NEW_KEY!"=="back" goto MAIN_MENU
if /i "!NEW_KEY!"=="exit" goto MAIN_MENU
if "!NEW_KEY!"=="" ( echo  [!] Name cannot be blank. Try again or type "back" to cancel. & goto ADD_KEY_LOOP )
if not exist "%SSH_DIR%\!NEW_KEY!" ( echo  [X] Key "!NEW_KEY!" was not found. Check the name and try again. & goto ADD_KEY_LOOP )
exit /b 0


:: Key picker for MANUAL_CONNECT; sets MAN_KEY_NAME, MAN_KEY_PATH
:PICK_MAN_KEY
set "MAN_KEY_NAME=" & set "MAN_KEY_PATH="
call :LIST_KEYS
if "!KEY_COUNT!"=="0" ( echo  [!] No key files found in %SSH_DIR%. Skipping. & exit /b 0 )
:MAN_KEY_LOOP
set "MAN_KEY_NAME="
set /p "MAN_KEY_NAME=  Enter key name from list above: "
if /i "!MAN_KEY_NAME!"=="back" goto MAIN_MENU
if /i "!MAN_KEY_NAME!"=="exit" goto MAIN_MENU
if "!MAN_KEY_NAME!"=="" ( echo  [!] Name cannot be blank. Try again or type "back" to cancel. & goto MAN_KEY_LOOP )
if not exist "%SSH_DIR%\!MAN_KEY_NAME!" ( echo  [X] Key "!MAN_KEY_NAME!" was not found. Check the name and try again. & goto MAN_KEY_LOOP )
set "MAN_KEY_PATH=%SSH_DIR%\!MAN_KEY_NAME!"
exit /b 0


:: Key picker for DO_EDIT; sets EDIT_KEY, EDIT_KEY_ABORT=1 on cancel
:PICK_EDIT_KEY
set "EDIT_KEY_ABORT=0"
call :LIST_KEYS
if "!KEY_COUNT!"=="0" exit /b 0
:EDIT_KEY_LOOP
set "EDIT_KEY_NAME="
set /p "EDIT_KEY_NAME=  Key name: "
if /i "!EDIT_KEY_NAME!"=="back" ( set "EDIT_KEY_ABORT=1" & exit /b 0 )
if /i "!EDIT_KEY_NAME!"=="exit" ( set "EDIT_KEY_ABORT=1" & exit /b 0 )
if "!EDIT_KEY_NAME!"=="" ( echo  [!] Name cannot be blank. Try again or type "back" to cancel. & goto EDIT_KEY_LOOP )
if not exist "%SSH_DIR%\!EDIT_KEY_NAME!" ( echo  [X] Key "!EDIT_KEY_NAME!" was not found. Check the name and try again. & goto EDIT_KEY_LOOP )
set "EDIT_KEY=~/.ssh/!EDIT_KEY_NAME!"
exit /b 0


:: Sets PORT_VALID=1 if value is a number between 1 and 65535
:VALIDATE_PORT
set "PORT_VALID=0"
set "_P=%~1"
if "%_P%"=="" goto :EOF
for /f "delims=0123456789" %%C in ("%_P%") do goto :EOF
if %_P% GEQ 1 if %_P% LEQ 65535 set "PORT_VALID=1"
goto :EOF


:: ============================================================
:EXIT_SCRIPT
:: ============================================================
call :PRINT_HEADER
echo    Goodbye!
echo.
echo  =====================================================
echo.
pause
exit /b 0
