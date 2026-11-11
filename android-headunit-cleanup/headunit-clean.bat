@echo off
chcp 65001 >nul
setlocal
rem Подключается к магнитоле по ADB через сеть и запускает на ней clean_device.sh.
rem   headunit-clean.bat                  отчёт: что занимает место (ничего не удаляет)
rem   headunit-clean.bat clean            удалить кэш и временные файлы
rem   headunit-clean.bat apps             список приложений
rem   headunit-clean.bat disable ^<пакет^>  отключить приложение (обратимо)
rem   headunit-clean.bat enable ^<пакет^>   включить обратно
rem Другой адрес: set HEADUNIT=192.168.2.150:37123

if "%HEADUNIT%"=="" set "HEADUNIT=192.168.2.150:5555"
set "REMOTE=/data/local/tmp/headunit_clean.sh"
set "MODE=%~1"

where adb >nul 2>nul
if errorlevel 1 goto no_adb

adb connect %HEADUNIT% >nul 2>nul
set "STATE="
for /f "delims=" %%s in ('adb -s %HEADUNIT% get-state 2^>^&1') do if not defined STATE set "STATE=%%s"
if "%STATE%"=="device" goto connected
echo %STATE% | find "unauthorized" >nul
if not errorlevel 1 goto unauthorized
goto not_connected

:connected
if /i "%MODE%"=="clean" goto confirm_clean
if /i "%MODE%"=="disable" goto confirm_disable
goto run

:confirm_clean
set "ANS="
set /p "ANS=Удалить кэш приложений и временные файлы на %HEADUNIT%? [y/N] "
if /i not "%ANS%"=="y" exit /b 0
goto run

:confirm_disable
set "ANS="
set /p "ANS=Отключить приложение %~2 на %HEADUNIT%? [y/N] "
if /i not "%ANS%"=="y" exit /b 0
goto run

:run
adb -s %HEADUNIT% push "%~dp0clean_device.sh" %REMOTE% >nul
if errorlevel 1 exit /b 1
adb -s %HEADUNIT% shell sh %REMOTE% %*
set "RC=%ERRORLEVEL%"
adb -s %HEADUNIT% shell rm -f %REMOTE%
exit /b %RC%

:no_adb
echo adb не найден. Установите Android SDK Platform-Tools и добавьте папку в PATH:
echo   https://developer.android.com/tools/releases/platform-tools
exit /b 1

:unauthorized
echo Магнитола спрашивает разрешение на отладку: нажмите «Разрешить» на её экране и запустите скрипт снова.
exit /b 1

:not_connected
echo Не удалось подключиться к %HEADUNIT%:
echo   %STATE%
echo Проверьте, что компьютер и магнитола в одной сети и на магнитоле включена
echo «Отладка по USB» + «ADB по сети» (Настройки -^> Для разработчиков).
echo Если там «Беспроводная отладка» (Android 11+), сделайте adb pair и укажите порт:
echo   set HEADUNIT=192.168.2.150:^<порт^>
exit /b 1
