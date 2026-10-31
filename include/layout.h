/* myos/include/layout.h: 물리·가상 메모리 고정 배치 (Day 0에 고정)
 * 어셈블리에서도 쓰므로 #define 숫자만 둔다. Makefile이 build/layout.inc(%define)로 바꿔 준다.
 * 숫자를 바꾸면 C와 어셈블리가 함께 바뀐다.
 */
#ifndef MYOS_LAYOUT_H
#define MYOS_LAYOUT_H

/* 1MB 이하 물리 메모리 */
#define BDA_END 0x004FF   /* IVT·BDA: 건드리지 않음 */
#define EARLY_PML4 0x1000 /* W2 초기 페이지 테이블, 동적 페이징 후 회수 */
#define EARLY_PDPT 0x2000
#define EARLY_PD 0x3000       /* 0x3000~0x5FFF */
#define BOOT_STACK_TOP 0x7C00 /* 리얼·보호 모드 스택, 아래로 자람 */
#define MBR_ADDR 0x7C00
#define AP_TRAMPOLINE 0x8000 /* W21까지 비워 둠 */
#define E820_MAP 0x9000      /* 24B × 최대 170개 */
#define E820_MAX 170
#define KERNEL_LOAD 0x10000      /* 커널 플랫 바이너리 */
#define KERNEL_MAX_BYTES 0x70000 /* 448KB: 0x10000~0x7FFFF */
#define EARLY_KSTACK_TOP 0x90000
#define EBDA_START 0x9FC00
#define VGA_TEXT 0xB8000

/* 가상 주소 */
#define KERNEL_VMA 0xFFFFFFFF80000000
#define DIRECT_MAP 0xFFFF800000000000   /* W7: 물리 메모리 전체 */
#define VMALLOC_BASE 0xFFFF900000000000 /* W7: 커널 스택 등 */
#define USER_BASE 0x400000
#define USER_STACK_TOP 0x7FFFFFFFE000

/* MMIO */
#define LAPIC_PHYS 0xFEE00000
#define IOAPIC_PHYS 0xFEC00000

/* GDT 셀렉터: sysretq 호환 순서, STAR = (0x10 << 48) | (0x08 << 32) */
#define SEL_KCODE 0x08
#define SEL_KDATA 0x10
#define SEL_UDATA 0x18 /* RPL 3 → 0x1B */
#define SEL_UCODE 0x20 /* RPL 3 → 0x23 */
#define SEL_TSS 0x28

#endif
