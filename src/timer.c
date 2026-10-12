#include "printf.h"
#include "peripherals/timer.h"
#include "peripherals/irq.h"
#include "peripherals/aux.h"

const u32 interval_1 = CLOCKHZ;
u32 cur_val_1 = 0;

const u32 interval_3 = CLOCKHZ / 4;
u32 cur_val_3 = 0;

static void schedule_next_compare(unsigned int channel, u32 *deadline, u32 interval)
{
    u32 now = REGS_TIMER->counter_lo;

    // catch up if the handler was delayed
    do {
        *deadline += interval;
    } while ((s32)(*deadline - now) <= 0);

    REGS_TIMER->compare[channel] = *deadline;
    REGS_TIMER->control_status = (1u << channel);
}

void timer_init(void)
{
    cur_val_1 = REGS_TIMER->counter_lo + interval_1;
    REGS_TIMER->compare[1] = cur_val_1;
    cur_val_3 = REGS_TIMER->counter_lo + interval_3;
    REGS_TIMER->compare[3] = cur_val_3;
    // clear stale match flags before unmasking the cpu interrupt.
    REGS_TIMER->control_status = (1u << 1) | (1u << 3);
}

void handle_timer_1() {
    schedule_next_compare(1, &cur_val_1, interval_1);
}

void handle_timer_3() {
    schedule_next_compare(3, &cur_val_3, interval_3);
}

u64 timer_get_ticks(void)
{
    u32 hi_before, lo, hi_after;
    do {
        hi_before = REGS_TIMER->counter_hi;
        lo = REGS_TIMER->counter_lo;
        hi_after = REGS_TIMER->counter_hi;
    } while (hi_before != hi_after);

    return ((u64)hi_after << 32) | lo;
}

// sleep in milliseconds
// scheduler sleep comes later
void timer_sleep(u32 ms)
{
    const u64 duration_us = (u64)ms * 1000ULL;
    const u64 start = timer_get_ticks();
    while ((timer_get_ticks() - start) < duration_us) {
        __asm__ volatile("yield" ::: "memory");
    }
}
