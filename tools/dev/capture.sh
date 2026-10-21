#!/usr/bin/env bash
# SuperLyric 设备侧诊断：重启目标宿主并抓取模块日志
# 用法: SL_DEVICE=<serial> bash tools/dev/capture.sh <package> <launch-component> [wait-seconds]
#
# 必须先把 logcat 落到文件再 grep：系统侧每秒写十几行播放状态日志，
# 缓冲区轮转极快，事后 `logcat -d` 已经看不到宿主进程启动阶段的模块日志。
export MSYS_NO_PATHCONV=1
set -u

PKG="${1:-cn.kuwo.kwmusiccar}"
COMP="${2:-cn.kuwo.kwmusiccar/.ui.WelcomeActivity}"
WAIT="${3:-14}"

D="${SL_DEVICE:-$(adb devices | awk '$2=="device"{print $1; exit}')}"
if [ -z "$D" ]; then
  echo "no device"
  exit 1
fi
echo "device: $D"

OUT="/tmp/sl-capture-$$.log"
adb -s "$D" logcat -c >/dev/null 2>&1
adb -s "$D" logcat -v time > "$OUT" 2>/dev/null &
LOGPID=$!
sleep 1
adb -s "$D" shell am force-stop "$PKG" >/dev/null 2>&1
sleep 1
adb -s "$D" shell am start -n "$COMP" >/dev/null 2>&1
sleep "$WAIT"
kill "$LOGPID" 2>/dev/null
wait "$LOGPID" 2>/dev/null

echo "=== module log (${PKG}) ==="
grep -F "(${PKG})[com.hchen.superlyric," "$OUT" \
  | sed 's/.*\[I\]: //; s/.*\[D\]: //; s/.*\[W\]: //; s/.*\[E\]: //'

echo "=== system-side lyric events ==="
grep -E 'sendLyric|Register publisher|orphaned|Active publisher' "$OUT" | tail -15
echo "=== raw log: $OUT ==="
