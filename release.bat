@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM Release — Hard Reset
REM Version: 1.0
REM Date: 2026-07-13
REM 
REM What it does:
REM   1. Finds latest build in build/v{version}/
REM   2. Shows files and version diff
REM   3. Asks for confirmation
REM   4. Creates git tag v{version}
REM   5. Pushes tag to GitHub
REM   6. Creates GitHub Release via gh CLI
REM   7. Saves download links to {date}_links.txt
REM ============================================================

call :main %*
exit /b %ERRORLEVEL%

:main
    call :init
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :find_latest_build
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :show_files
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :ask_confirmation
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :create_tag
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :push_tag
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :create_release
    if %ERRORLEVEL% neq 0 exit /b 1
    
    call :save_links
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
    set "LINKS_DIR=%SCRIPT_DIR%.release"
    set "EXPORT_NAME=hardreset"
    set "BUILD_VERSION="
    set "BUILD_DIR="
    set "EXE_PATH="
    set "APK_PATH="
    set "GIT_REMOTE="
    set "REPO_URL="
    
    REM Check gh CLI
    where gh >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: GitHub CLI (gh) not found
        echo Install from: https://cli.github.com/
        exit /b 1
    )
    
    REM Check git
    where git >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: git not found
        exit /b 1
    )
    
    REM Check build directory
    if not exist "%BUILD_BASE%" (
        echo ERROR: Build directory not found: %BUILD_BASE%
        echo Run build.bat first
        exit /b 1
    )
    
    echo [INIT] Dependencies OK
    goto :eof

REM ============================================================
REM Find latest build (highest version number)
REM ============================================================
:find_latest_build
    set "LATEST_VERSION="
    set "LATEST_DIR="
    
    for /d %%d in ("%BUILD_BASE%\v*") do (
        set "DIR_NAME=%%~nxd"
        set "VER=!DIR_NAME:v=!"
        
        if "!LATEST_VERSION!"=="" (
            set "LATEST_VERSION=!VER!"
            set "LATEST_DIR=%%d"
        ) else (
            REM Compare versions (simple string compare, works for x.y.z)
            if "!VER!" gtr "!LATEST_VERSION!" (
                set "LATEST_VERSION=!VER!"
                set "LATEST_DIR=%%d"
            )
        )
    )
    
    if "!LATEST_DIR!"=="" (
        echo ERROR: No builds found in %BUILD_BASE%
        echo Run build.bat first
        exit /b 1
    )
    
    set "BUILD_VERSION=!LATEST_VERSION!"
    set "BUILD_DIR=!LATEST_DIR!"
    set "EXE_PATH=!BUILD_DIR!\%EXPORT_NAME%.exe"
    set "APK_PATH=!BUILD_DIR!\%EXPORT_NAME%_signed.apk"
    
    echo [BUILD] Found: v!BUILD_VERSION! in !BUILD_DIR!
    goto :eof

REM ============================================================
REM Show files and version info
REM ============================================================
:show_files
    echo.
    echo ============================================================
    echo                     RELEASE PREVIEW
    echo ============================================================
    echo.
    echo Version: v!BUILD_VERSION!
    echo Build:   !BUILD_DIR!
    echo.
    
    REM EXE info
    if exist "!EXE_PATH!" (
        for %%f in ("!EXE_PATH!") do (
            set "EXE_SIZE=%%~zf"
            set /a "EXE_SIZE_MB=!EXE_SIZE! / 1048576"
            echo [Windows EXE]
            echo   Path:     !EXE_PATH!
            echo   Size:     !EXE_SIZE_MB! MB
            echo.
        )
    ) else (
        echo [Windows EXE] NOT FOUND: !EXE_PATH!
        echo.
    )
    
    REM APK info
    if exist "!APK_PATH!" (
        for %%f in ("!APK_PATH!") do (
            set "APK_SIZE=%%~zf"
            set /a "APK_SIZE_MB=!APK_SIZE! / 1048576"
            echo [Android APK - SIGNED]
            echo   Path:     !APK_PATH!
            echo   Size:     !APK_SIZE_MB! MB
            echo.
        )
    ) else (
        echo [Android APK] NOT FOUND: !APK_PATH!
        echo.
    )
    
    REM Git status
    echo --- Git Status ---
    echo.
    git status --short
    echo.
    
    REM Check existing tags
    echo --- Existing Tags ---
    echo.
    git tag -l "v*"
    echo.
    
    REM Check if tag already exists
    git tag -l "v!BUILD_VERSION!" | findstr /r "." >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo WARNING: Tag v!BUILD_VERSION! already exists!
        echo.
    )
    
    echo ============================================================
    echo.
    goto :eof

