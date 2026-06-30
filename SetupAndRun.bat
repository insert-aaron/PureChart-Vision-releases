@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: PureChart Vision - SetupAndRun.bat
:: Auto-installer + updater + launcher for the unified app.
::
:: Ships as a self-contained .NET 8 app (PureChartVision.exe — no
:: .NET runtime install needed), plus:
::   python\        embedded Python interpreter + decoder deps (panoramic)
::   decoder\       Python reconstruction pipeline (panoramic)
::   PluginHost.exe x86 TWAIN host (intraoral RVG capture)
::
:: Three-way state detection:
::   .git missing, marker missing  -> fresh clone + post-install + launch
::   .git exists,  marker missing  -> user cloned manually, post-install + launch
::   .git exists,  marker exists   -> returning launch, check for updates + launch
::
:: Deployed to PureChart-Vision-releases by CI on every push to main.
:: x64 only: the embedded Python (opencv) ships amd64 wheels only. The
:: TWAIN PluginHost is x86 but runs as a separate subprocess.
:: ============================================================

set "INSTALL_DIR=%~dp0"
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"
set "REPO_URL=https://github.com/insert-aaron/PureChart-Vision-releases.git"
set "BRANCH=main"
set "APP_NAME=PureChartVision"
set "EXE_NAME=PureChartVision.exe"
set "SERVICE_NAME=PluginHost.exe"
set "SHORTCUT_NAME=PureChart Vision"
set "DATA_DIR=%APPDATA%\PureChartVision"
set "MARKER=%INSTALL_DIR%\.purechartvision_installed"

set "EXE_PATH=%INSTALL_DIR%\%EXE_NAME%"
set "SERVICE_PATH=%INSTALL_DIR%\%SERVICE_NAME%"
set "DECODER_DIR=%INSTALL_DIR%\decoder"
set "BUNDLED_PY=%INSTALL_DIR%\python\python.exe"

title %APP_NAME% Setup and Launcher

set "LOGFILE=%INSTALL_DIR%\purechartvision_launcher.log"
echo. >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo [%date% %time%] Launcher started >> "%LOGFILE%"
echo   Install dir:  %INSTALL_DIR% >> "%LOGFILE%"
echo   Bundled py:   %BUNDLED_PY% >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"

echo.
echo ========================================
echo   %APP_NAME% - Setup and Launcher
echo ========================================
echo Launcher log: %LOGFILE%
echo.

:: ============================================================
:: Step 1: Check/Install Git
:: ============================================================
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [%APP_NAME%] Git not found. Installing via winget...
    where winget >nul 2>&1
    if %errorlevel% neq 0 (
        echo [%APP_NAME%] ERROR: Neither Git nor winget found.
        echo [%APP_NAME%] Install Git manually from https://git-scm.com/download/win
        goto :launch_existing
    )
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1
    set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files (x86)\Git\cmd"
    where git >nul 2>&1
    if %errorlevel% neq 0 (
        echo [%APP_NAME%] Git installed but not yet on PATH. Please restart this script.
        goto :launch_existing
    )
    echo [%APP_NAME%] Git installed.
) else (
    echo [%APP_NAME%] Git found.
)

:: ============================================================
:: Step 2: Locate Python for the panoramic decoder
::   1. Bundled Python (shipped in the release — primary path)
::   2. System Python on PATH (fallback)
:: No runtime download (fails on locked-down clinic PCs).
:: ============================================================
echo [%APP_NAME%] Locating Python for image decoder...
set "PYTHON_CMD="
if exist "%BUNDLED_PY%" (
    set "PYTHON_CMD=%BUNDLED_PY%"
    echo [%APP_NAME%] Using bundled Python: !PYTHON_CMD!
    goto :verify_python
)
where python >nul 2>&1
if %errorlevel% equ 0 ( set "PYTHON_CMD=python" & goto :verify_python )
where python3 >nul 2>&1
if %errorlevel% equ 0 ( set "PYTHON_CMD=python3" & goto :verify_python )
echo [%APP_NAME%] WARNING: No Python found. Panoramic decoder unavailable until restored.
echo [%date% %time%] Python NOT FOUND >> "%LOGFILE%"
goto :state_detect

:verify_python
"%PYTHON_CMD%" -c "import numpy, cv2, PIL, scipy, pydicom" >nul 2>&1
if %errorlevel% neq 0 (
    echo [%APP_NAME%] Decoder deps missing — attempting pip repair...
    if exist "%DECODER_DIR%\requirements.txt" (
        "%PYTHON_CMD%" -m pip install -r "%DECODER_DIR%\requirements.txt" --no-warn-script-location >> "%LOGFILE%" 2>&1
        "%PYTHON_CMD%" -c "import numpy, cv2, PIL, scipy, pydicom" >nul 2>&1
        if !errorlevel! neq 0 ( echo [%APP_NAME%] WARNING: decoder repair failed. & set "PYTHON_CMD=" )
    ) else ( set "PYTHON_CMD=" )
)
if defined PYTHON_CMD echo [%APP_NAME%] Python verified.

:: ============================================================
:: Step 3: Three-way state detection
:: ============================================================
:state_detect
if not exist "%INSTALL_DIR%\.git" if not exist "%MARKER%" goto :fresh_clone
if exist "%INSTALL_DIR%\.git" if not exist "%MARKER%" goto :post_install
if exist "%INSTALL_DIR%\.git" if exist "%MARKER%" goto :check_update
goto :launch

