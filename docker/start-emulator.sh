#!/usr/bin/env bash
# 에뮬레이터를 띄우고 부팅 완료까지 기다린다.
# 기본은 헤드리스. EMULATOR_WINDOW=1 이면 호스트 X11 화면에 창을 띄운다 (emulator-gui 서비스).
set -euo pipefail
if [ ! -e /dev/kvm ]; then echo "/dev/kvm 없음 — 하드웨어 가속 없이는 에뮬레이터가 너무 느립니다." >&2; exit 1; fi

WINDOW_OPTS=(-no-window)
if [ "${EMULATOR_WINDOW:-0}" = "1" ]; then
  if [ -z "${DISPLAY:-}" ]; then echo "DISPLAY 없음 — 호스트에서 DISPLAY 를 넘겨 주세요." >&2; exit 1; fi
  WINDOW_OPTS=()
fi

emulator -avd test "${WINDOW_OPTS[@]}" -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -memory 3072 > /tmp/emulator.log 2>&1 &

adb wait-for-device
for i in $(seq 1 120); do
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
  sleep 2
done
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
echo "에뮬레이터 준비 완료"
