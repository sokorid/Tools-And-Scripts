@echo off
setlocal enabledelayedexpansion
title SSH Key Generator
color f

:: ============================================================
:: Author:  sokor | github.com/sokorid | codeberg.org/sokorid
:: License: MIT (https://opensource.org/licenses/MIT)
:: Notice:  Provided "as is", without warranty of any kind.
:: ============================================================
::  SSH_Key_Generator.bat — Generates Ed25519 or RSA SSH keys
:: ============================================================

:: ============================================================
:: CONFIGURATION
:: ============================================================
set "TITLE=SSH Key Generator"
set "VERSION=v2.0"
set "SSH_DIR=%USERPROFILE%\.ssh"

:: ============================================================
:MAIN_MENU
:: ============================================================
call :PRINT_HEADER
echo    Generates a secure SSH key for connecting to
echo    servers without a password and better security.
echo.
echo  -----------------------------------------------------
echo    Choose your key type:
echo.
echo    [1]  Ed25519  ^(Recommended^)
echo         Modern, fast, and highly secure.
echo.
echo    [2]  RSA 4096
echo         Older standard. Use if Ed25519 is unsupported.
echo.
echo    [3]  List Existing Keys
echo         View any SSH keys already on this machine.
echo.
echo    [4]  Exit
echo.
echo  -----------------------------------------------------
echo.
set /p "CHOICE=  Your choice (1, 2, 3 or 4): "

if "%CHOICE%"=="1" goto GEN_ED25519
if "%CHOICE%"=="2" goto GEN_RSA
if "%CHOICE%"=="3" goto LIST_KEYS
if "%CHOICE%"=="4" goto EXIT_SCRIPT

echo.
echo  [X] Invalid choice. Enter 1, 2, 3 or 4.
echo.
pause & goto MAIN_MENU


:: ============================================================
:GEN_ED25519
:: ============================================================
set "KEY_TYPE=Ed25519"
set "KEY_FILE=%SSH_DIR%\id_ed25519"
set "KEYGEN_ARGS=-t ed25519"
goto NAME_KEY


:: ============================================================
:GEN_RSA
:: ============================================================
set "KEY_TYPE=RSA 4096"
set "KEY_FILE=%SSH_DIR%\id_rsa"
set "KEYGEN_ARGS=-t rsa -b 4096"
goto NAME_KEY


:: ============================================================
:LIST_KEYS
:: ============================================================
call :PRINT_HEADER
echo  -----------------------------------------------------
echo    EXISTING SSH KEYS
echo  -----------------------------------------------------
echo.
if not exist "%SSH_DIR%" (
    echo  [!] SSH folder not found: %SSH_DIR%
    echo      No keys have been generated on this machine yet.
    echo.
    pause
    goto MAIN_MENU
)
set "FOUND_KEYS=0"
for %%F in ("%SSH_DIR%\*.pub") do (
    set "FOUND_KEYS=1"
    echo  Key: %%F
    echo.
    echo    Public Key:
    type "%%F"
    echo.
    echo    Fingerprint:
    ssh-keygen -lf "%%F"
    echo.
    echo  -----------------------------------------------------
    echo.
)
if "%FOUND_KEYS%"=="0" echo  [!] No SSH keys found on this machine.
echo.
pause
goto MAIN_MENU


:: ============================================================
:NAME_KEY
:: ============================================================
call :PRINT_HEADER
echo  -----------------------------------------------------
echo    KEY FILE NAME
echo  -----------------------------------------------------
echo    Press ENTER for default, or enter a custom name.
echo    Default: %KEY_FILE%
echo    Custom names saved to: %SSH_DIR%\^<name^>
echo.
echo    Rules: letters, numbers, hyphens, underscores.
echo    Spaces allowed. No special characters ^(^& ^| ^> ^< %% ^^^).
echo.
echo  -----------------------------------------------------
echo    EXISTING KEY NAMES
echo  -----------------------------------------------------
set "ANY_KEYS=0"
for %%F in ("%SSH_DIR%\*.pub") do (
    set "ANY_KEYS=1"
    echo    %%~nF
)
if "%ANY_KEYS%"=="0" echo    None found
echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "CUSTOM_NAME=  Custom name (or press ENTER for default): "

if /i "%CUSTOM_NAME%"=="b"    goto MAIN_MENU
if /i "%CUSTOM_NAME%"=="back" goto MAIN_MENU
if /i "%CUSTOM_NAME%"=="m"    goto MAIN_MENU
if /i "%CUSTOM_NAME%"=="main" goto MAIN_MENU
if /i "%CUSTOM_NAME%"=="menu" goto MAIN_MENU
if /i "%CUSTOM_NAME%"=="e"    goto EXIT_SCRIPT
if /i "%CUSTOM_NAME%"=="end"  goto EXIT_SCRIPT
if /i "%CUSTOM_NAME%"=="exit" goto EXIT_SCRIPT
if    "%CUSTOM_NAME%"==""     goto CHECK_EXISTS

call :VALIDATE_NAME "%CUSTOM_NAME%"
if errorlevel 1 (
    echo.
    echo  [X] Invalid name. Avoid special characters ^(^& ^| ^> ^< %% ^^^).
    echo.
    pause
    goto NAME_KEY
)
goto APPEND_TYPE


:: ============================================================
:APPEND_TYPE
:: ============================================================
call :PRINT_HEADER
echo  -----------------------------------------------------
echo    APPEND ENCRYPTION TYPE TO NAME?
echo  -----------------------------------------------------
echo    [1]  Yes  e.g. %CUSTOM_NAME%_ed25519 / %CUSTOM_NAME%_rsa4096
echo    [2]  No   Keep name as typed
echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "APPEND_CHOICE=  Your choice (1 or 2): "

if /i "%APPEND_CHOICE%"=="b"    goto NAME_KEY
if /i "%APPEND_CHOICE%"=="back" goto NAME_KEY
if /i "%APPEND_CHOICE%"=="m"    goto MAIN_MENU
if /i "%APPEND_CHOICE%"=="main" goto MAIN_MENU
if /i "%APPEND_CHOICE%"=="menu" goto MAIN_MENU
if /i "%APPEND_CHOICE%"=="e"    goto EXIT_SCRIPT
if /i "%APPEND_CHOICE%"=="end"  goto EXIT_SCRIPT
if /i "%APPEND_CHOICE%"=="exit" goto EXIT_SCRIPT
if "%APPEND_CHOICE%"=="1" (
    if "%KEY_TYPE%"=="Ed25519"  set "CUSTOM_NAME=%CUSTOM_NAME%_ed25519"
    if "%KEY_TYPE%"=="RSA 4096" set "CUSTOM_NAME=%CUSTOM_NAME%_rsa4096"
    goto SET_KEY_FILE
)
if "%APPEND_CHOICE%"=="2" goto SET_KEY_FILE

echo.
echo  [X] Invalid choice. Enter 1 or 2.
echo.
goto APPEND_TYPE

:SET_KEY_FILE
set "KEY_FILE=%SSH_DIR%\%CUSTOM_NAME%"


:: ============================================================
:CHECK_EXISTS
:: ============================================================
call :PRINT_HEADER
if exist "%KEY_FILE%" goto SHOW_EXISTING


:: ============================================================
:KEY_COMMENT
:: ============================================================
echo  -----------------------------------------------------
echo    KEY COMMENT ^(-C^)
echo  -----------------------------------------------------
echo    A label embedded in your public key for identification.
echo    Has no effect on security.
echo.
echo    [1]  Default  %USERNAME%@%COMPUTERNAME%
echo    [2]  Custom   e.g. your@email.com, work-laptop, github-personal
echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "COMMENT_CHOICE=  Your choice (1 or 2): "

if /i "%COMMENT_CHOICE%"=="b"    goto NAME_KEY
if /i "%COMMENT_CHOICE%"=="back" goto NAME_KEY
if /i "%COMMENT_CHOICE%"=="m"    goto MAIN_MENU
if /i "%COMMENT_CHOICE%"=="main" goto MAIN_MENU
if /i "%COMMENT_CHOICE%"=="menu" goto MAIN_MENU
if /i "%COMMENT_CHOICE%"=="e"    goto EXIT_SCRIPT
if /i "%COMMENT_CHOICE%"=="end"  goto EXIT_SCRIPT
if /i "%COMMENT_CHOICE%"=="exit" goto EXIT_SCRIPT
if "%COMMENT_CHOICE%"=="1" (
    set "KEY_COMMENT=%USERNAME%@%COMPUTERNAME%"
    goto PASSPHRASE_INFO
)
if "%COMMENT_CHOICE%"=="2" goto CUSTOM_COMMENT

echo.
echo  [X] Invalid choice. Enter 1 or 2.
echo.
goto KEY_COMMENT


:: ============================================================
:CUSTOM_COMMENT
:: ============================================================
echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu   [E] Exit
echo  -----------------------------------------------------
echo.
set /p "CUSTOM_COMMENT=  Enter your comment: "

if /i "%CUSTOM_COMMENT%"=="b"    goto KEY_COMMENT
if /i "%CUSTOM_COMMENT%"=="back" goto KEY_COMMENT
if /i "%CUSTOM_COMMENT%"=="m"    goto MAIN_MENU
if /i "%CUSTOM_COMMENT%"=="main" goto MAIN_MENU
if /i "%CUSTOM_COMMENT%"=="menu" goto MAIN_MENU
if /i "%CUSTOM_COMMENT%"=="e"    goto EXIT_SCRIPT
if /i "%CUSTOM_COMMENT%"=="end"  goto EXIT_SCRIPT
if /i "%CUSTOM_COMMENT%"=="exit" goto EXIT_SCRIPT
if "%CUSTOM_COMMENT%"=="" (
    set "KEY_COMMENT=%USERNAME%@%COMPUTERNAME%"
    echo.
    echo  [i] No input entered. Using default: %USERNAME%@%COMPUTERNAME%
    echo.
    goto PASSPHRASE_INFO
)

call :VALIDATE_COMMENT "%CUSTOM_COMMENT%"
if errorlevel 1 (
    echo.
    echo  [X] Invalid comment. Avoid special characters ^(^& ^| ^> ^<^).
    echo.
    pause
    goto CUSTOM_COMMENT
)
set "KEY_COMMENT=%CUSTOM_COMMENT%"


:: ============================================================
:PASSPHRASE_INFO
:: ============================================================
call :PRINT_HEADER
echo  -----------------------------------------------------
echo    ABOUT PASSPHRASES
echo  -----------------------------------------------------
echo    ssh-keygen will ask you to set a passphrase.
echo    This protects your key file if it is ever stolen.
echo.
echo    * Press ENTER twice to skip ^(no passphrase^)
echo    * Or type a strong password to protect your key
echo.
echo    Tip: Skip for automated scripts. Set one for personal keys.
echo  -----------------------------------------------------
echo.
pause

if not exist "%SSH_DIR%" (
    mkdir "%SSH_DIR%"
    icacls "%SSH_DIR%" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo  [!] Warning: Could not set secure permissions on %SSH_DIR%.
        echo      Your key folder may be readable by other users.
        echo.
        echo      It is strongly recommended to fix permissions before continuing.
        echo      Press any key to abort, or close this window to cancel.
        echo.
        echo  -----------------------------------------------------
        echo    [C] Continue anyway   [A] Abort
        echo  -----------------------------------------------------
        echo.
        set /p "PERM_CHOICE=  Your choice: "
        if /i "!PERM_CHOICE!"=="a"        goto MAIN_MENU
        if /i "!PERM_CHOICE!"=="abort"    goto MAIN_MENU
        if /i "!PERM_CHOICE!"=="c"        goto DO_KEYGEN
        if /i "!PERM_CHOICE!"=="continue" goto DO_KEYGEN
        goto MAIN_MENU
    )
)

