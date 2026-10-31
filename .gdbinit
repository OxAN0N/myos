# myos/.gdbinit: gmake debug 후 다른 터미널에서 gmake gdb
# (GDB는 보안상 이 파일을 자동으로 읽지 않는다. setup.sh가 ~/.gdbinit에 허용 줄을 넣는다)
set disassembly-flavor intel
set pagination off
target remote :1234

# W1 리얼 모드: 아래 두 줄을 GDB 안에서 직접 친다
#   set architecture i8086
#   b *0x7c00
# 보호·롱 모드로 넘어간 뒤: set architecture i386:x86-64

# W3부터 주석을 풀면 kmain 같은 심볼과 소스 줄 단위 next/step이 된다
# symbol-file build/kernel.elf
