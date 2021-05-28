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
Spectre-PHT

It trains the history of a branch predictor such
that two loads are executed speculatively even
if the branch should not have been taken. This
is the Pattern History Table(PHT) variant of
Spectre, also known as Spectre v1.

1st load: 0x0000000080020100
2nd load: 0x0000000080001280
*/


spec:

  // call spec_funct 16 times in order to train the
  // branch predictor. Loop unrolled by hand to
  // avoid branch prediction on this loop
  
  addi a0, x0, 0x0
  jal ra, spec_funct
  addi a0, x0, 0x1
  jal ra, spec_funct
  addi a0, x0, 0x2
  jal ra, spec_funct
  addi a0, x0, 0x3
  jal ra, spec_funct
  addi a0, x0, 0x4
  jal ra, spec_funct
  addi a0, x0, 0x5
  jal ra, spec_funct
  addi a0, x0, 0x6
  jal ra, spec_funct
  addi a0, x0, 0x7
  jal ra, spec_funct
  addi a0, x0, 0x8
  jal ra, spec_funct
  addi a0, x0, 0x9
  jal ra, spec_funct
  addi a0, x0, 0xa
  jal ra, spec_funct
  addi a0, x0, 0xb
  jal ra, spec_funct
  addi a0, x0, 0xc
  jal ra, spec_funct
  addi a0, x0, 0xd
  jal ra, spec_funct
  addi a0, x0, 0xe
  jal ra, spec_funct
  addi a0, x0, 0xf
  jal ra, spec_funct

  // flush cache in order to evict
  // value loaded for comparison
  jal ra, flush

  // fetch cache line of data to
  // be accessed speculatively into L1 cache
  lla t4, arr
  addi t4, t4, 256
  ld t4, 0(t4)

  // this load needs to be finished
  // before continuing
  fence rw, rw

  // prepare hardware performance monitoring
  // do counting of load request sent by the CPU
  HPM_SELECT_EVENT(3, 0x30)
  // read value of counter 3 and store it to s10
  HPM_M_READ_X (s10, 3)

  // calls with parameters that will lead to
  // speculative execution
  addi a0, x0, 0x20
  jal ra, spec_funct

  HPM_M_READ_X (s11, 3)


probe:

#ifdef VCU_118
  li t2, 0xc0001000
  li t6, 0xc0005000
#else
  li t2, 0x80001000
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

  // we expect 3 loads to have happened
  // one architectural load in spec_funct
  // two transient loads in spec_funct with the
  // latter one leaking the secret
  HPM_TEST(s10, s11, 3)

idle_funct:
  add t4, x0, x0
  beq t4, x0, idle_funct

  .rept 0x20
  nop
  .endr


flush:
  // flushes 8 KiB of the cache
  lla t0, arr
  li t1, 8192
  add t0, t0, t1
  add t1, t0, t1

flush_loop:
  ld t2, 0(t0)
  addi t0, t0, 64
  blt t0, t1, flush_loop
  jalr x0, ra


spec_funct:
  // function will speculatively execute memory loads
  // the first load will return an address
  // the second load will return the value at
  // the aforementioned address
  // expects index parameter in a0

  lla t0, cmp_val
  slli t1, a0, 3
  lla t2, arr
  add t2, t2, t1
  ld t0, 0(t0)
  bge a0, t0, spec_funct_end
  ld t2, 0(t2)
  // use speculative execution
  // access address directly
  ld t3, 0(t2)
spec_funct_end:
  jalr x0, 0(ra)




.data


arr:

#ifdef VCU_118
  // cache line 0 and 1
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
  .dword 0x00000000c0001200
#else
  // cache line 0 and 1
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
  .dword 0x0000000080001200
#endif

  // other data (16 * 8 bytes) used as buffer
  // cache line 2 and 3
  .dword 0xfffffffffffffff0
  .dword 0xfffffffffffffff1
  .dword 0xfffffffffffffff2
  .dword 0xfffffffffffffff3
  .dword 0xfffffffffffffff4
  .dword 0xfffffffffffffff5
  .dword 0xfffffffffffffff6
  .dword 0xfffffffffffffff7
  .dword 0xfffffffffffffff8
  .dword 0xfffffffffffffff9
  .dword 0xfffffffffffffffa
  .dword 0xfffffffffffffffb
  .dword 0xfffffffffffffffc
  .dword 0xfffffffffffffffd
  .dword 0xfffffffffffffffe
  .dword 0xffffffffffffffff

#ifdef VCU_118
  // to be accessed speculatively
  // cache line 4 and 5
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
  .dword 0x00000000c0001280
#else
  // to be accessed speculatively
  // cache line 4 and 5
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
  .dword 0x0000000080001280
#endif

cmp_val:
  // cache line 6 and 7
  .dword 0x0000000000000010
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

attack_arr:
  // cache line 8 and 9
  .dword 0xffffffff00000000
  .dword 0xffffffff00000001
  .dword 0xffffffff00000002
  .dword 0xffffffff00000003
  .dword 0xffffffff00000004
  .dword 0xffffffff00000005
  .dword 0xffffffff00000006
  .dword 0xffffffff00000007
  .dword 0xffffffff00000008
  .dword 0xffffffff00000009
  .dword 0xffffffff0000000a
  .dword 0xffffffff0000000b
  .dword 0xffffffff0000000c
  .dword 0xffffffff0000000d
  .dword 0xffffffff0000000e
  .dword 0xffffffff0000000f

  // cache line 10 and 11
  .dword 0xffffffff00000010
  .dword 0xffffffff00000011
  .dword 0xffffffff00000012
  .dword 0xffffffff00000013
  .dword 0xffffffff00000014
  .dword 0xffffffff00000015
  .dword 0xffffffff00000016
  .dword 0xffffffff00000017
  .dword 0xffffffff00000018
  .dword 0xffffffff00000019
  .dword 0xffffffff0000001a
  .dword 0xffffffff0000001b
  .dword 0xffffffff0000001c
  .dword 0xffffffff0000001d
  .dword 0xffffffff0000001e
  .dword 0xffffffff0000001f

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000