:fresh_clone
echo [%APP_NAME%] Fresh install — cloning release repository...
git clone --branch %BRANCH% --single-branch --depth=1 "%REPO_URL%" "%INSTALL_DIR%_tmp" >> "%LOGFILE%" 2>&1
if %errorlevel% neq 0 ( echo [%APP_NAME%] ERROR: git clone failed. See %LOGFILE%. & goto :end_pause_error )
if exist "%INSTALL_DIR%" (
    xcopy /E /Y /Q "%INSTALL_DIR%_tmp\*" "%INSTALL_DIR%\" >nul
    xcopy /E /Y /H /Q "%INSTALL_DIR%_tmp\.git" "%INSTALL_DIR%\.git\" >nul
    rmdir /S /Q "%INSTALL_DIR%_tmp"
) else (
    move "%INSTALL_DIR%_tmp" "%INSTALL_DIR%"
)
echo [%APP_NAME%] Clone complete.
goto :post_install

:post_install
echo [%APP_NAME%] Running post-install...
if defined PYTHON_CMD if exist "%DECODER_DIR%\requirements.txt" (
    "%PYTHON_CMD%" -m pip install -r "%DECODER_DIR%\requirements.txt" --no-warn-script-location >> "%LOGFILE%" 2>&1
)
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
if not exist "%DATA_DIR%\patients" mkdir "%DATA_DIR%\patients"
echo installed> "%MARKER%"
echo [%APP_NAME%] Post-install complete.
goto :launch

:check_update
pushd "%INSTALL_DIR%"
git fetch origin +%BRANCH%:refs/remotes/origin/%BRANCH% >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( echo [%APP_NAME%] WARNING: could not check for updates (no network?). & popd & goto :launch )
for /f "delims=" %%A in ('git rev-parse HEAD') do set "LOCAL_HASH=%%A"
for /f "delims=" %%A in ('git rev-parse origin/%BRANCH%') do set "REMOTE_HASH=%%A"
if "!LOCAL_HASH!"=="!REMOTE_HASH!" ( echo [%APP_NAME%] Already up to date. & popd & goto :launch )
echo [%APP_NAME%] Update available — installing...
taskkill /f /im "%EXE_NAME%" >nul 2>&1
taskkill /f /im "%SERVICE_NAME%" >nul 2>&1
git reset --hard origin/%BRANCH% >> "%LOGFILE%" 2>&1
if defined PYTHON_CMD if exist "%DECODER_DIR%\requirements.txt" (
    "%PYTHON_CMD%" -m pip install -r "%DECODER_DIR%\requirements.txt" --no-warn-script-location >> "%LOGFILE%" 2>&1
)
echo [%APP_NAME%] Updated.
popd
goto :launch

:: ============================================================
:: Launch
:: ============================================================
:launch
if not exist "%EXE_PATH%" (
    echo [%APP_NAME%] ERROR: %EXE_NAME% not found at %EXE_PATH%
    echo [%APP_NAME%] Installation may be corrupt. Delete the install dir and re-run.
    goto :end_pause_error
)

:: Self-healing Desktop shortcut (OneDrive-redirected desktops supported)
set "DESKTOP_DIR="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP_DIR=%%D"
if not defined DESKTOP_DIR set "DESKTOP_DIR=%USERPROFILE%\Desktop"
set "SHORTCUT_PATH=!DESKTOP_DIR!\%SHORTCUT_NAME%.lnk"
if not exist "!SHORTCUT_PATH!" (
    set "ICO=%INSTALL_DIR%\Assets\app.ico"
    if not exist "!ICO!" set "ICO=%EXE_PATH%"
    powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut('!SHORTCUT_PATH!'); $sc.TargetPath = '%INSTALL_DIR%\SetupAndRun.bat'; $sc.WorkingDirectory = '%INSTALL_DIR%'; $sc.IconLocation = '!ICO!'; $sc.Description = 'PureChart Vision - Dental Imaging'; $sc.Save()" >nul 2>&1
)

:: Optional: report TWAIN sources for the intraoral module (non-fatal).
if exist "%SERVICE_PATH%" (
    for /f "usebackq delims=" %%L in (`"%SERVICE_PATH%" --list-sources 2^>nul`) do echo [%APP_NAME%] TWAIN source: %%L
)

:: Tell the app where Python is (decoder subprocess); env var is named
:: PUREXS_PYTHON for compatibility with the panoramic imaging service.
if defined PYTHON_CMD set "PUREXS_PYTHON=%PYTHON_CMD%"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
echo [%APP_NAME%] Launching %APP_NAME%...
start "" "%EXE_PATH%"
goto :end_pause_success

:launch_existing
if exist "%EXE_PATH%" ( start "" "%EXE_PATH%" & goto :end_pause_warn )
echo [%APP_NAME%] No existing installation found. Cannot continue.
goto :end_pause_error

:end_pause_success
echo.
echo   %APP_NAME% launched. Log: %LOGFILE%
timeout /t 6 >nul
exit /b 0

:end_pause_warn
echo.
echo   %APP_NAME% launched in fallback mode. Review: %LOGFILE%
timeout /t 12 >nul
exit /b 0

:end_pause_error
echo.
echo   %APP_NAME% setup failed. Full log: %LOGFILE%
pause >nul
exit /b 1
