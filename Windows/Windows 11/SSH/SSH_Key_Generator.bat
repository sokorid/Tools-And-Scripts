@echo off
title SSH Key Generator
:: ============================================================
:: Author:  sokor
:: GitHub:  https://github.com/sokorid
:: License: MIT (https://opensource.org/licenses/MIT)
:: Notice:  Provided "as is", without warranty of any kind.
:: ============================================================

:: =================================================================================
::  SSH_Key_Generator.bat — Quickly generates Ed25519 or RSA keys for your servers
::  SCRIPT_VERSION_1.0
:: =================================================================================

:: ============================================================
::  HEADER
:: ============================================================
cls
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
echo  -----------------------------------------------------
echo.
set /p "choice=  Your choice (1 or 2): "

if "%choice%"=="1" goto gen_ed25519
if "%choice%"=="2" goto gen_rsa

echo.
echo  [X] Invalid choice. Please run the script again and enter 1 or 2.
echo.
pause & exit /b 1

:: ============================================================
:gen_ed25519
:: ============================================================
set "KEY_TYPE=Ed25519"
set "KEY_FILE=%USERPROFILE%\.ssh\id_ed25519"
set "KEYGEN_ARGS=-t ed25519"
goto check_exists

:: ============================================================
:gen_rsa
:: ============================================================
set "KEY_TYPE=RSA 4096"
set "KEY_FILE=%USERPROFILE%\.ssh\id_rsa"
set "KEYGEN_ARGS=-t rsa -b 4096"
goto check_exists

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
echo  =====================================================
echo    To use a different key name, run ssh-keygen manually.
echo  =====================================================

:: ============================================================
:end
:: ============================================================
echo.
pause
