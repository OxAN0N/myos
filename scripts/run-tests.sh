#!/bin/sh
# 사용: scripts/run-tests.sh build-test/os.img          (plan/tech-fixes.md #15)
# 커널(TEST=1 빌드)은 테스트마다 시리얼에 "PASS 이름" 또는 "FAIL 이름: 이유"를 한 줄씩 찍고,
# 끝나면 outb(0xf4, 0x10)(전부 통과) 또는 outb(0xf4, 0x11)(하나라도 실패)로 QEMU를 끈다.
# QEMU 종료 코드 = (값 << 1) | 1 이므로 0x10 → 33.
# 환경 변수: SMP(코어 수), TEST_TIMEOUT(초, 기본 30), QEMU_EXTRA(추가 옵션)
IMG=${1:?사용법: run-tests.sh <이미지>}
T=${TEST_TIMEOUT:-30}
TO=$(command -v gtimeout || command -v timeout) || { echo "gtimeout 없음: brew install coreutils"; exit 2; }
LOG=$(dirname "$IMG")/test.log
DISK=""
[ -f build/disk.img ] && DISK="-drive format=raw,file=build/disk.img,if=ide,index=1"

# shellcheck disable=SC2086
"$TO" "$T" qemu-system-x86_64 -drive format=raw,file="$IMG" -m 256M -smp "${SMP:-1}" \
  -serial stdio -display none -no-reboot \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04 $DISK $QEMU_EXTRA > "$LOG" 2>&1
code=$?

npass=$(grep -c '^PASS' "$LOG")
nfail=$(grep -c '^FAIL' "$LOG")
[ "$nfail" -gt 0 ] && grep '^FAIL' "$LOG"

case $code in
  33)
    if [ "$nfail" -eq 0 ]; then echo "PASS: 테스트 ${npass}개 (로그 $LOG)"; exit 0; fi ;;
  124)
    echo "FAIL: ${T}초 시간 초과(멈춤). 로그 마지막 3줄:"; tail -n 3 "$LOG"; exit 1 ;;
  0)
    echo "FAIL: QEMU가 종료 코드 0으로 끝남. 트리플 폴트 리셋일 가능성이 큼 → gmake trace"; exit 1 ;;
esac
echo "FAIL: 종료 코드 $code, PASS ${npass} / FAIL ${nfail} (로그 $LOG)"
exit 1
