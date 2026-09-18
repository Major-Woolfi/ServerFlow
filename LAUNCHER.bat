@echo off
setlocal

set SCRIPT_DIR=%~dp0

set BASH_PATH=

if exist "C:\Program Files\Git\bin\bash.exe" (
    set BASH_PATH=C:\Program Files\Git\bin\bash.exe
) else (
    for /f "delims=" %%i in ('wsl which bash 2^>nul') do set BASH_PATH=%%i
)

if "%BASH_PATH%"=="" (
    echo ERROR: No bash found. Install Git for Windows or WSL.
    pause
    exit /b 1
)

echo Starting ServerFlow...
"%BASH_PATH%" "%SCRIPT_DIR%LAUNCHER.sh"
if %ERRORLEVEL% neq 0 (
    echo Script failed. Press any key...
    pause >nul
)
