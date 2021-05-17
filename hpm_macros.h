#ifndef __HPM_MACROS_H
#define __HPM_MACROS_H

/*
Macros for HPM support
Author: Franz Fuchs
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
