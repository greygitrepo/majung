#!/usr/bin/env bash
# 헤드리스 에뮬레이터를 띄우고 부팅 완료까지 기다린다.
set -euo pipefail
if [ ! -e /dev/kvm ]; then echo "/dev/kvm 없음 — 하드웨어 가속 없이는 에뮬레이터가 너무 느립니다." >&2; exit 1; fi

emulator -avd test -no-window -no-audio -no-boot-anim -no-snapshot \
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
