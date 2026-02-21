ENTRY(_start)

SECTIONS
{
  . = 0x80000400;

  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
  }

  .data : {
    *(.data*)
    *(.sdata*)
    *(.got*)
  }

  .bss (NOLOAD) : {
    *(.bss*)
    *(.sbss*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.MIPS.abiflags)
    *(.MIPS.options)
    *(.pdr)
    *(.mdebug*)
    *(.comment)
    *(.note*)
    *(.eh_frame*)
  }
}
