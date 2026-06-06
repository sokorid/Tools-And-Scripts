@echo off
:: Capture %~f0 BEFORE setlocal — safe from delayed expansion mangling
set "SELF=%~f0"
setlocal EnableDelayedExpansion
title ScriptDownloader
:: ============================================================
:: Author:  sokor | github.com/sokorid | codeberg.org/sokorid
:: License: MIT (https://opensource.org/licenses/MIT)
:: Notice:  Provided "as is", without warranty of any kind.
:: ============================================================
::  ScriptDownloader.bat — Browse, preview, and download
::  sokorid's Windows 11 scripts from GitHub or Codeberg
:: ============================================================

:: ============================================================
:: CONFIGURATION
:: ============================================================
set "TITLE=ScriptDownloader"
set "VERSION=v2.3"
set "GITHUB_USER=sokorid"
set "GITHUB_REPO=Tools-And-Scripts"
set "GITHUB_BRANCH=main"
set "CODEBERG_USER=sokorid"
set "CODEBERG_REPO=Tools-And-Scripts"
set "CODEBERG_BRANCH=main"
set "RAW_BASE="
set "REGISTRY_URL="
set "REPO_VIEW_URL="
set "SCRIPT_DIR=%TEMP%\Sokor_Script_Downloader"
set "TEMP_DIR=%SCRIPT_DIR%\temp"
set "TEMP_REGISTRY=%TEMP_DIR%\Scripts_List.txt"
set "TEMP_README=%TEMP_DIR%\Fetched_Readme.txt"
set "TEMP_OUT=%TEMP_DIR%\Sokor_PowerShell_Output.txt"
set "TEMP_PS=%TEMP_DIR%\Sokor_PowerShell_Scripts.ps1"

:: ============================================================
:: STARTUP: CLEAN SLATE
:: ============================================================
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" >nul 2>&1
if not exist "%SCRIPT_DIR%" mkdir "%SCRIPT_DIR%"
mkdir "%TEMP_DIR%"

:: ============================================================
:: ELEVATION CHECK
:: ============================================================
net session >nul 2>&1
if not errorlevel 1 goto :select_source
cls
color 0f
call :print_header
echo  -----------------------------------------------------
echo    [i] ADMINISTRATOR RECOMMENDED
echo  -----------------------------------------------------
echo.
echo    This script works without Administrator, but
echo    running as Administrator is highly recommended
echo    for the most reliable experience.
echo.
echo  -----------------------------------------------------
echo    [1]  Relaunch as Administrator  (recommended)
echo    [2]  Continue without elevation
echo  -----------------------------------------------------
echo.
set /p "ELEV_Q=    Choice: "
if "!ELEV_Q!"=="1" (
    setlocal DisableDelayedExpansion
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
    exit /b 0
)

:select_source
cls
color 0f
call :print_header
echo    Choose where to download scripts from:
echo.
echo  -----------------------------------------------------
echo    [1]  GitHub    (github.com/sokorid)
echo    [2]  Codeberg  (codeberg.org/sokorid)
echo    [0]  Exit
echo  -----------------------------------------------------
echo.
set /p "SRC_Q=    Your choice (1, 2 or 0): "

if "!SRC_Q!"=="1" (
    set "RAW_BASE=https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/%GITHUB_BRANCH%"
    set "REGISTRY_URL=!RAW_BASE!/Windows/scripts-list.txt"
    set "REPO_VIEW_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/tree/main/Windows/Windows%%2011"
    set "SOURCE_LABEL=GitHub"
    goto :banner
)
if "!SRC_Q!"=="2" (
    set "RAW_BASE=https://codeberg.org/%CODEBERG_USER%/%CODEBERG_REPO%/raw/branch/%CODEBERG_BRANCH%"
    set "REGISTRY_URL=!RAW_BASE!/Windows/scripts-list.txt"
    set "REPO_VIEW_URL=https://codeberg.org/%CODEBERG_USER%/%CODEBERG_REPO%/src/branch/main/Windows"
    set "SOURCE_LABEL=Codeberg"
    goto :banner
)
if "!SRC_Q!"=="0" goto :goodbye

echo.
echo    [X] Invalid choice. Please enter 1, 2 or 0.
echo.
timeout /t 2 >nul
goto :select_source

:banner
cls
color 0f
call :print_header
echo    Browse and download scripts from the sokorid
echo    !SOURCE_LABEL! repository.
echo.
echo  =====================================================

:: ============================================================
:: SAFETY WARNING
:: ============================================================
echo.
echo  -----------------------------------------------------
echo    [!] READ BEFORE CONTINUING
echo  -----------------------------------------------------
echo.
echo    You are about to download scripts from the internet.
echo    Always review any script before running it.
echo.
echo    View scripts on !SOURCE_LABEL! first:
echo    !REPO_VIEW_URL!
echo.
echo    By continuing you agree that:
echo      - You are downloading scripts from the internet
echo      - You take responsibility for reviewing them
echo      - sokorid is not liable for any damage caused
echo.
echo  -----------------------------------------------------
echo.
set /p "WARN_CONFIRM=    Understood? Continue? (Y/N): "
call :check_yes "!WARN_CONFIRM!" W1
if not "!W1!"=="1" goto :goodbye

echo.
echo  -----------------------------------------------------
set /p "WARN_SURE=    Are you absolutely sure? (Y/N): "
call :check_yes "!WARN_SURE!" W2
if not "!W2!"=="1" goto :goodbye

:: ============================================================
:: MAIN MENU
:: ============================================================
:main_menu
cls
call :print_header
echo    [~] Fetching available scripts...
echo.

if exist "%TEMP_REGISTRY%" del /f /q "%TEMP_REGISTRY%"
curl -s -f -o "%TEMP_REGISTRY%" "%REGISTRY_URL%"
if errorlevel 1 (
    echo    [X] Could not reach !SOURCE_LABEL!. Check your connection.
    pause
    goto :cleanup_exit
)
if not exist "%TEMP_REGISTRY%" (
    echo    [X] Registry file not found after download.
    pause
    goto :cleanup_exit
)

cls
call :print_header
echo  -----------------------------------------------------
echo    AVAILABLE SCRIPTS
echo  -----------------------------------------------------
echo.

set "SCRIPT_COUNT=0"
if exist "%TEMP_OUT%" del /f /q "%TEMP_OUT%"

setlocal DisableDelayedExpansion
if exist "%TEMP_PS%" del /f /q "%TEMP_PS%"
echo $lines = Get-Content "%TEMP_REGISTRY%"          >> "%TEMP_PS%"
echo foreach ($line in $lines) {                      >> "%TEMP_PS%"
echo     $l = $line.Trim()                            >> "%TEMP_PS%"
echo     if ($l -eq "" -or $l.StartsWith("#")) { continue } >> "%TEMP_PS%"
echo     $p = $l.Split("|")                           >> "%TEMP_PS%"
echo     if ($p.Count -lt 4) { continue }             >> "%TEMP_PS%"
echo     $n=$p[0].Trim(); $t=$p[1].Trim(); $pa=$p[2].Trim(); $f=$p[3].Trim() >> "%TEMP_PS%"
echo     if ($n -eq "" -or $t -eq "") { continue }    >> "%TEMP_PS%"
echo     Write-Output ($n+"~"+$t+"~"+$pa+"~"+$f)      >> "%TEMP_PS%"
echo }                                                 >> "%TEMP_PS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%" > "%TEMP_OUT%" 2>nul
if errorlevel 1 echo    [!] Warning: registry parse returned no data.
endlocal

for /f "usebackq tokens=1,2,3,4* delims=~" %%A in ("%TEMP_OUT%") do (
    set /a SCRIPT_COUNT+=1
    set "SC=!SCRIPT_COUNT!"
    set "S_NAME_!SC!=%%A"
    set "S_TYPE_!SC!=%%B"
    set "S_PATH_!SC!=%%C"
    set "S_FILE_!SC!=%%D"
    echo    [!SCRIPT_COUNT!]  %%A
)

if "!SCRIPT_COUNT!"=="0" (
    echo    [X] No scripts found in registry.
    echo  Check that scripts-list.txt is in your Windows folder on !SOURCE_LABEL!.
    pause
    goto :cleanup_exit
)

echo.
echo  -----------------------------------------------------
echo    [0]  Exit
echo  -----------------------------------------------------
echo.
set /p "MENU_CHOICE=    Enter a number: "

if "!MENU_CHOICE!"=="" (
    echo    [!] Please enter a number.
    timeout /t 2 >nul
    goto :main_menu
)
if "!MENU_CHOICE!"=="0" goto :goodbye
call :check_back "!MENU_CHOICE!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :main_menu

set "VALID=0"
for /l %%i in (1,1,!SCRIPT_COUNT!) do (
    if "!MENU_CHOICE!"=="%%i" set "VALID=1"
)
if "!VALID!"=="0" (
    echo    [!] Invalid selection.
    timeout /t 2 >nul
    goto :main_menu
)

set "SEL_NAME=!S_NAME_%MENU_CHOICE%!"
set "SEL_TYPE=!S_TYPE_%MENU_CHOICE%!"
set "SEL_PATH=!S_PATH_%MENU_CHOICE%!"
set "SEL_FILE=!S_FILE_%MENU_CHOICE%!"

:: ============================================================
:: FETCH README
:: ============================================================
if exist "%TEMP_README%" del /f /q "%TEMP_README%"
set "README_URL=!RAW_BASE!/!SEL_PATH!/README.md"
set "README_URL=!README_URL: =%%20!"

curl -s -f -o "%TEMP_README%" "!README_URL!"
if errorlevel 1 (
    echo    [X] Could not fetch README.
    echo  URL: !README_URL!
    pause
    goto :main_menu
)

if /i "!SEL_TYPE!"=="standalone" goto :handle_standalone
if /i "!SEL_TYPE!"=="multi"      goto :handle_multi
echo    [X] Unknown script type: !SEL_TYPE!
pause
goto :main_menu

:: ============================================================
:: STANDALONE HANDLER
:: ============================================================
:handle_standalone
cls
echo.
echo  =====================================================
echo    !SEL_NAME!
echo  =====================================================
echo.

set "P_FILE="
set "P_RE=no"
set "P_RA=no"
set "P_DO=no"
set "SEC_COUNT=0"

if exist "%TEMP_OUT%" del /f /q "%TEMP_OUT%"
setlocal DisableDelayedExpansion
if exist "%TEMP_PS%" del /f /q "%TEMP_PS%"
echo $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8 >> "%TEMP_PS%"
echo $c = Get-Content "%TEMP_README%" -Encoding UTF8 -Raw >> "%TEMP_PS%"
echo $pm = [regex]::Match($c, "<!--\s*PRIMARY:\s*([^|]+)\|([^>]+)-->") >> "%TEMP_PS%"
echo if ($pm.Success) { >> "%TEMP_PS%"
echo     $pf = $pm.Groups[1].Value.Trim() >> "%TEMP_PS%"
echo     $fl = $pm.Groups[2].Value >> "%TEMP_PS%"
echo     $re = if ($fl -match "RE:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     $ra = if ($fl -match "RA:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     $do = if ($fl -match "DO:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     Write-Output ("P~"+$pf+"~"+$re+"~"+$ra+"~"+$do) >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo $sms = [regex]::Matches($c, "<!--\s*SECONDARY_(\d+):\s*([^|]+)\|([^|]+)\|([^|]+)\|\s*RUN:(\w+)\s*-->") >> "%TEMP_PS%"
echo foreach ($sm in $sms) { >> "%TEMP_PS%"
echo     $sf=$sm.Groups[2].Value.Trim(); $sd=$sm.Groups[3].Value.Trim() >> "%TEMP_PS%"
echo     $fl=$sm.Groups[4].Value; $sr=$sm.Groups[5].Value.Trim().ToLower() >> "%TEMP_PS%"
echo     $re = if ($fl -match "RE:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     $ra = if ($fl -match "RA:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     $do = if ($fl -match "DO:(yes|no)") { $matches[1] } else { "no" } >> "%TEMP_PS%"
echo     Write-Output ("S~"+$sf+"~"+$sd+"~"+$re+"~"+$ra+"~"+$do+"~"+$sr) >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%" > "%TEMP_OUT%" 2>nul
if errorlevel 1 echo    [!] Warning: metadata parse returned no data.
endlocal

for /f "usebackq tokens=1-8 delims=~" %%A in ("%TEMP_OUT%") do (
    if "%%A"=="P" (
        set "P_FILE=%%B"
        set "P_RE=%%C"
        set "P_RA=%%D"
        set "P_DO=%%E"
    )
    if "%%A"=="S" (
        set /a SEC_COUNT+=1
        set "SEC_FILE_!SEC_COUNT!=%%B"
        set "SEC_DESC_!SEC_COUNT!=%%C"
        set "SEC_RE_!SEC_COUNT!=%%D"
        set "SEC_RA_!SEC_COUNT!=%%E"
        set "SEC_DO_FLAG_!SEC_COUNT!=%%F"
        set "SEC_RUN_!SEC_COUNT!=%%G"
    )
)

echo  About this script:
echo  -----------------------------------------------------
echo.
call :display_readme_clean
echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu
echo  -----------------------------------------------------
echo.

if "!P_FILE!"=="" (
    echo    [X] No PRIMARY tag found in README.
    echo        Add the correct tags to your README.md first.
    pause
    goto :main_menu
)

if /i "!P_RA!"=="yes" (
    echo  -----------------------------------------------------
    echo    [!] ADMINISTRATOR REQUIRED
    echo  -----------------------------------------------------
    echo.
    echo    This script must be run as Administrator.
    echo.
    set /p "RA_Q=    Continue? (Y/N): "
    call :check_back "!RA_Q!" _NAV
    if "!_NAV!"=="MAIN" goto :main_menu
    if "!_NAV!"=="BACK" goto :main_menu
    call :check_yes "!RA_Q!" RA_OK
    if not "!RA_OK!"=="1" ( timeout /t 2 >nul & goto :main_menu )
)

set /p "DL_Q=    Download !P_FILE!? (Y/N): "
call :check_back "!DL_Q!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :main_menu
call :check_yes "!DL_Q!" DL_OK
if not "!DL_OK!"=="1" ( timeout /t 2 >nul & goto :main_menu )

call :choose_location "!P_DO!" P_LOC
if "!P_LOC!"=="CANCEL" goto :main_menu
if "!P_LOC!"=="BACK"   goto :main_menu
if "!P_LOC!"=="MAIN"   goto :main_menu

set "P_URL=!RAW_BASE!/!SEL_PATH: =%%20!/!P_FILE: =%%20!"
set "P_DEST=!P_LOC!\!P_FILE!"

call :check_collision "!P_DEST!" "!P_FILE!" P_DEST_FINAL
if "!P_DEST_FINAL!"=="CANCEL" goto :main_menu
if "!P_DEST_FINAL!"=="BACK"   goto :main_menu
if "!P_DEST_FINAL!"=="MAIN"   goto :main_menu
set "P_DEST=!P_DEST_FINAL!"

echo.
echo    [~] Downloading !P_FILE!...
curl -s -f -o "!P_DEST!" "!P_URL!"
if errorlevel 1 ( echo    [X] Download failed. Check your connection. & pause & goto :main_menu )
echo    [+] Saved to: !P_DEST!
echo.

if !SEC_COUNT! GTR 0 call :handle_secondaries "!SEL_PATH!"
call :execute_flow "!P_FILE!" "!P_DEST!" "!P_RA!" "!P_RE!" "!P_LOC!"
if !SEC_COUNT! GTR 0 call :run_after_secondaries

echo.
pause
goto :main_menu

:: ============================================================
:: MULTI HANDLER
:: ============================================================
:handle_multi
cls
echo.
echo  =====================================================
echo    !SEL_NAME!
echo  =====================================================
echo.
echo  -----------------------------------------------------
echo    SELECT A SCRIPT
echo  -----------------------------------------------------
echo.

set "MULTI_COUNT=0"
setlocal DisableDelayedExpansion
if exist "%TEMP_PS%" del /f /q "%TEMP_PS%"
echo $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8 >> "%TEMP_PS%"
echo $c = Get-Content "%TEMP_README%" -Encoding UTF8 -Raw >> "%TEMP_PS%"
echo $dRE="no"; $dRA="no"; $dDO="no" >> "%TEMP_PS%"
echo $res = @() >> "%TEMP_PS%"
echo $lines = $c -split "`n" >> "%TEMP_PS%"
echo $in = $false; $cn = "" >> "%TEMP_PS%"
echo for ($i=0; $i -lt $lines.Count; $i++) { >> "%TEMP_PS%"
echo     $l = $lines[$i] >> "%TEMP_PS%"
echo     if ($l -match "<!--\s*tag_default:\s*\(([^)]+)\)\s*-->") { >> "%TEMP_PS%"
echo         $f = $matches[1] >> "%TEMP_PS%"
echo         if ($f -match "RE:(yes|no)") { $dRE = $matches[1] } >> "%TEMP_PS%"
echo         if ($f -match "RA:(yes|no)") { $dRA = $matches[1] } >> "%TEMP_PS%"
echo         if ($f -match "DO:(yes|no)") { $dDO = $matches[1] } >> "%TEMP_PS%"
echo     } >> "%TEMP_PS%"
echo     if ($l -match "<details>") { $in=$true; $cRE=$dRE; $cRA=$dRA; $cDO=$dDO; $cn=""; $cFILE="" } >> "%TEMP_PS%"
echo     if ($in) { >> "%TEMP_PS%"
echo         if ($cn -eq "" -and $l -match "<summary>(.+?)</summary>") { $cn=($matches[1] -replace "[^a-zA-Z0-9\s_\-\.]","").Trim() } >> "%TEMP_PS%"
echo         if ($l -match "<!--\s*FILE:\s*([^-]+\.bat)\s*-->") { $cFILE = $matches[1].Trim() } >> "%TEMP_PS%"
echo         if ($l -match "<!--\s*tag:\s*\(([^)]+)\)\s*-->") { >> "%TEMP_PS%"
echo             $f = $matches[1] >> "%TEMP_PS%"
echo             if ($f -match "RE:(yes|no)") { $cRE = $matches[1] } >> "%TEMP_PS%"
echo             if ($f -match "RA:(yes|no)") { $cRA = $matches[1] } >> "%TEMP_PS%"
echo             if ($f -match "DO:(yes|no)") { $cDO = $matches[1] } >> "%TEMP_PS%"
echo         } >> "%TEMP_PS%"
echo         if ($l -match "</details>" -and $cn -ne "") { >> "%TEMP_PS%"
echo             $fn = if ($cFILE -ne "") { $cFILE } else { $cn } >> "%TEMP_PS%"
echo             $res += ($cn+"~"+$cRE+"~"+$cRA+"~"+$cDO+"~"+$fn); $in=$false >> "%TEMP_PS%"
echo         } >> "%TEMP_PS%"
echo     } >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo foreach ($r in $res) { Write-Output $r } >> "%TEMP_PS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%" > "%TEMP_OUT%" 2>nul
if errorlevel 1 echo    [!] Warning: script list parse returned no data.
endlocal

for /f "usebackq tokens=1-5 delims=~" %%A in ("%TEMP_OUT%") do (
    set /a MULTI_COUNT+=1
    set "MC=!MULTI_COUNT!"
    set "M_NAME_!MC!=%%A"
    set "M_RE_!MC!=%%B"
    set "M_RA_!MC!=%%C"
    set "M_DO_!MC!=%%D"
    set "M_FILE_!MC!=%%E"
    echo    [!MULTI_COUNT!]  %%A
)

if "!MULTI_COUNT!"=="0" (
    echo    [X] No scripts found. Check README uses details blocks and tag_default tags.
    pause
    goto :main_menu
)

echo.
echo  -----------------------------------------------------
echo    [0]  Back to main menu
echo  -----------------------------------------------------
echo.
set /p "MC_CHOICE=    Select a script: "

if "!MC_CHOICE!"=="" ( timeout /t 2 >nul & goto :handle_multi )
if "!MC_CHOICE!"=="0" goto :main_menu
call :check_back "!MC_CHOICE!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :main_menu

set "MV=0"
for /l %%i in (1,1,!MULTI_COUNT!) do if "!MC_CHOICE!"=="%%i" set "MV=1"
if "!MV!"=="0" ( echo  [!] Invalid. & timeout /t 2 >nul & goto :handle_multi )

set "MS_NAME=!M_NAME_%MC_CHOICE%!"
set "MS_RE=!M_RE_%MC_CHOICE%!"
set "MS_RA=!M_RA_%MC_CHOICE%!"
set "MS_DO=!M_DO_%MC_CHOICE%!"
set "MS_FILE_RAW=!M_FILE_%MC_CHOICE%!"
set "MS_NAME_SAFE_OUTER=!MS_NAME!"

cls
echo.
echo  =====================================================
echo    !MS_NAME!
echo  =====================================================
echo.
echo  -----------------------------------------------------
echo    ABOUT THIS SCRIPT
echo  -----------------------------------------------------
echo.

setlocal DisableDelayedExpansion
if exist "%TEMP_PS%" del /f /q "%TEMP_PS%"
echo $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8 >> "%TEMP_PS%"
echo $c = Get-Content "%TEMP_README%" -Encoding UTF8 -Raw >> "%TEMP_PS%"
echo $e = [regex]::Escape("%MS_NAME_SAFE_OUTER%") >> "%TEMP_PS%"
echo $m = [regex]::Match($c, "(?s)<details>\s*<summary>[^<]*"+$e+"[^<]*</summary>(.*?)</details>") >> "%TEMP_PS%"
echo $skip = @("!\[","shields\.io","<!--","-->","^<br","^<details","^</details","^<summary","</summary") >> "%TEMP_PS%"
echo if ($m.Success) { >> "%TEMP_PS%"
echo     $block = $m.Groups[1].Value >> "%TEMP_PS%"
echo     $dm = [regex]::Match($block, "(?s)<!-- DISPLAY_START -->(.*?)<!-- DISPLAY_END -->") >> "%TEMP_PS%"
echo     $b = if ($dm.Success) { $dm.Groups[1].Value -split "`n" } else { $block -split "`n" } >> "%TEMP_PS%"
echo     $found = $false >> "%TEMP_PS%"
echo     foreach ($line in $b) { >> "%TEMP_PS%"
echo         $l = $line.Trim() >> "%TEMP_PS%"
echo         if ($l -eq "") { continue } >> "%TEMP_PS%"
echo         $bad = $false >> "%TEMP_PS%"
echo         foreach ($p in $skip) { if ($l -match $p) { $bad=$true; break } } >> "%TEMP_PS%"
echo         if ($bad) { continue } >> "%TEMP_PS%"
echo         $l = $l -replace "^#+\s*","" -replace "\*\*","" -replace "``","" -replace "\[([^\]]+)\]\([^\)]+\)","`$1" >> "%TEMP_PS%"
echo         if ($l.Trim() -ne "") { Write-Host ("  "+$l); $found=$true } >> "%TEMP_PS%"
echo     } >> "%TEMP_PS%"
echo     if (-not $found) { Write-Host "  No preview available." } >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%"
if errorlevel 1 echo    [!] Warning: preview parse returned no data.
endlocal

echo.
echo  -----------------------------------------------------
echo    [B] Back   [M] Main Menu
echo  -----------------------------------------------------
echo.

if /i "!MS_RA!"=="yes" (
    echo  -----------------------------------------------------
    echo    [!] ADMINISTRATOR REQUIRED
    echo  -----------------------------------------------------
    echo.
    echo    This script must be run as Administrator.
    echo.
    set /p "MRA_Q=    Continue? (Y/N): "
    call :check_back "!MRA_Q!" _NAV
    if "!_NAV!"=="MAIN" goto :main_menu
    if "!_NAV!"=="BACK" goto :handle_multi
    call :check_yes "!MRA_Q!" MRA_OK
    if not "!MRA_OK!"=="1" ( timeout /t 2 >nul & goto :handle_multi )
)

set /p "MDL_Q=    Download !MS_NAME!? (Y/N): "
call :check_back "!MDL_Q!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :handle_multi
call :check_yes "!MDL_Q!" MDL_OK
if not "!MDL_OK!"=="1" ( timeout /t 2 >nul & goto :handle_multi )

call :choose_location "!MS_DO!" MS_LOC
if "!MS_LOC!"=="CANCEL" goto :handle_multi
if "!MS_LOC!"=="BACK"   goto :handle_multi
if "!MS_LOC!"=="MAIN"   goto :main_menu

set "MS_FILE=!MS_FILE_RAW!"
echo !MS_FILE! | findstr /i "\.bat" >nul 2>&1
if errorlevel 1 set "MS_FILE=!MS_FILE!.bat"

set "MS_URL=!RAW_BASE!/!SEL_PATH: =%%20!/!MS_FILE: =%%20!"
set "MS_DEST=!MS_LOC!\!MS_FILE!"

call :check_collision "!MS_DEST!" "!MS_FILE!" MS_DEST_FINAL
if "!MS_DEST_FINAL!"=="CANCEL" goto :handle_multi
if "!MS_DEST_FINAL!"=="BACK"   goto :handle_multi
if "!MS_DEST_FINAL!"=="MAIN"   goto :main_menu
set "MS_DEST=!MS_DEST_FINAL!"

echo.
echo    [~] Downloading !MS_FILE!...
curl -s -f -o "!MS_DEST!" "!MS_URL!"
if errorlevel 1 ( echo    [X] Download failed. Check your connection. & pause & goto :handle_multi )
echo    [+] Saved to: !MS_DEST!
echo.

call :execute_flow "!MS_FILE!" "!MS_DEST!" "!MS_RA!" "!MS_RE!" "!MS_LOC!"
echo.
pause
goto :handle_multi

:: ============================================================
:: SUBROUTINE: CHECK YES (y/Y/yes/YES)
:: ============================================================
:check_yes
set "%~2=0"
if /i "%~1"=="y"   set "%~2=1"
if /i "%~1"=="yes" set "%~2=1"
goto :eof

:: ============================================================
:: SUBROUTINE: CHECK BACK / MAIN MENU NAV
:: ============================================================
:check_back
set "%~2=NONE"
if /i "%~1"=="b"         set "%~2=BACK"
if /i "%~1"=="back"      set "%~2=BACK"
if /i "%~1"=="m"         set "%~2=MAIN"
if /i "%~1"=="main"      set "%~2=MAIN"
if /i "%~1"=="main menu" set "%~2=MAIN"
goto :eof

:: ============================================================
:: SUBROUTINE: CHECK COLLISION
:: ============================================================
:check_collision
set "_CC_DEST=%~1"
set "_CC_FILE=%~2"
set "%~3=!_CC_DEST!"

if not exist "!_CC_DEST!" goto :eof

:collision_prompt
echo.
echo  -----------------------------------------------------
echo    [!] FILE ALREADY EXISTS
echo  -----------------------------------------------------
echo.
echo    A file named !_CC_FILE! already exists at this location.
echo.
echo    [1]  Overwrite  (replaces the existing file)
echo    [2]  Rename     (saves with a number suffix)
echo    [0]  Cancel
echo.
echo  -----------------------------------------------------
echo.
set "COL_Q="
set /p "COL_Q=    Choice: "

if "!COL_Q!"=="" (
    echo    [!] Please make a selection.
    timeout /t 2 >nul
    goto :collision_prompt
)

call :check_back "!COL_Q!" _NAV
if "!_NAV!"=="MAIN" ( set "%~3=MAIN" & goto :eof )
if "!_NAV!"=="BACK" ( set "%~3=BACK" & goto :eof )
if "!COL_Q!"=="0" ( set "%~3=CANCEL" & goto :eof )

if "!COL_Q!"=="1" (
    echo    [i] Overwriting existing file.
    set "%~3=!_CC_DEST!"
    goto :eof
)

if "!COL_Q!"=="2" (
    set "_BASE=!_CC_FILE!"
    set "_BASE=!_BASE:.bat=!"
    for %%F in ("!_CC_DEST!") do set "_DIR=%%~dpF"
    set "_IDX=1"
    :collision_loop
    if !_IDX! GTR 999 ( set "%~3=CANCEL" & echo    [!] Too many copies exist. Cancelling. & goto :eof )
    set "_NEWDEST=!_DIR!!_BASE! !_IDX!.bat"
    if exist "!_NEWDEST!" ( set /a _IDX+=1 & goto :collision_loop )
    echo    [i] Saving as: !_BASE! !_IDX!.bat
    set "%~3=!_NEWDEST!"
    goto :eof
)

echo    [!] Invalid choice.
timeout /t 2 >nul
goto :collision_prompt

:: ============================================================
:: SUBROUTINE: CHOOSE SAVE LOCATION
:: ============================================================
:choose_location
set "%~2=CANCEL"
if /i "%~1"=="yes" (
    echo    [i] Desktop only - saving to your Desktop.
    set "%~2=%USERPROFILE%\Desktop"
    goto :eof
)
echo  -----------------------------------------------------
echo    SAVE LOCATION
echo  -----------------------------------------------------
echo.
echo    [1]  Desktop
echo    [2]  Temp  ^(saved to Sokor_Script_Downloader, deleted on exit^)
echo    [0]  Cancel
echo.
echo  -----------------------------------------------------
echo.
set /p "LOC=    Enter choice: "

call :check_back "!LOC!" _NAV
if "!_NAV!"=="MAIN" ( set "%~2=MAIN" & goto :eof )
if "!_NAV!"=="BACK" ( set "%~2=BACK" & goto :eof )
if "!LOC!"=="1" ( set "%~2=%USERPROFILE%\Desktop" & goto :eof )
if "!LOC!"=="2" ( set "%~2=%SCRIPT_DIR%"          & goto :eof )
if "!LOC!"=="0" goto :eof
echo    [!] Invalid choice. Defaulting to Desktop.
set "%~2=%USERPROFILE%\Desktop"
goto :eof

:: ============================================================
:: SUBROUTINE: EXECUTE FLOW
:: ============================================================
:execute_flow
set "_F=%~1"
set "_P=%~2"
set "_RA=%~3"
set "_RE=%~4"
set "_L=%~5"

if /i "!_RE!"=="yes" (
    echo  -----------------------------------------------------
    echo    [!] CONFIGURATION REQUIRED
    echo  -----------------------------------------------------
    echo.
    echo    This script must be edited before use.
    echo    Open the file, make your changes, then run manually.
    echo.
    echo    Saved to: !_P!
    echo.
    goto :eof
)

set /p "EX_Q=    Execute !_F! now? (Y/N): "
call :check_back "!EX_Q!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :eof
call :check_yes "!EX_Q!" EX_OK
if not "!EX_OK!"=="1" ( echo    [i] Saved to: !_P! & goto :eof )

if /i "!_RA!"=="yes" (
    set /p "ADM_Q=    Launch as Administrator? (Y/N): "
    call :check_back "!ADM_Q!" _NAV
    if "!_NAV!"=="MAIN" goto :main_menu
    if "!_NAV!"=="BACK" goto :eof
    call :check_yes "!ADM_Q!" ADM_OK
    if "!ADM_OK!"=="1" (
        echo    [~] Requesting UAC elevation...
        powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%_P%\"') -Verb RunAs -Wait"
    ) else (
        echo    [i] Right-click the file and select Run as Administrator
        echo        Location: !_P!
    )
) else (
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%_P%\" & pause') -Wait"
)

if /i "!_L!"=="%SCRIPT_DIR%" if exist "!_P!" (
    del /f /q "!_P!" >nul 2>&1
    echo    [+] Temp file cleaned up.
)
goto :eof

:: ============================================================
:: SUBROUTINE: HANDLE SECONDARIES
:: ============================================================
:handle_secondaries
set "_SHP=%~1"
if !SEC_COUNT! EQU 0 goto :eof

echo.
echo  =====================================================
echo    Optional Companion Files
echo  =====================================================
echo.
for /l %%i in (1,1,!SEC_COUNT!) do (
    echo    [%%i] !SEC_FILE_%%i!
    echo         !SEC_DESC_%%i!
    echo.
)
echo  -----------------------------------------------------
echo    [A]  Download all
echo    [N]  Skip all
echo    [B]  Back   [M]  Main Menu
echo  -----------------------------------------------------
echo.
set /p "SC_Q=    Choice: "

call :check_back "!SC_Q!" _NAV
if "!_NAV!"=="MAIN" goto :main_menu
if "!_NAV!"=="BACK" goto :eof
if /i "!SC_Q!"=="n"  goto :eof
if /i "!SC_Q!"=="no" goto :eof

for /l %%i in (1,1,!SEC_COUNT!) do set "SDLO_%%i=0"

if /i "!SC_Q!"=="a" (
    for /l %%i in (1,1,!SEC_COUNT!) do set "SDLO_%%i=1"
) else (
    set "SV=0"
    for /l %%i in (1,1,!SEC_COUNT!) do if "!SC_Q!"=="%%i" ( set "SDLO_%%i=1" & set "SV=1" )
    if "!SV!"=="0" ( echo    [!] Invalid. Skipping. & goto :eof )
)

for /l %%i in (1,1,!SEC_COUNT!) do (
    if "!SDLO_%%i!"=="1" (
        echo.
        echo  -- !SEC_FILE_%%i! --
        call :choose_location "!SEC_DO_FLAG_%%i!" SLOC_%%i
        if "!SLOC_%%i!"=="CANCEL" (
            set "SDLO_%%i=0"
        ) else if "!SLOC_%%i!"=="BACK" (
            set "SDLO_%%i=0"
        ) else if "!SLOC_%%i!"=="MAIN" (
            set "SDLO_%%i=0"
            goto :main_menu
        ) else (
            set "SU=!RAW_BASE!/!_SHP: =%%20!/!SEC_FILE_%%i: =%%20!"
            set "SDEST_%%i=!SLOC_%%i!\!SEC_FILE_%%i!"
            call :check_collision "!SDEST_%%i!" "!SEC_FILE_%%i!" SDEST_%%i
            if "!SDEST_%%i!"=="CANCEL" (
                set "SDLO_%%i=0"
            ) else if "!SDEST_%%i!"=="BACK" (
                set "SDLO_%%i=0"
            ) else if "!SDEST_%%i!"=="MAIN" (
                set "SDLO_%%i=0"
                goto :main_menu
            ) else (
                curl -s -f -o "!SDEST_%%i!" "!SU!"
                if errorlevel 1 (
                    echo    [X] Failed: !SEC_FILE_%%i!
                    set "SDLO_%%i=0"
                ) else (
                    echo    [+] !SDEST_%%i!
                    if /i "!SEC_RUN_%%i!"=="manual" (
                        echo    [i] Run manually: !SDEST_%%i!
                        set "SDLO_%%i=0"
                    )
                    if /i "!SEC_RUN_%%i!"=="with" (
                        set /p "WR_Q=    Launch !SEC_FILE_%%i! alongside primary? (Y/N): "
                        call :check_yes "!WR_Q!" WR_OK
                        if "!WR_OK!"=="1" (
                            if /i "!SEC_RA_%%i!"=="yes" (
                                start powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%SDEST_%%i%\"') -Verb RunAs"
                            ) else (
                                start powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%SDEST_%%i%\" & pause')"
                            )
                        )
                        set "SDLO_%%i=0"
                    )
                )
            )
        )
    )
)
goto :eof

:: ============================================================
:: SUBROUTINE: RUN AFTER SECONDARIES
:: ============================================================
:run_after_secondaries
for /l %%i in (1,1,!SEC_COUNT!) do (
    if "!SDLO_%%i!"=="1" if /i "!SEC_RUN_%%i!"=="after" (
        echo.
        echo  -----------------------------------------------------
        echo    [i] !SEC_FILE_%%i! - !SEC_DESC_%%i!
        echo.
        set /p "AR_Q=    Run !SEC_FILE_%%i! now? (Y/N): "
        call :check_back "!AR_Q!" _NAV
        if "!_NAV!"=="MAIN" goto :main_menu
        if not "!_NAV!"=="BACK" (
            call :check_yes "!AR_Q!" AR_OK
            if "!AR_OK!"=="1" (
                if /i "!SEC_RA_%%i!"=="yes" (
                    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%SDEST_%%i%\"') -Verb RunAs -Wait"
                ) else (
                    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList @('/c', '\"%SDEST_%%i%\" & pause') -Wait"
                )
                if /i "!SLOC_%%i!"=="%SCRIPT_DIR%" if exist "!SDEST_%%i!" del /f /q "!SDEST_%%i!" >nul 2>&1
            )
        )
    )
)
goto :eof

:: ============================================================
:: SUBROUTINE: DISPLAY CLEAN README
:: ============================================================
:display_readme_clean
setlocal DisableDelayedExpansion
if exist "%TEMP_PS%" del /f /q "%TEMP_PS%"
echo $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8 >> "%TEMP_PS%"
echo $content = Get-Content "%TEMP_README%" -Encoding UTF8 -Raw >> "%TEMP_PS%"
echo $skip = @("!\[","shields\.io","<!--","-->","^<br","^<details","^</details","^<summary","</summary") >> "%TEMP_PS%"
echo $dm = [regex]::Match($content, "(?s)<!-- DISPLAY_START -->(.*?)<!-- DISPLAY_END -->") >> "%TEMP_PS%"
echo if ($dm.Success) { >> "%TEMP_PS%"
echo     $lines = $dm.Groups[1].Value -split "`n" >> "%TEMP_PS%"
echo } else { >> "%TEMP_PS%"
echo     $lines = ($content -split "`n") ^| Select-Object -First 50 >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo $n = 0; $found = $false >> "%TEMP_PS%"
echo foreach ($line in $lines) { >> "%TEMP_PS%"
echo     if ($n -ge 25) { break } >> "%TEMP_PS%"
echo     $l = $line.Trim() >> "%TEMP_PS%"
echo     if ($l -eq "") { continue } >> "%TEMP_PS%"
echo     $bad = $false >> "%TEMP_PS%"
echo     foreach ($p in $skip) { if ($l -match $p) { $bad=$true; break } } >> "%TEMP_PS%"
echo     if ($bad) { continue } >> "%TEMP_PS%"
echo     $l = $l -replace "^#+\s*","" -replace "\*\*","" -replace "``","" -replace "\[([^\]]+)\]\([^\)]+\)","`$1" >> "%TEMP_PS%"
echo     if ($l.Trim() -ne "") { Write-Host ("  "+$l); $n++; $found=$true } >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo if (-not $found) { Write-Host "  No preview available." } >> "%TEMP_PS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%"
if errorlevel 1 echo    [!] Warning: README display returned no data.
endlocal
goto :eof

:: ============================================================
:: SUBROUTINE: PRINT HEADER
:: ============================================================
:print_header
echo.
echo  =====================================================
echo    %TITLE% %VERSION%
echo  =====================================================
echo.
goto :eof

:: ============================================================
:: GOODBYE / CLEANUP
:: ============================================================
:goodbye
cls
call :print_header
echo    Goodbye!
echo.
echo  =====================================================
echo.
pause

:cleanup_exit
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" >nul 2>&1

if not exist "%SCRIPT_DIR%" goto :do_exit
set "KEPT_SCRIPTS=0"
for %%F in ("%SCRIPT_DIR%\*.bat") do set /a KEPT_SCRIPTS+=1

if "!KEPT_SCRIPTS!"=="0" (
    rd /s /q "%SCRIPT_DIR%" >nul 2>&1
    goto :do_exit
)

echo.
echo  -----------------------------------------------------
echo    [i] Scripts left in Sokor_Script_Downloader:
echo  -----------------------------------------------------
echo.
for %%F in ("%SCRIPT_DIR%\*.bat") do echo      %%~nxF
echo.
echo  -----------------------------------------------------
set /p "DEL_Q=    Delete all downloaded scripts? (Y/N): "
call :check_yes "!DEL_Q!" DEL_OK
if "!DEL_OK!"=="1" (
    rd /s /q "%SCRIPT_DIR%" >nul 2>&1
    echo    [+] Cleaned up.
) else (
    echo    [i] Scripts kept at: %SCRIPT_DIR%
)
echo.

:do_exit
endlocal
exit /b 0