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
Meltdown-GP

This variant of Meltdown attempts to transiently read out the
content of an arbitrary M privilege mode register, which is
mcause in this example.

steps:
1. change to U mode
2. execute faulting instruction there
3. see whether it is successful
*/

melt_gp:
    jal ra, init_hpm

init_hpm:
    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // enable reading from S mode
    HPM_M_ENABLE_X(3)
    HPM_S_ENABLE_X(3)

init_trap_vector:
    // all traps will end up in the pc
    // being set to trap_handler
    lla t0, trap_handler
    csrw mtvec, t0


change_to_U:
    // check that it works in M mode
    csrr t0, mcause

    // set MPP such that we return to U mode
    li t1, 0x00001800
    csrc mstatus, t1
    // load valid pc into mepc such that we
    // return there
    lla t2, access_m_reg
    csrw mepc, t2
    // return to user mode
    // which is a jump to access_m_reg
    mret

// align on PC divisible by four
.align 4

trap_handler:
    // read value of counter 3 and store it to s11
    HPM_M_READ_X (s11, 3)

    // if successful, we expect 1 load to have happened
    // 1 transient load in access_m_reg that leaks the
    // value in mcause
    HPM_TEST(s10, s11, 1)

    nop
    nop
    nop
    nop
    nop
    nop	

access_m_reg:
    // read value of counter 3 and store it to s10
    HPM_SU_READ_X (s10, 3)

    // execute a load with this address
    lla t0, mem
    csrr t1, mcause
    // multiply by 64 in order to get a
    // different cache line for each value
    slli t1, t1, 6
    add t1, t0, t1
    ld t1, 0(t1)

.data

mem:
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
  .dword 0x0000000000000000

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
