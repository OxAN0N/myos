#!/bin/sh
# 사용: scripts/size-check.sh [mbr.bin ...] [kernel.bin]   (plan/tech-fixes.md #4)
# MBR: 정확히 512바이트, 끝이 55 AA, 실제 코드가 쓰는 바이트(뒤쪽 0 패딩 제외)를 보고
# 커널: 458752바이트(448KB) 이하
fail=0
for f in "$@"; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  case "$f" in
    *mbr*.bin)
      if [ "$size" -ne 512 ]; then
        echo "FAIL: $f 는 ${size}B (512여야 함)"; fail=1; continue
      fi
      sig=$(tail -c 2 "$f" | od -An -tx1 | tr -d ' \n')
      if [ "$sig" != "55aa" ]; then echo "FAIL: $f 끝 2바이트가 55 AA가 아님 ($sig)"; fail=1; fi
      used=$(head -c 510 "$f" | od -An -v -tu1 | tr -s ' \n' '\n' | grep -v '^$' |
             awk '{ if ($1 != 0) last = NR } END { print last + 0 }')
      echo "OK: MBR 코드 약 ${used}/510B 사용"
      ;;
    *)
      if [ "$size" -gt 458752 ]; then
        echo "FAIL: $f ${size}B > 448KB. 2단계 로더 대신 Limine으로 전환 (PLAN.md 규칙 4)"; fail=1
      else
        echo "OK: 커널 ${size}B / 458752B"
      fi
      ;;
  esac
done
exit $fail
