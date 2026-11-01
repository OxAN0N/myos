# myos/Makefile: 맥에서는 반드시 gmake로 실행 (맥 기본 make 3.81은 너무 오래됨)
#
#   gmake              커널 이미지 빌드 (build/os.img)
#   gmake run-mbr      W1 Day 2~4: MBR만 띄워 보기 (커널 없이)
#   gmake run          QEMU 실행. 시리얼 출력은 이 터미널로. QEMU 창에서 Ctrl+Option+2 = 모니터
#   gmake debug        QEMU를 멈춘 채 띄움 → 다른 터미널에서 gmake gdb
#   gmake gdb          x86_64-elf-gdb (.gdbinit 사용)
#   gmake trace        예외·리셋 로그를 build/qemu.log에 (트리플 폴트 원인 찾기)
#   gmake test         TEST=1로 빌드해 커널 테스트 실행 (W5부터)
#   gmake test-soak    test를 100번 반복 (W23)
#   gmake check        크기·SSE 혼입·포맷·정적 분석·복잡도 (pre-commit 훅이 실행)
#   gmake disasm       섹션 주소 출력 + build/kernel.lst에 소스 섞인 디스어셈블
#   gmake disk         두 번째 디스크 build/disk.img 64MB (W17부터)
#   변수: SMP=4  DEBUG=1(-Og)  ACCEL=(Apple Silicon은 비워 둠: TCG만 가능)

CROSS   ?= x86_64-elf-
CC      := $(CROSS)gcc
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
GDB     ?= $(CROSS)gdb
NASM    ?= nasm
QEMU    ?= qemu-system-x86_64

BUILD := build
ifeq ($(TEST),1)
BUILD := build-test
endif

OPT := -O2
ifeq ($(DEBUG),1)
OPT := -Og
endif

# 플래그마다 이유는 plan/tech-fixes.md #1
CFLAGS := -std=gnu11 $(OPT) -g -Wall -Wextra -Iinclude \
          -ffreestanding -fno-stack-protector -fno-pic -fno-pie \
          -fno-omit-frame-pointer \
          -mno-red-zone -mcmodel=kernel -mgeneral-regs-only
ifeq ($(TEST),1)
CFLAGS += -DKTEST
endif
LDFLAGS   := -nostdlib -static -T linker.ld -z max-page-size=0x1000 -z noexecstack --no-warn-rwx-segments
NASMFLAGS := -f elf64 -g -F dwarf -I$(BUILD)/

