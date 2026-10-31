# myos: 커널 코드 (어디에 무엇을 넣나)

이 폴더는 직접 씁니다. Claude는 읽고, 빌드하고, 테스트를 돌리고, 리뷰만 합니다(수정은 설정으로 막혀 있음).
제공된 것은 빌드 장치뿐입니다: `Makefile`, `linker.ld`, `include/layout.h`, `.gdbinit`, `scripts/`. 나머지는 주차별로 직접 만듭니다.
각 주의 Day별 파일은 `plan/weeks/Wnn.md`의 "코드·파일 위치" 열에 있습니다.

## 폴더별 역할

| 폴더 | 들어갈 것 | 주차 |
| --- | --- | --- |
| `boot/` | `mbr.asm`(16비트, 디스크 읽기·A20·GDT·보호 모드), `entry64.asm`(`section .boot`: 32비트 → 페이징 → 64비트 → `kmain`), `trampoline.asm`(AP용) | W1, W2, W6(E820), W21 |
| `include/` | 공용 헤더: `layout.h`(제공), `io.h`, `kprintf.h`, `interrupt.h`, `mm.h`, `proc.h`, `vfs.h` | 계속 |
| `kernel/` | `main.c`(kmain), 콘솔·시리얼·kprintf·panic, IDT·ISR·트랩, PIC·APIC·타이머·키보드, 락, per_cpu, GDT·TSS, syscall, ACPI, IPI | W2~W22 |
| `mm/` | E820, 물리 페이지·버디, 페이지 테이블·vmap, 슬랩·kmalloc, VMA, 페이지 폴트, CoW, uaccess, TLB shootdown | W6~W16, W22 |
| `proc/` | task, `switch.asm`, 스케줄러, 유저 모드 진입, ELF, fork·exit·wait·exec, FPU, SMP | W9~W26 |
| `fs/` | ATA, 버퍼 캐시, VFS, namei, SimpleFS, fd 시스템 콜, 파이프 | W17~W26 |
| `lib/` | `string.c`(memcpy 등 4개, W3) 같은 커널 공용 함수 | W3~ |
| `user/` | 유저 프로그램: W11 어셈블리 조각, W12 `linker.ld`(0x400000), `crt0.S`, `ulibc.c`, `umalloc.c`, `sh.c`, `bin/*.c` | W11~W27 |
| `tests/` | 커널 안 테스트 `test_*.c`. `TEST=1` 빌드에만 들어감 | W5~ |
| `scripts/` | `run-tests.sh`, `size-check.sh`(제공), `mkfs.c`(W19, 맥 clang으로 빌드) | W5, W19 |
| `docs/` | 마지막 주 전체 흐름 문서 | W28 |

## 빌드가 하는 일

```
boot/entry64.asm + kernel/ mm/ proc/ fs/ lib/ (+ tests/)
        │  x86_64-elf-gcc / nasm
        ▼
build/kernel.elf ── linker.ld: .boot는 0x10000, 나머지는 0xFFFFFFFF80000000+
        │  objcopy -O binary
        ▼
build/kernel.bin ── 크기로 섹터 수 계산 → nasm -DKERNEL_SECTORS=N boot/mbr.asm
        ▼
build/os.img = mbr.bin(512B) + kernel.bin + 빈 섹터 1개
```

`include/layout.h`의 숫자는 Makefile이 `build/layout.inc`로 바꿔 주므로 어셈블리에서 `%include "layout.inc"`로 같은 이름을 씁니다.

## 첫 주(W1) 시작하기

1. Day 2~4는 커널 없이 MBR만 있습니다. `boot/mbr.asm`만 만들고 `gmake run-mbr`로 띄웁니다.
   MBR 맨 위에 `org 0x7c00`, `%include "layout.inc"`, 맨 끝에 `times 510-($-$$) db 0`과 `dw 0xAA55`.
   읽을 섹터 수는 `KERNEL_SECTORS` 이름으로 쓰면 Makefile이 넣어 줍니다(run-mbr에서는 1).
2. Day 5에 `boot/entry64.asm`을 만들면(`section .boot`, `bits 32`, `global _start32`) `gmake run`이 전체 이미지를 씁니다.
3. 디버깅: 터미널 1에서 `gmake debug`, 터미널 2에서 `gmake gdb` → `set architecture i8086` → `b *0x7c00` → `c`.
4. 막히면 `gmake trace` 후 `build/qemu.log`의 마지막 예외 줄을 보고, 2시간 규칙(PLAN.md)을 지킵니다.

## 테스트 규칙 (W5부터)

- 커널은 `-DKTEST`로 빌드되면 `tests/`의 테스트를 실행하고, 테스트마다 시리얼에 `PASS 이름` 또는 `FAIL 이름: 이유` 한 줄을 찍습니다.
- 모두 끝나면 `outb(0xf4, 0x10)`(전부 통과) 또는 `outb(0xf4, 0x11)`로 QEMU를 끕니다.
- `gmake test`가 30초 안에 안 끝나면 FAIL, 트리플 폴트로 리셋되면 FAIL입니다.
