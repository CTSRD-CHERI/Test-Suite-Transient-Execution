/*
This is taken from:
https://github.com/riscv/riscv-test-env/tree/68cad7baf3ed0a4553fffd14726d24519ee1296a/p
*/

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .text : { *(.text) }
  . = ALIGN(0x1000);
  .melt_data : { *(.melt_data) }
  . = ALIGN(0x1000);
  .table1 : { *(.table1) }
  . = ALIGN(0x1000);
  .table2 : { *(.table2) }
  . = ALIGN(0x1000);
  .melt_utext : { *(.melt_utext) }
  . = ALIGN(0x1000);
  .melt_udata : { *(.melt_udata) }
  . = ALIGN(0x20000);
  .acode : { *(.acode) }
  . = ALIGN(0x1000);
  .data : { *(.data) }
  . = ALIGN(0x4000000);
  .spec_btb_attack : { *(.spec_btb_attack) }
  . = ALIGN(0x1000);
  .utext : { *(.utext) }
  . = ALIGN(0x1000);
  .udata : { *(.udata) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  _end = .;
}

