/* myos/linker.ld: plan/tech-fixes.md #3
 * .boot   : 페이징 전에 실행되는 16/32/64비트 초기 코드. VMA = LMA = 물리 주소 0x10000
 * 나머지  : higher-half(0xFFFFFFFF80000000 + 물리 주소)에 링크, LMA는 물리 주소
 * .boot 안의 32비트 코드는 higher-half 심볼을 (sym - KERNEL_VMA)로만 쓴다.
 */
ENTRY(_start32)
KERNEL_VMA = 0xFFFFFFFF80000000;

SECTIONS
{
    . = 0x10000;
    .boot : { KEEP(*(.boot)) }

    . += KERNEL_VMA;
    .text   : AT(ADDR(.text)   - KERNEL_VMA) { *(.text .text.*) }
    .rodata : AT(ADDR(.rodata) - KERNEL_VMA) { *(.rodata .rodata.*) }
    .data   : AT(ADDR(.data)   - KERNEL_VMA) { *(.data .data.*) }
    /* W16: exception table을 여기에 직접 추가한다 (예: __ex_table 섹션과 시작·끝 심볼) */
    .bss    : AT(ADDR(.bss)    - KERNEL_VMA) {
        _bss_start = .;
        *(.bss .bss.*) *(COMMON)
        _bss_end = .;
    }
    _kernel_end = .;

    /DISCARD/ : { *(.eh_frame) *(.comment) *(.note*) }
}