KDIRS   := kernel mm proc fs lib
SRCDIRS := $(KDIRS) $(if $(filter 1,$(TEST)),tests)
CSRCS   := $(foreach d,$(SRCDIRS),$(wildcard $(d)/*.c))
# entry64.asm이 맨 앞이어야 .boot의 첫 바이트가 _start32가 된다 (tech-fixes #3)
ASRCS   := $(wildcard boot/entry64.asm) $(foreach d,$(KDIRS),$(wildcard $(d)/*.asm))
OBJS    := $(patsubst %.asm,$(BUILD)/%.o,$(ASRCS)) $(patsubst %.c,$(BUILD)/%.o,$(CSRCS))
# W12~: user/ 프로그램 빌드 규칙은 직접 추가한다 (user/linker.ld, -mgeneral-regs-only, objcopy → incbin)
# W21~: boot/trampoline.asm은 nasm -f bin으로 따로 만들어 커널에 incbin 한다

SMP   ?= 1
ACCEL ?=
DISK  := build/disk.img
QEMU_BASE := -drive format=raw,file=$(BUILD)/os.img -m 256M -smp $(SMP) -serial stdio
ifneq ($(wildcard $(DISK)),)
QEMU_BASE += -drive format=raw,file=$(DISK),if=ide,index=1
endif
ifneq ($(ACCEL),)
QEMU_BASE += -accel $(ACCEL)
endif

.PHONY: all run run-mbr debug gdb trace test test-soak check disasm disk clean
all: $(BUILD)/os.img

# layout.h의 #define을 nasm용 %define으로 바꿔 어셈블리와 C가 같은 숫자를 쓰게 한다
$(BUILD)/layout.inc: include/layout.h
	@mkdir -p $(BUILD)
	sed -E -n 's|/\*.*\*/||; s|^#define[[:space:]]+([A-Z0-9_]+)[[:space:]]+([^[:space:]]+).*$$|%define \1 \2|p' $< > $@

$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD)/%.o: %.asm $(BUILD)/layout.inc
	@mkdir -p $(dir $@)
	$(NASM) $(NASMFLAGS) $< -o $@

-include $(OBJS:.o=.d)

$(BUILD)/kernel.elf: $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(BUILD)/kernel.bin: $(BUILD)/kernel.elf
	$(OBJCOPY) -O binary $< $@
	@echo "kernel.bin: $$(wc -c < $@ | tr -d ' ') bytes (한도 458752)"

# 읽을 섹터 수는 여기서 계산해 MBR에 -DKERNEL_SECTORS로 넘긴다
$(BUILD)/mbr.bin: boot/mbr.asm $(BUILD)/kernel.bin $(BUILD)/layout.inc
	$(NASM) -f bin -I$(BUILD)/ -DKERNEL_SECTORS=$$(( ($$(wc -c < $(BUILD)/kernel.bin) + 511) / 512 )) $< -o $@

$(BUILD)/os.img: $(BUILD)/mbr.bin $(BUILD)/kernel.bin
	cat $^ > $@
	dd if=/dev/zero bs=512 count=1 >> $@ 2>/dev/null

# W1 Day 2~4용: 커널 없이 MBR만. 읽을 섹터는 1개(빈 섹터)
$(BUILD)/mbr-only.img: boot/mbr.asm $(BUILD)/layout.inc
	$(NASM) -f bin -I$(BUILD)/ -DKERNEL_SECTORS=1 $< -o $(BUILD)/mbr-only.bin
	cat $(BUILD)/mbr-only.bin > $@
	dd if=/dev/zero bs=512 count=1 >> $@ 2>/dev/null

run-mbr: $(BUILD)/mbr-only.img
	$(QEMU) -drive format=raw,file=$< -m 256M -serial stdio

run: all
	$(QEMU) $(QEMU_BASE)

debug: all
	@echo "다른 터미널에서: cd $(CURDIR) && gmake gdb"
	$(QEMU) $(QEMU_BASE) -s -S

gdb:
	$(GDB)

trace: all
	-$(QEMU) $(QEMU_BASE) -d int,cpu_reset -no-reboot -no-shutdown -D $(BUILD)/qemu.log
	@echo "로그: $(BUILD)/qemu.log (마지막 'v=' 줄의 예외 번호, e=에러 코드, CR2, RIP를 보세요)"

test:
	$(MAKE) TEST=1 all
	SMP=$(SMP) scripts/run-tests.sh build-test/os.img

test-soak:
	$(MAKE) TEST=1 all
	@for i in $$(seq 1 100); do \
	  SMP=$(SMP) QEMU_EXTRA="$(if $(ACCEL),-accel $(ACCEL))" scripts/run-tests.sh build-test/os.img > /dev/null \
	  || { echo "실패: $$i번째 (build-test/test.log)"; exit 1; }; \
	done; echo "100회 통과"

# 아직 커널이 없으면(W1 Day 2~4) MBR만 검사한다
ifneq ($(wildcard boot/entry64.asm),)
CHECK_DEPS := all
else ifneq ($(wildcard boot/mbr.asm),)
CHECK_DEPS := $(BUILD)/mbr-only.img
else
CHECK_DEPS :=
endif

check: $(CHECK_DEPS)
	@scripts/size-check.sh $(wildcard $(BUILD)/mbr.bin $(BUILD)/mbr-only.bin) $(wildcard $(BUILD)/kernel.bin)
	@if [ -f $(BUILD)/kernel.elf ]; then \
	  if $(OBJDUMP) -d $(BUILD)/kernel.elf | grep -q 'xmm[0-9]'; then echo "FAIL: 커널에 SSE(XMM) 명령 (tech-fixes #1)"; exit 1; \
	  else echo "OK: XMM 0"; fi; fi
	@FILES="$$(git ls-files '*.c' '*.h')"; if [ -n "$$FILES" ]; then \
	  clang-format --dry-run --Werror $$FILES && echo "OK: 포맷"; fi
	@SRC="$$(git ls-files '*.c')"; if [ -n "$$SRC" ]; then \
	  cppcheck --quiet --error-exitcode=1 --enable=warning,portability --inline-suppr \
	    --suppress=missingIncludeSystem -Iinclude $$SRC && echo "OK: cppcheck"; fi
	@SRC="$$(git ls-files '*.c')"; if [ -n "$$SRC" ]; then \
	  lizard -C 10 -L 60 -w $$SRC || echo "참고: 복잡도 경고 (실패 아님)"; fi

disasm: all
	$(OBJDUMP) -h $(BUILD)/kernel.elf
	$(OBJDUMP) -d -M intel -S $(BUILD)/kernel.elf > $(BUILD)/kernel.lst
	@echo "→ $(BUILD)/kernel.lst"

disk:
	@mkdir -p build
	dd if=/dev/zero of=$(DISK) bs=1048576 count=64

clean:
	rm -rf build build-test
