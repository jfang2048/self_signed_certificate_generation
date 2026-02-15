@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%cert_config.env"
set "ARG_CERT_FILE="
set "ARG_CERT_STORE="

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="-h" goto show_help
if /I "%~1"=="--help" goto show_help
if /I "%~1"=="-c" (
    set "CONFIG_FILE=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--config" (
    set "CONFIG_FILE=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--cert" (
    set "ARG_CERT_FILE=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--store" (
    set "ARG_CERT_STORE=%~2"
    shift
    shift
    goto parse_args
)
>&2 echo Error: Unknown option: %~1
exit /b 1

:show_help
echo Usage: %~nx0 [--config FILE] [--cert FILE] [--store STORE_NAME]
exit /b 0

:args_done
if not exist "%CONFIG_FILE%" (
    >&2 echo Error: Config file not found: %CONFIG_FILE%
    exit /b 1
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    set "K=%%A"
    set "V=%%B"
    if defined K (
        set "K=!K: =!"
        if not "!K!"=="" set "!K!=!V!"
    )
)

if not defined ROOT_CA_NAME set "ROOT_CA_NAME=ROOT_CA"
if not defined ROOT_CA_CRT_FILE set "ROOT_CA_CRT_FILE=!ROOT_CA_NAME!.crt"
if not defined WIN_CA_CERT_FILE set "WIN_CA_CERT_FILE=!ROOT_CA_CRT_FILE!"
if not defined WIN_CERT_STORE set "WIN_CERT_STORE=Root"
if not defined CERT_OUTPUT_DIR set "CERT_OUTPUT_DIR=."

if defined ARG_CERT_FILE set "WIN_CA_CERT_FILE=%ARG_CERT_FILE%"
if defined ARG_CERT_STORE set "WIN_CERT_STORE=%ARG_CERT_STORE%"

net session >nul 2>&1
if %errorlevel% neq 0 (
    >&2 echo Error: This script requires administrative privileges.
    exit /b 1
)

set "CERT_OUTPUT_DIR_WIN=!CERT_OUTPUT_DIR:/=\!"
set "certFilePath=!WIN_CA_CERT_FILE!"

if exist "!SCRIPT_DIR!!CERT_OUTPUT_DIR_WIN!\!WIN_CA_CERT_FILE!" (
    set "certFilePath=!SCRIPT_DIR!!CERT_OUTPUT_DIR_WIN!\!WIN_CA_CERT_FILE!"
) else if exist "!SCRIPT_DIR!!WIN_CA_CERT_FILE!" (
    set "certFilePath=!SCRIPT_DIR!!WIN_CA_CERT_FILE!"
)

if not exist "!certFilePath!" (
    >&2 echo Error: Certificate file not found: !certFilePath!
    exit /b 1
)

>&2 echo Importing certificate: !certFilePath!
>&2 echo Store: !WIN_CERT_STORE!
certutil -addstore -f "!WIN_CERT_STORE!" "!certFilePath!"
if %errorlevel% neq 0 (
    >&2 echo Error: Certificate import failed.
    exit /b %errorlevel%
)

echo WIN_CERT_PATH=!certFilePath!
echo WIN_CERT_STORE=!WIN_CERT_STORE!
endlocal
