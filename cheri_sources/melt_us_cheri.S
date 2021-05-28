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
Meltdown-US-CHERI

The goal of the attack is to read memory out-of-bounds
while using capabilities. This tests whether a CHERI microarchitecture
checks in the correct place in the pipeline. If
the implementation did not do so, the transient instruction sequence
following the faulting load could leak the secret value.

Similar attacks could be conducted for capability
permissions, etc.

steps:

1. load from a capability with the address being out-of-bounds
2. perform a load dependent on the previous load
*/

start:

  // set pcc flags such that capability encoding
  // mode is used
  // This is described in the CHERI Specification v7
  // in Section 5.3.6 
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

melt_us_cheri:

  // set up trap_handler
  cllc ct2, trap_handler
  cspecialw mtcc, ct2

  // prepare hardware performance monitoring
  // do counting of load request sent by the CPU
  HPM_SELECT_EVENT(3, 0x30)
  // read value of counter 3 and store it to s10
  HPM_M_READ_X (s10, 3)


#ifdef VCU_118
  // cs0 is a capability to [0xc0001000 - 0xc0001080]
  li  t2, 0xc0001000
  cfromptr cs0, ddc, t2
  li t1, 0x80
  csetbounds cs0, cs0, t1

  // cs1 is a capability to [0xc0001200 - 0xc0002200]
  li  t2, 0xc0001200
  cfromptr cs1, ddc, t2
  li t1, 0x1000
  csetbounds cs1, cs1, t1
  // store value
  // will be in L1 cache
  li t1, 0x400
  csd t1, 0(cs1)

  // cs2 is a capability to [0xc0003000 - 0xc0004000]
  li  t2, 0xc0003000
  cfromptr cs2, ddc, t2
  li t1, 0x1000
  csetbounds cs2, cs2, t1
#else
  // cs0 is a capability to [0x80001000 - 0x80001080]
  li  t2, 0x80001000
  cfromptr cs0, ddc, t2
  li t1, 0x80
  csetbounds cs0, cs0, t1

  // cs1 is a capability to [0x80001200 - 0x80002200]
  li  t2, 0x80001200
  cfromptr cs1, ddc, t2
  li t1, 0x1000
  csetbounds cs1, cs1, t1
  // store value
  // will be in L1 cache
  li t1, 0x400
  csd t1, 0(cs1)

  // cs2 is a capability to [0x80003000 - 0x80004000]
  li  t2, 0x80003000
  cfromptr cs2, ddc, t2
  li t1, 0x1000
  csetbounds cs2, cs2, t1
#endif

  // set offset for cache miss later
  li t1, 0x800
  cincoffset cs1, cs1, t1

attack_funct:
  // capability is in cs0
  // bounds are [mem, mem + 16*8[

  // set cs0 offset out of bounds
  // we want to access a value in the memory
  // region of cs1
  cincoffsetimm cs0, cs0, 512

  // load will miss all caches
  // this will delay the exception being raised
  cld t3, 0(cs1)

  // load out of bounds
  cld t2, 0(cs0)
  // load again from other capability with offset
  // in order to make the secret visible
  cincoffset cs2, cs2, t2
  cld t2, 0(cs2)

  .rept 0x1f
  nop
  .endr

trap_handler:
  HPM_M_READ_X (s11, 3)

  // we expect 3 loads to have happened
  // one architectural load in attack_funct
  // two transient loads in attack_funct, where
  // the latter one leaks the secret
  HPM_CAP_TEST(s10, s11, 3)

.section .tohost , "adw"

tohost:
  .dword 0x0000000000000000
