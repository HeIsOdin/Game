    .set noreorder
    .section .text.start, "ax", @progbits
    .globl _start
    .ent _start
_start:
    lui   $sp, 0x8040
    addiu $sp, $sp, -16

    jal   game_main
    nop

1:
    b     1b
    nop
    .end _start
