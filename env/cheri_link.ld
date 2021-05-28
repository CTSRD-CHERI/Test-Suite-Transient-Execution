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
  . = ALIGN(0x200);
  .spec_btb_cheri_s : { *(.spec_btb_cheri_s) }
  . = ALIGN(0x20000);
  .kernel : { *(.kernel) }
  . = ALIGN(0x8000000);
  .spec_btb_cheri_u : { *(.spec_btb_cheri_u) }
  . = ALIGN(0x40000);
  .user : { *(.user) }
  . = ALIGN(0x20000);
  .acode : { *(.acode) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .data : { *(.data) }
  _end = .;
}

