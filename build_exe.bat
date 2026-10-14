@echo off
rem ============================================================
rem  build_exe.bat — сборка WeatherCollector.exe из weather_collector.py
rem  Требуется установленный Python 3.8+ (python.org). PyInstaller
rem  будет установлен автоматически. Результат кладётся рядом
rem  с этим bat-файлом и в папку dist\.
rem ============================================================
chcp 65001 >nul
cd /d "%~dp0"

python -m pip install --upgrade pyinstaller pywin32 || goto :err

python -m PyInstaller --onefile --console --clean --name WeatherCollector --hidden-import win32timezone weather_collector.py || goto :err

copy /y "dist\WeatherCollector.exe" "WeatherCollector.exe" >nul || goto :err
echo.
echo ГОТОВО: WeatherCollector.exe
echo Первый запуск создаст WeatherCollector.ini рядом с exe:
echo   WeatherCollector.exe --city "Тихвин" --interval 30 --out D:\Project\WeatherRoll\weather.txt
echo.
pause
exit /b 0

:err
echo ОШИБКА сборки.
pause
exit /b 1
