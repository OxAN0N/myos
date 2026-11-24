# myos/.gdbinit: gmake debug 후 다른 터미널에서 gmake gdb
# (GDB는 보안상 이 파일을 자동으로 읽지 않는다. setup.sh가 ~/.gdbinit에 허용 줄을 넣는다)
set disassembly-flavor intel
set pagination off
target remote :1234

## W1 리얼 모드: GDB 안에서 직접 친다
#   b *0x7c00
# 16비트 명령 보기: GDB x/i는 64비트 규칙으로 풀어서 틀린다. QEMU에 맡긴다
#   monitor x /4i $pc
# (set architecture i8086은 GDB 18.1 + QEMU 11.1.3에서 거부됨)

# W3부터 주석을 풀면 kmain 같은 심볼과 소스 줄 단위 next/step이 된다
# symbol-file build/kernel.elf
