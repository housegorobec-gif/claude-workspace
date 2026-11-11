#!/system/bin/sh
# Безопасная очистка мусора на Android-магнитоле.
# Выполняется на самом устройстве через `adb shell`, root не нужен.
#
#   sh clean_device.sh report          показать, что занимает место (ничего не удаляет)
#   sh clean_device.sh clean           удалить кэш приложений и временные файлы
#   sh clean_device.sh apps            список приложений (сторонние, отключённые, системные)
#   sh clean_device.sh disable <пакет> отключить приложение (обратимо)
#   sh clean_device.sh enable <пакет>  включить отключённое приложение обратно
#
# Музыка, видео, фото, загрузки и сами приложения режимом clean не трогаются.

MODE=${1:-report}
PKG=$2
SD=${EXTERNAL_STORAGE:-/sdcard}

# Папки, содержимое которых можно удалять без последствий:
# приложения и система пересоздают их сами.
JUNK_DIRS="
$SD/Android/data/*/cache
$SD/LOST.DIR
$SD/DCIM/.thumbnails
$SD/Pictures/.thumbnails
$SD/Movies/.thumbnails
$SD/Music/.thumbnails
$SD/mtklog
$SD/debuglogger
"

human() {
  kb=${1:-0}
  if [ "$kb" -ge 1048576 ]; then
    echo "$((kb / 1048576)).$((kb % 1048576 * 10 / 1048576)) ГБ"
  elif [ "$kb" -ge 1024 ]; then
    echo "$((kb / 1024)) МБ"
  else
    echo "$kb КБ"
  fi
}

# Свободное место во внутренней памяти, КБ (0, если df не понял).
free_kb() {
  df -k /data 2>/dev/null | {
    read -r _
    read -r _ _ _ avail _
    case $avail in
      '' | *[!0-9]*) echo 0 ;;
      *) echo "$avail" ;;
    esac
  }
}

# Суммарный размер переданных путей, КБ.
size_kb() {
  total=0
  for p in "$@"; do
    [ -e "$p" ] || continue
    s=$(du -sk "$p" 2>/dev/null | { read -r k _; echo "${k:-0}"; })
    case $s in *[!0-9]*) s=0 ;; esac
    total=$((total + s))
  done
  echo "$total"
}

strip_prefix() {
  n=0
  while read -r line; do
    echo "  ${line#package:}"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || echo "  нет"
}

report() {
  echo "=== Магнитола ==="
  echo "Модель:   $(getprop ro.product.manufacturer) $(getprop ro.product.model)"
  echo "Android:  $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
  free=$(free_kb)
  if [ "$free" -gt 0 ]; then
    echo "Свободно: $(human "$free") во внутренней памяти"
  else
    echo "Свободно: неизвестно (df не ответил)"
  fi
  echo "Сторонних приложений: $(pm list packages -3 2>/dev/null | wc -l)"
  echo

  echo "=== Что больше всего занимает место в $SD ==="
  du -sk "$SD"/* "$SD"/.[!.]* 2>/dev/null | sort -rn | head -n 15 |
    while read -r kb path; do
      printf '%12s  %s\n' "$(human "$kb")" "$path"
    done
  echo

  echo "=== Мусор, который удалит режим clean ==="
  total=0
  set -f
  for pattern in $JUNK_DIRS; do
    set +f
    # shellcheck disable=SC2086  # шаблон должен раскрыться
    kb=$(size_kb $pattern)
    set -f
    [ "$kb" -gt 0 ] || continue
    printf '%12s  %s\n' "$(human "$kb")" "$pattern"
    total=$((total + kb))
  done
  set +f
  echo "Итого: $(human "$total") + кэш приложений во внутренней памяти"
  echo

  echo "=== Установщики APK в Download (сами не удаляются, проверьте вручную) ==="
  found=0
  for f in "$SD"/Download/*.apk "$SD"/Download/*.APK; do
    [ -f "$f" ] || continue
    found=1
    printf '%12s  %s\n' "$(human "$(size_kb "$f")")" "$f"
  done
  [ "$found" = 1 ] || echo "  нет"
}

clean() {
  before=$(free_kb)

  echo "Очищаю кэш приложений во внутренней памяти..."
  out=$(pm trim-caches 999G 2>&1)
  if [ -n "$out" ]; then echo "  $out"; else echo "  готово"; fi

  echo "Удаляю временные файлы в $SD..."
  set -f
  for pattern in $JUNK_DIRS; do
    set +f
    for d in $pattern; do
      [ -d "$d" ] || continue
      rm -rf "${d:?}"/* "${d:?}"/.[!.]* 2>/dev/null
    done
    set -f
  done
  set +f
  sync

  after=$(free_kb)
  if [ "$before" -gt 0 ] && [ "$after" -gt 0 ]; then
    freed=$((after - before))
    [ "$freed" -gt 0 ] || freed=0
    echo "Освобождено: $(human "$freed"). Свободно сейчас: $(human "$after")"
  else
    echo "Готово (размер освобождённого места измерить не удалось)."
  fi
}

apps() {
  echo "=== Сторонние приложения (установлены вами или продавцом) ==="
  pm list packages -3 2>/dev/null | sort | strip_prefix
  echo
  echo "=== Отключённые приложения ==="
  pm list packages -d 2>/dev/null | sort | strip_prefix
  echo
  echo "=== Системные приложения (без нужды не трогать) ==="
  pm list packages -s 2>/dev/null | sort | strip_prefix
}

usage() {
  echo "Режимы: report | clean | apps | disable <пакет> | enable <пакет>"
}

case $MODE in
  report) report ;;
  clean) clean ;;
  apps) apps ;;
  disable)
    [ -n "$PKG" ] || { usage; exit 1; }
    pm disable-user --user 0 "$PKG"
    ;;
  enable)
    [ -n "$PKG" ] || { usage; exit 1; }
    pm enable "$PKG"
    ;;
  *)
    usage
    exit 1
    ;;
esac
