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

#ifndef __HPM_MACROS_H
#define __HPM_MACROS_H

/*
Macros for HPM support
*/

// selects event eventnum to be counted in
// counter with number counternum
// changes register t0!
#define HPM_SELECT_EVENT( counternum, eventnum ) \
hpm_select_event_ ## counternum: \
    li  t0, eventnum; \
    csrw mhpmevent ## counternum, t0;

// uninhibits counter with number counternum
// changes register t0
#define HPM_M_UN_INHIBIT_X( counternum ) \
hpm_m_uninhibit_ ## counternum: \
    li  t0, 1 << counternum; \
    csrc mcountinhibit, t0;


// inhibits counter with number counternum
// changes register t0
#define HPM_M_INHIBIT_X( counternum ) \
hpm_m_inhibit_ ## counternum: \
    li  t0, 1 << counternum; \
    csrs mcountinhibit, t0;


// enables counting of counter with number counternum from M to S mode
// changes register t0
#define HPM_M_ENABLE_X( counternum ) \
hpm_m_enable_ ## counternum: \
    li  t0, 1 << counternum; \
    csrs mcounteren, t0;

// enables counting of counter with number counternum from S to U mode
// changes register t0
#define HPM_S_ENABLE_X( counternum ) \
hpm_s_enable_ ## counternum: \
    li  t0, 1 << counternum; \
    csrs scounteren, t0;

// read counter with counternum into register reg when in M mode
#define HPM_M_READ_X( reg, counternum ) \
csrr  reg , mhpmcounter ## counternum;

// read counter with counternum into register reg when in S or U mode
#define HPM_SU_READ_X( reg, counternum ) \
csrr  reg , hpmcounter ## counternum;

// pass or fail the test
// reg_prev: regiser holding the counter value before
// the attack
// reg_past: regiser holding the counter value after
// the attack
// threshold: threshold value for the test to be successful
// changes registers t0, t1, and t2
#define HPM_TEST( reg_prev, reg_past, threshold) \
hpm_test: \
    sub t0, reg_past, reg_prev; \
    li t1, threshold; \
    lla t2, tohost; \
    blt t0, t1, hpm_test_fail; \
hpm_test_pass: \
    li t0, 1; \
    sd t0, 0(t2); \
hpm_test_fail: \
    li t0, 2; \
    sd t0, 0(t2);

// pass or fail the test capability variant
// reg_prev: regiser holding the counter value before
// the attack
// reg_past: regiser holding the counter value after
// the attack
// threshold: threshold value for the test to be successful
// changes registers t0, t1, and ct2
#define HPM_CAP_TEST( reg_prev, reg_past, threshold) \
hpm_test: \
    sub t0, reg_past, reg_prev; \
    li t1, threshold; \
    cllc ct2, tohost; \
    blt t0, t1, hpm_test_fail; \
hpm_test_pass: \
    li t0, 1; \
    csd t0, 0(ct2); \
hpm_test_fail: \
    li t0, 2; \
    csd t0, 0(ct2);


#endif
