ENTRY(_start)

SECTIONS
{
  . = 0x80001000;

  .text : {
    *(.text*)
    *(.rodata*)
  }

  .data : {
    *(.data*)
  }

  .bss (NOLOAD) : {
    *(.bss*)
    *(COMMON)
  }
}
