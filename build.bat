@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM Build & Sign — Hard Reset
REM Version: 1.0
REM Date: 2026-07-13
REM 
REM What it does:
REM   1. Reads current version from export_presets.cfg
REM   2. Exports Windows EXE via Godot CLI
REM   3. Exports Android APK via Godot CLI
REM   4. Signs APK via apksigner
REM   5. Verifies signature
REM   6. Outputs full report
REM ============================================================

call :main %*
exit /b %ERRORLEVEL%

:main
    call :init
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :read_version
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :ask_version
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :create_build_dir
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :export_windows
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :export_android
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :sign_apk
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :verify_signature
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :report
    if %ERRORLEVEL% neq 0 exit /b 1
    
    goto :eof

REM ============================================================
REM Init — set constants and check dependencies
REM ============================================================
:init
    set "SCRIPT_DIR=%~dp0"
    set "PROJECT_DIR=%SCRIPT_DIR%"
    set "BUILD_BASE=%SCRIPT_DIR%build"
    set "PRESETS_FILE=%SCRIPT_DIR%export_presets.cfg"
    set "GODOT_EXE=C:\Programs\Godot_v4.7-stable_win64.exe"
    set "APKSIGNER=C:\Users\igort\AppData\Local\Android\Sdk\build-tools\37.0.0\apksigner.bat"
    set "EXPORT_NAME=hardreset"
    set "CURRENT_VERSION="
    set "NEW_VERSION="
    set "BUILD_DIR="
    set "EXE_PATH="
    set "APK_PATH="
    set "SIGNED_APK_PATH="
    
    REM Check Godot
    if not exist "%GODOT_EXE%" (
        echo ERROR: Godot not found at %GODOT_EXE%
        echo Please update GODOT_EXE path in this script
        exit /b 1
    )
    
    REM Check apksigner
    if not exist "%APKSIGNER%" (
        echo ERROR: apksigner not found at %APKSIGNER%
        echo Please update APKSIGNER path in this script
        exit /b 1
    )
    
    REM Check export_presets.cfg
    if not exist "%PRESETS_FILE%" (
        echo ERROR: export_presets.cfg not found at %PRESETS_FILE%
        exit /b 1
    )
    
    echo [INIT] Dependencies OK
    goto :eof

REM ============================================================
REM Read current version from export_presets.cfg (Android version/name)
REM ============================================================
:read_version
    set "CURRENT_VERSION="
    
    REM Find version/name line in Android preset
    for /f "tokens=2 delims==" %%a in ('findstr /b "version/name=" "%PRESETS_FILE%"') do (
        set "RAW=%%a"
        REM Remove quotes
        set "CURRENT_VERSION=!RAW:"=!"
    )
    
    if "!CURRENT_VERSION!"=="" (
        echo ERROR: Could not read version/name from export_presets.cfg
        exit /b 1
    )
    
    echo [VERSION] Current: !CURRENT_VERSION!
    goto :eof

REM ============================================================
REM Ask user for new version
REM ============================================================
:ask_version
    echo.
    echo Current version: !CURRENT_VERSION!
    echo.
    set /p "NEW_VERSION=Enter new version (or press Enter to keep !CURRENT_VERSION!): "
    
    if "!NEW_VERSION!"=="" (
        set "NEW_VERSION=!CURRENT_VERSION!"
        echo [VERSION] Keeping: !NEW_VERSION!
    ) else (
        echo [VERSION] New: !NEW_VERSION!
    )
    
    REM Update version/name in export_presets.cfg (Android preset)
    echo [VERSION] Updating export_presets.cfg...
    
    REM Create temp file
    set "TEMP_FILE=%TEMP%\export_presets_temp.cfg"
    
    REM Replace version/name line
    (
        for /f "delims=" %%a in ('type "%PRESETS_FILE%"') do (
            set "line=%%a"
            if "!line:~0,13!"=="version/name=" (
                echo version/name="!NEW_VERSION!"
            ) else (
                echo %%a
            )
        )
    ) > "%TEMP_FILE%"
    
    REM Replace original
    move /y "%TEMP_FILE%" "%PRESETS_FILE%" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to update export_presets.cfg
        exit /b 1
    )
    
    echo [VERSION] Updated to !NEW_VERSION!
    goto :eof

REM ============================================================
REM Create build directory for this version
REM ============================================================
:create_build_dir
    set "BUILD_DIR=%BUILD_BASE%\v!NEW_VERSION!"
    
    if not exist "%BUILD_DIR%" (
        mkdir "%BUILD_DIR%"
        echo [BUILD] Created: %BUILD_DIR%
    ) else (
        echo [BUILD] Directory exists: %BUILD_DIR%
    )
    
    set "EXE_PATH=%BUILD_DIR%\%EXPORT_NAME%.exe"
    set "APK_PATH=%BUILD_DIR%\%EXPORT_NAME%.apk"
    set "SIGNED_APK_PATH=%BUILD_DIR%\%EXPORT_NAME%_signed.apk"
    
    goto :eof

