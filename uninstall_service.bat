@echo off
rem ============================================================
rem  uninstall_service.bat — остановка и удаление службы
rem  WeatherCollector. ЗАПУСКАТЬ ОТ ИМЕНИ АДМИНИСТРАТОРА.
rem ============================================================
chcp 65001 >nul
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo Требуются права администратора.
    pause
    exit /b 1
)

WeatherCollector.exe stop 2>nul
WeatherCollector.exe remove || goto :err
echo Служба WeatherCollector удалена.
pause
exit /b 0

:err
echo ОШИБКА удаления службы.
pause
exit /b 1
