#include "utils.h"
#include "printf.h"
#include "entry.h"
#include "peripherals/irq.h"
#include "peripherals/aux.h"
#include "mini_uart.h"
#include "timer.h"

const char entry_error_messages[16][32] = {
    "SYNC_INVALID_EL1t", "IRQ_INVALID_EL1t", "FIQ_INVALID_EL1t", "ERROR_INVALID_EL1T",
    "SYNC_INVALID_EL1h", "IRQ_INVALID_EL1h", "FIQ_INVALID_EL1h", "ERROR_INVALID_EL1h",
    "SYNC_INVALID_EL0_64", "IRQ_INVALID_EL0_64", "FIQ_INVALID_EL0_64", "ERROR_INVALID_EL0_64",
    "SYNC_INVALID_EL0_32", "IRQ_INVALID_EL0_32", "FIQ_INVALID_EL0_32", "ERROR_INVALID_EL0_32"
};

void show_invalid_entry_message(u32 type, u64 esr, u64 address)
{
    if (type >= 16) {
        printf("FATAL: invalid exception type %d\n", type);
        return;
    }

    printf("ERROR: %s (%d) ESR=0x%08X%08X address=0x%08X%08X\n",
           (char *)entry_error_messages[type], type,
           (u32)(esr >> 32), (u32)esr,
           (u32)(address >> 32), (u32)address);
}

#if RPI_VERSION == 4
// BCM2711 routes VideoCore peripheral IRQs through the Arm GIC-400.
// Physical addresses from the BCM2711 peripheral documentation.
#define GICD_BASE       0xFF841000UL
#define GICC_BASE       0xFF842000UL
#define GICD_CTLR       (*(volatile u32 *)(GICD_BASE + 0x000))
#define GICD_ISENABLER(n) (*(volatile u32 *)(GICD_BASE + 0x100 + 4u * (n)))
#define GICD_ICENABLER(n) (*(volatile u32 *)(GICD_BASE + 0x180 + 4u * (n)))
#define GICD_ITARGETSR(id) (*(volatile u8 *)(GICD_BASE + 0x800 + (id)))
#define GICC_CTLR       (*(volatile u32 *)(GICC_BASE + 0x000))
#define GICC_PMR        (*(volatile u32 *)(GICC_BASE + 0x004))
#define GICC_IAR        (*(volatile u32 *)(GICC_BASE + 0x00C))
#define GICC_EOIR       (*(volatile u32 *)(GICC_BASE + 0x010))
#define GIC_SPURIOUS_ID 1023u
#define GIC_IRQ_AUX     125u  // VideoCore IRQ 29 + SPI base 96
#define GIC_IRQ_TIMER1  97u   // VideoCore system timer IRQ 1 + 96
#define GIC_IRQ_TIMER3  99u   // VideoCore system timer IRQ 3 + 96

static void gic_enable_spi(u32 id)
{
    GICD_ITARGETSR(id) = 1u; // route to CPU interface 0
    GICD_ISENABLER(id / 32u) = 1u << (id % 32u);
}



void enable_interrupt_controller(void)
{
    // Keep the controller disabled while configuring target and enable bits
    GICD_CTLR = 0;
    GICC_CTLR = 0;
    GICC_PMR = 0xFF;
    gic_enable_spi(GIC_IRQ_AUX);
    gic_enable_spi(GIC_IRQ_TIMER1);
    gic_enable_spi(GIC_IRQ_TIMER3);
    __asm__ volatile("dsb sy\n\tisb" ::: "memory");
    GICD_CTLR = 1;
    GICC_CTLR = 1;
    __asm__ volatile("dsb sy\n\tisb" ::: "memory");
}




static void dispatch_gic_irq(u32 id)
{
    switch (id) {
    case GIC_IRQ_AUX:
        // Drain RX FIFO
        while (REGS_AUX->mu_lsr & 1u) {
            uart_send(uart_recv());
        }
        break;
    case GIC_IRQ_TIMER1:
        handle_timer_1();
        break;
    case GIC_IRQ_TIMER3:
        handle_timer_3();
        break;
    default:
        // Disable unknown SPI sources to prevent an interrupt storm.
        if (id >= 32u && id < 1020u)
            GICD_ICENABLER(id / 32u) = 1u << (id % 32u);
        break;
    }
}

void handle_irq(void)
{
    for (;;) {
        u32 acknowledge = GICC_IAR;
        u32 id = acknowledge & 0x3FFu;
        if (id == GIC_SPURIOUS_ID)
            return;
        dispatch_gic_irq(id);
        // GIC requires the original acknowledge token for completion
        GICC_EOIR = acknowledge;
    }
}

#elif RPI_VERSION == 3
// BCM2837 legacy interrupt controller: pending_0 is basic pending,
// pending_1 and pending_2 are the two ordinary 32-bit banks.
void enable_interrupt_controller(void)
{
    REGS_IRQ->irq0_enable_0 = AUX_IRQ; // basic pending: AUX is bit 29
    REGS_IRQ->irq0_enable_1 = SYS_TIMER_IRQ_1 | SYS_TIMER_IRQ_3;
}

void handle_irq(void)
{
    u32 basic = REGS_IRQ->irq0_pending_0;
    u32 bank1 = REGS_IRQ->irq0_pending_1;

    if (basic & AUX_IRQ) {
        while (REGS_AUX->mu_lsr & 1u)
            uart_send(uart_recv());
    }
    if (bank1 & SYS_TIMER_IRQ_1)
        handle_timer_1();
    if (bank1 & SYS_TIMER_IRQ_3)
        handle_timer_3();

    // Unknown legacy IRQs are not spun on here. Add source-specific masking
    // and diagnostics when more devices are introduced.
}
#endif