:DO_KEYGEN
ssh-keygen %KEYGEN_ARGS% -f "%KEY_FILE%" -C "%KEY_COMMENT%"

if errorlevel 1 (
    echo.
    echo  [X] Key generation failed. Please try again.
    echo.
    pause
    goto MAIN_MENU
)

call :PRINT_HEADER
echo  [+] SUCCESS! Your %KEY_TYPE% key has been created.
echo.
call :SHOW_KEY_INFO
echo  =====================================================
echo    All done! Copy the public key above to your server.
echo  =====================================================
echo.
pause
goto MAIN_MENU


:: ============================================================
:SHOW_EXISTING
:: ============================================================
echo  [!] A %KEY_TYPE% key already exists. No new key was created.
echo.
call :SHOW_KEY_INFO
echo  -----------------------------------------------------
echo    To generate a key with a different name, go back
echo    and choose a custom name on the previous screen.
echo  -----------------------------------------------------
echo.
pause
goto MAIN_MENU


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


:: Displays public key, copies to clipboard, shows fingerprint
:SHOW_KEY_INFO
echo  -----------------------------------------------------
echo    KEY LOCATION
echo  -----------------------------------------------------
echo    Private key : %KEY_FILE%
echo    Public key  : %KEY_FILE%.pub
echo.
echo    Keep your PRIVATE key secret. Never share it.
echo    Copy your PUBLIC key to any server you want access to.
echo.
echo  -----------------------------------------------------
echo    YOUR PUBLIC KEY
echo  -----------------------------------------------------
echo.
type "%KEY_FILE%.pub"
type "%KEY_FILE%.pub" | clip >nul 2>&1
echo.
echo  [i] Public key copied to clipboard.
echo.
echo  -----------------------------------------------------
echo    KEY FINGERPRINT
echo  -----------------------------------------------------
echo    A short unique ID for your key. Use it to verify
echo    server connections or identify keys among several.
echo.
ssh-keygen -lf "%KEY_FILE%.pub"
echo.
exit /b 0


:: Validates name — exits 1 if blank/whitespace or contains invalid chars (spaces allowed)
:VALIDATE_NAME
setlocal enabledelayedexpansion
set "input=%~1"
set "trimmed=!input: =!"
if "!trimmed!"=="" (
    endlocal
    exit /b 1
)
set "safe="
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ " %%A in ("!input!") do (
    set "safe=%%A"
)
if defined safe (
    endlocal
    exit /b 1
)
endlocal
exit /b 0


:: Validates comment — exits 1 if comment contains & | > <
:VALIDATE_COMMENT
setlocal enabledelayedexpansion
set "input=%~1"
echo(!input!| findstr /r "[&|><]" >nul 2>&1
if not errorlevel 1 (
    endlocal
    exit /b 1
)
endlocal
exit /b 0
