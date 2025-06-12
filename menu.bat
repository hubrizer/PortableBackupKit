@echo off
set KITDIR=%~dp0

:menu
cls
echo === PortableBackupKit Menu ===

echo 1^)^ Setup
echo 2^)^ Restore
echo 3^)^ Uninstall
echo 4^)^ Update
echo 5^)^ Exit

echo.
set /p choice=Select an option ^(1-5^):
if "%choice%"=="1" (
    powershell -ExecutionPolicy Bypass -File "%KITDIR%setup.ps1"
    goto menu
) else if "%choice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "%KITDIR%restore.ps1"
    goto menu
) else if "%choice%"=="3" (
    powershell -ExecutionPolicy Bypass -File "%KITDIR%uninstall.ps1"
    goto menu
) else if "%choice%"=="4" (
    powershell -ExecutionPolicy Bypass -File "%KITDIR%update.ps1"
    goto menu
) else if "%choice%"=="5" (
    goto end
) else (
    echo Invalid choice.
    timeout /t 2 /nobreak >nul
    goto menu
)

:end
