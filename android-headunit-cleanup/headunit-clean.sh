#!/usr/bin/env bash
# Подключается к магнитоле по ADB через сеть и запускает на ней clean_device.sh.
#
#   ./headunit-clean.sh                  отчёт: что занимает место (ничего не удаляет)
#   ./headunit-clean.sh clean            удалить кэш и временные файлы
#   ./headunit-clean.sh apps             список приложений
#   ./headunit-clean.sh disable <пакет>  отключить приложение (обратимо)
#   ./headunit-clean.sh enable <пакет>   включить обратно
#
# Адрес по умолчанию 192.168.2.150:5555, другой задаётся так:
#   HEADUNIT=192.168.2.150:37123 ./headunit-clean.sh
set -euo pipefail

DEVICE=${HEADUNIT:-192.168.2.150:5555}
REMOTE=/data/local/tmp/headunit_clean.sh
HERE=$(cd "$(dirname "$0")" && pwd)
MODE=${1:-report}

if ! command -v adb >/dev/null; then
  echo "adb не найден. Установите Android SDK Platform-Tools:"
  echo "  https://developer.android.com/tools/releases/platform-tools"
  exit 1
fi

adb connect "$DEVICE" >/dev/null 2>&1 || true
state=$(adb -s "$DEVICE" get-state 2>&1 || true)
case $state in
  device) ;;
  *unauthorized*)
    echo "Магнитола спрашивает разрешение на отладку: нажмите «Разрешить» на её экране и запустите скрипт снова."
    exit 1
    ;;
  *)
    echo "Не удалось подключиться к $DEVICE:"
    echo "  $state"
    echo "Проверьте, что компьютер и магнитола в одной сети и на магнитоле включена"
    echo "«Отладка по USB» + «ADB по сети» (Настройки → Для разработчиков)."
    echo "Если там «Беспроводная отладка» (Android 11+), сделайте adb pair и укажите порт:"
    echo "  HEADUNIT=192.168.2.150:<порт> $0 $*"
    exit 1
    ;;
esac

confirm() {
  local ans
  read -r -p "$1 [y/N] " ans || true
  case $ans in
    y* | Y* | д* | Д*) ;;
    *) exit 0 ;;
  esac
}

case $MODE in
  clean) confirm "Удалить кэш приложений и временные файлы на $DEVICE?" ;;
  disable) confirm "Отключить приложение ${2:-?} на $DEVICE?" ;;
esac

adb -s "$DEVICE" push "$HERE/clean_device.sh" "$REMOTE" >/dev/null
rc=0
adb -s "$DEVICE" shell sh "$REMOTE" "$@" || rc=$?
adb -s "$DEVICE" shell rm -f "$REMOTE" || true
exit "$rc"