REM ============================================================
REM Export Windows EXE
REM ============================================================
:export_windows
    echo.
    echo ============================================================
    echo [WINDOWS] Exporting EXE...
    echo ============================================================
    
    REM Remove old EXE if exists
    if exist "%EXE_PATH%" del /f /q "%EXE_PATH%"
    
    REM Export
    "%GODOT_EXE%" --headless --export-release "Windows Desktop" "%EXE_PATH%" 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [WINDOWS] First attempt failed, retrying without --headless...
        "%GODOT_EXE%" --export-release "Windows Desktop" "%EXE_PATH%" 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: Windows export failed
            exit /b 1
        )
    )
    
    REM Verify
    if not exist "%EXE_PATH%" (
        echo ERROR: EXE not created
        exit /b 1
    )
    
    for %%f in ("%EXE_PATH%") do set "EXE_SIZE=%%~zf"
    set /a "EXE_SIZE_MB=!EXE_SIZE! / 1048576"
    
    echo [WINDOWS] OK: %EXE_PATH% (!EXE_SIZE_MB! MB)
    goto :eof

REM ============================================================
REM Export Android APK
REM ============================================================
:export_android
    echo.
    echo ============================================================
    echo [ANDROID] Exporting APK...
    echo ============================================================
    
    REM Remove old APK if exists
    if exist "%APK_PATH%" del /f /q "%APK_PATH%"
    
    REM Export
    "%GODOT_EXE%" --headless --export-release "Android" "%APK_PATH%" 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [ANDROID] First attempt failed, retrying without --headless...
        "%GODOT_EXE%" --export-release "Android" "%APK_PATH%" 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: Android export failed
            exit /b 1
        )
    )
    
    REM Verify
    if not exist "%APK_PATH%" (
        echo ERROR: APK not created
        exit /b 1
    )
    
    for %%f in ("%APK_PATH%") do set "APK_SIZE=%%~zf"
    set /a "APK_SIZE_MB=!APK_SIZE! / 1048576"
    
    echo [ANDROID] OK: %APK_PATH% (!APK_SIZE_MB! MB)
    goto :eof

REM ============================================================
REM Sign APK
REM ============================================================
:sign_apk
    echo.
    echo ============================================================
    echo [SIGN] Signing APK...
    echo ============================================================
    
    REM Copy APK to signed version
    copy /y "%APK_PATH%" "%SIGNED_APK_PATH%" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to copy APK for signing
        exit /b 1
    )
    
    REM Sign
    "%APKSIGNER%" sign --ks "%SCRIPT_DIR%.opencode\hardreset.keystore" --ks-key-alias hardreset "%SIGNED_APK_PATH%" 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: APK signing failed
        exit /b 1
    )
    
    echo [SIGN] OK: %SIGNED_APK_PATH%
    goto :eof

REM ============================================================
REM Verify signature
REM ============================================================
:verify_signature
    echo.
    echo ============================================================
    echo [VERIFY] Checking signature...
    echo ============================================================
    
    "%APKSIGNER%" verify --verbose --print-certs "%SIGNED_APK_PATH%" 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Signature verification failed
        exit /b 1
    )
    
    echo [VERIFY] Signature OK
    goto :eof

REM ============================================================
REM Generate report
REM ============================================================
:report
    echo.
    echo ============================================================
    echo                     BUILD REPORT
    echo ============================================================
    echo.
    echo Version:    !NEW_VERSION!
    echo Date:       %date% %time%
    echo Project:    %PROJECT_DIR%
    echo.
    echo --- Files ---
    echo.
    
    REM EXE info
    if exist "%EXE_PATH%" (
        for %%f in ("%EXE_PATH%") do (
            set "EXE_DATE=%%~tf"
            echo [Windows EXE]
            echo   Path:     %EXE_PATH%
            echo   Size:     %%~zf bytes (!EXE_SIZE_MB! MB)
            echo   Modified: !EXE_DATE!
            echo.
        )
    ) else (
        echo [Windows EXE] NOT FOUND
        echo.
    )
    
    REM APK info
    if exist "%SIGNED_APK_PATH%" (
        for %%f in ("%SIGNED_APK_PATH%") do (
            set "APK_DATE=%%~tf"
            echo [Android APK - SIGNED]
            echo   Path:     %SIGNED_APK_PATH%
            echo   Size:     %%~zf bytes (!APK_SIZE_MB! MB)
            echo   Modified: !APK_DATE!
            echo.
        )
    ) else (
        echo [Android APK] NOT FOUND
        echo.
    )
    
    echo --- Signature Details ---
    echo.
    "%APKSIGNER%" verify --print-certs "%SIGNED_APK_PATH%" 2>&1
    echo.
    echo ============================================================
    echo                     BUILD COMPLETE
    echo ============================================================
    echo.
    echo Ready to upload to GitHub using release.bat
    echo.
    goto :eof