REM ============================================================
REM Ask for confirmation
REM ============================================================
:ask_confirmation
    set /p "CONFIRM=Do you want to release v!BUILD_VERSION!? (YES/NO): "
    
    if /i "!CONFIRM!"=="YES" (
        echo [CONFIRM] Proceeding with release...
    ) else (
        echo [CONFIRM] Cancelled by user
        exit /b 1
    )
    
    echo.
    goto :eof

REM ============================================================
REM Create git tag
REM ============================================================
:create_tag
    echo ============================================================
    echo [TAG] Creating tag v!BUILD_VERSION!...
    echo ============================================================
    
    REM Check if tag exists
    git tag -l "v!BUILD_VERSION!" | findstr /r "." >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo [TAG] Tag v!BUILD_VERSION! already exists, skipping creation
    ) else (
        git tag -a "v!BUILD_VERSION!" -m "Release v!BUILD_VERSION!"
        if %ERRORLEVEL% neq 0 (
            echo ERROR: Failed to create tag
            exit /b 1
        )
        echo [TAG] Created: v!BUILD_VERSION!
    )
    
    echo.
    goto :eof

REM ============================================================
REM Push tag to GitHub
REM ============================================================
:push_tag
    echo ============================================================
    echo [PUSH] Pushing tag to GitHub...
    echo ============================================================
    
    git push origin "v!BUILD_VERSION!"
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to push tag
        exit /b 1
    )
    
    echo [TAG] Pushed: v!BUILD_VERSION!
    echo.
    goto :eof

REM ============================================================
REM Create GitHub Release
REM ============================================================
:create_release
    echo ============================================================
    echo [RELEASE] Creating GitHub Release...
    echo ============================================================
    
    REM Build release notes
    set "NOTES=Hard Reset v!BUILD_VERSION!"
    
    REM Create release with gh CLI
    gh release create "v!BUILD_VERSION!" ^
        --title "Hard Reset v!BUILD_VERSION!" ^
        --notes "!NOTES!" ^
        "!EXE_PATH!#hardreset.exe (Windows)" ^
        "!APK_PATH!#hardreset.apk (Android)"
    
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to create GitHub Release
        exit /b 1
    )
    
    echo [RELEASE] Created: v!BUILD_VERSION!
    echo.
    goto :eof

REM ============================================================
REM Save links to file
REM ============================================================
:save_links
    echo ============================================================
    echo [LINKS] Saving download links...
    echo ============================================================
    
    REM Get repo URL
    for /f "delims=" %%a in ('git remote get-url origin') do set "REPO_URL=%%a"
    
    REM Create links directory if not exists
    if not exist "%LINKS_DIR%" mkdir "%LINKS_DIR%"
    
    REM Generate filename with date
    for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value 2^>nul ^| find "="') do set "DT=%%a"
    set "DATE_FILE=!DT:~0,8!"
    set "LINKS_FILE=%LINKS_DIR%\!DATE_FILE!_links.txt"
    
    REM Write links
    (
        echo ============================================================
        echo Hard Reset — Download Links
        echo Version: v!BUILD_VERSION!
        echo Date: %date% %time%
        echo ============================================================
        echo.
        echo GitHub Release:
        echo https://github.com/igetpaid/hard-reset/releases/tag/v!BUILD_VERSION!
        echo.
        echo Direct Downloads:
        echo.
        echo Windows EXE:
        echo https://github.com/igetpaid/hard-reset/releases/download/v!BUILD_VERSION!/hardreset.exe
        echo.
        echo Android APK:
        echo https://github.com/igetpaid/hard-reset/releases/download/v!BUILD_VERSION!/hardreset.apk
        echo.
        echo ============================================================
    ) > "!LINKS_FILE!"
    
    echo [LINKS] Saved to: !LINKS_FILE!
    echo.
    goto :eof

REM ============================================================
REM Final report
REM ============================================================
:report
    echo ============================================================
    echo                     RELEASE COMPLETE
    echo ============================================================
    echo.
    echo Version:  v!BUILD_VERSION!
    echo Tag:      v!BUILD_VERSION!
    echo Release:  https://github.com/igetpaid/hard-reset/releases/tag/v!BUILD_VERSION!
    echo.
    echo Files uploaded:
    if exist "!EXE_PATH!" echo   - hardreset.exe (Windows)
    if exist "!APK_PATH!" echo   - hardreset.apk (Android)
    echo.
    echo Links saved to: !LINKS_FILE!
    echo.
    echo ============================================================
    echo.
    goto :eof
