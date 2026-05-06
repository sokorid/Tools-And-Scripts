@echo off
title SSH Key Generator
color f
:: ============================================================
:: Author:  sokor
:: GitHub:  https://github.com/sokorid
:: License: MIT (https://opensource.org/licenses/MIT)
:: Notice:  Provided "as is", without warranty of any kind.
:: ============================================================

:: =================================================================================
::  SSH_Key_Generator.bat — Quickly generates Ed25519 or RSA keys for your servers
:: =================================================================================

:: ============================================================
::  HEADER
:: ============================================================
:main_menu
cls
echo.
echo           SSH KEY Generator Script v1.8
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.
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
set /p "choice=  Your choice (1, 2, 3 or 4): "

if "%choice%"=="1" goto gen_ed25519
if "%choice%"=="2" goto gen_rsa
if "%choice%"=="3" goto list_keys
if "%choice%"=="4" goto exit_script

echo.
echo  [X] Invalid choice. Please run the script again and enter 1, 2, 3 or 4.
echo.
pause & goto main_menu

:: ============================================================
:gen_ed25519
:: ============================================================
set "KEY_TYPE=Ed25519"
set "KEY_FILE=%USERPROFILE%\.ssh\id_ed25519"
set "KEYGEN_ARGS=-t ed25519"
goto name_key

:: ============================================================
:gen_rsa
:: ============================================================
set "KEY_TYPE=RSA 4096"
set "KEY_FILE=%USERPROFILE%\.ssh\id_rsa"
set "KEYGEN_ARGS=-t rsa -b 4096"
goto name_key

:: ============================================================
:list_keys
:: ============================================================
cls
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.
echo  -----------------------------------------------------
echo    EXISTING SSH KEYS
echo  -----------------------------------------------------
echo.

set "FOUND_KEYS=0"

for %%F in ("%USERPROFILE%\.ssh\*.pub") do (
    set "FOUND_KEYS=1"
    echo  Key: %%F
    echo.
    echo    Public Key:
    type "%%F"
    echo.
    echo    Fingerprint:
    ssh-keygen -lf "%%F"
    echo.
    echo -----------------------------------------------------
    echo.
)

if "%FOUND_KEYS%"=="0" (
    echo  [!] No SSH keys found on this machine.
    echo.
    echo  =====================================================
    echo.
    pause
    goto main_menu
)

echo  =====================================================
echo.
pause
goto main_menu

:: ============================================================
:name_key
:: ============================================================
cls
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.
echo  -----------------------------------------------------
echo    KEY FILE NAME
echo  -----------------------------------------------------
echo    You can give your key a custom name, or press
echo    ENTER to use the default name.
echo.
echo    Default: %KEY_FILE%
echo.
echo    Custom names are saved in the same .ssh folder.
echo    Example: my_server  -^>  %USERPROFILE%\.ssh\my_server
echo.
echo    Type "back" or "exit" to return to the main menu.
echo.
echo  -----------------------------------------------------
echo    EXISTING KEYS NAMES
echo  -----------------------------------------------------
set "ANY_KEYS=0"
for %%F in ("%USERPROFILE%\.ssh\*.pub") do (
    set "ANY_KEYS=1"
    echo    %%~nF
)
if "%ANY_KEYS%"=="0" echo    None found
echo.
echo  -----------------------------------------------------
echo.
set /p "custom_name=  Custom name (or press ENTER for default): "

if "%custom_name%"=="" goto check_exists
if /i "%custom_name%"=="exit" goto main_menu
if /i "%custom_name%"=="back" goto main_menu

echo.
echo  -----------------------------------------------------
echo    APPEND ENCRYPTION TYPE?
echo  -----------------------------------------------------
echo    Would you like to append the encryption type
echo    to the end of your key name for easy identification?
echo.
echo    Example: %custom_name%_ed25519  or  %custom_name%_rsa4096
echo.
echo    [1]  Yes - append encryption type
echo    [2]  No  - keep name as typed
echo.
echo    Type "back" or "exit" to return to the main menu.
echo.
echo  -----------------------------------------------------
echo.
set /p "append_choice=  Your choice (1 or 2): "

if "%append_choice%"=="1" (
    if "%KEY_TYPE%"=="Ed25519" set "custom_name=%custom_name%_ed25519"
    if "%KEY_TYPE%"=="RSA 4096" set "custom_name=%custom_name%_rsa4096"
)
if /i "%append_choice%"=="exit" goto main_menu
if /i "%append_choice%"=="back" goto main_menu

set "KEY_FILE=%USERPROFILE%\.ssh\%custom_name%"

:: ============================================================
:check_exists
:: ============================================================
cls
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.

if exist "%KEY_FILE%" goto show_existing

:: ============================================================
::  GENERATE NEW KEY
:: ============================================================
echo    [~] No existing key found. Creating a new %KEY_TYPE% key...
echo.
echo  -----------------------------------------------------
echo    ABOUT PASSPHRASES
echo  -----------------------------------------------------
echo    ssh-keygen will now ask you to set a passphrase.
echo.
echo    A passphrase is an optional password that protects
echo    your key file. If someone steals your key file,
echo    they still cannot use it without the passphrase.
echo.
echo    * Press ENTER twice to skip ^(no passphrase^)
echo    * Or type a strong password to protect your key
echo.
echo    Tip: For automated scripts or servers, skipping
echo    the passphrase is common. For personal keys,
echo    setting one is strongly recommended.
echo  -----------------------------------------------------
echo.
pause

if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
ssh-keygen %KEYGEN_ARGS% -f "%KEY_FILE%"

if errorlevel 1 (
    echo.
    echo  [X] Key generation failed. Please try again.
    echo.
    goto end
)

cls
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.
echo  [+] SUCCESS! Your %KEY_TYPE% key has been created.
echo.
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
echo.
echo  -----------------------------------------------------
echo    KEY FINGERPRINT
echo  -----------------------------------------------------
echo    A fingerprint is a short unique ID for your key.
echo    Use it to verify you are connecting to the right
echo    server, or to identify which key is which if you
echo    have several. Servers display their fingerprint
echo    on first connection so you can confirm it matches.
echo.
ssh-keygen -lf "%KEY_FILE%.pub"
echo.
echo  =====================================================
echo    All done! Copy the public key above to your server.
echo  =====================================================
goto end

:: ============================================================
:show_existing
:: ============================================================
echo  [!] A %KEY_TYPE% key already exists. No new key was created.
echo.
echo  -----------------------------------------------------
echo    KEY LOCATION
echo  -----------------------------------------------------
echo    Private key : %KEY_FILE%
echo    Public key  : %KEY_FILE%.pub
echo.
echo  -----------------------------------------------------
echo    YOUR PUBLIC KEY
echo  -----------------------------------------------------
echo.
type "%KEY_FILE%.pub"
echo.
echo  -----------------------------------------------------
echo    KEY FINGERPRINT
echo  -----------------------------------------------------
echo    A fingerprint is a short unique ID for your key.
echo    Use it to verify you are connecting to the right
echo    server, or to identify which key is which if you
echo    have several. Servers display their fingerprint
echo    on first connection so you can confirm it matches.
echo.
ssh-keygen -lf "%KEY_FILE%.pub"
echo.
echo  ===========================================================================================
echo    To generate a key with a different name, run the script again and choose a custom name.
echo  ===========================================================================================

:: ============================================================
:end
:: ============================================================
echo.
pause
goto main_menu

:: ============================================================
:exit_script
:: ============================================================
cls
echo.
echo  =====================================================
echo    SSH Key Generator
echo  =====================================================
echo.
echo    Goodbye!
echo.
echo  =====================================================
echo.
pause
exit /b 0
