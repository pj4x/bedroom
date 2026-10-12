#include "mm.h"
#include "sysregs.h"

.section ".text.boot"

.globl _start
_start:
    mrs x0, mpidr_el1
    and x0, x0, #0xFF
    cbz x0, master
    b proc_hang

master:
    // setup GIC
    // GICv2 distributor: 0xFF841000
    ldr x1, =0xFF841000

    // Configure AUX (125), system timer 1 (97),
    // and system timer 3 (99) as Group 1 interrupts
    ldr w2, [x1, #0x08C]      // GICD_IGROUPR3
    movz w3, #0x000A
    movk w3, #0x2000, lsl #16 // bits 1, 3, 29
    orr  w2, w2, w3
    str  w2, [x1, #0x08C]

    // Route the three SPIs to CPU interface 0
    mov  w2, #1
    strb w2, [x1, #0x861]     // ITARGETSR[97]
    strb w2, [x1, #0x863]     // ITARGETSR[99]
    strb w2, [x1, #0x87D]     // ITARGETSR[125]

    // Set priorities to a normal, nonzero priority
    mov  w2, #0x80
    strb w2, [x1, #0x461]     // IPRIORITYR[97]
    strb w2, [x1, #0x463]     // IPRIORITYR[99]
    strb w2, [x1, #0x47D]     // IPRIORITYR[125]

    // GICv2 CPU interface: 0xFF842000
    ldr x4, =0xFF842000

    // Allow all interrupt priorities through the PMR
    mov  w2, #0xFF
    str  w2, [x4, #0x04]      // GICC_PMR

    dsb sy

    // Enable Group 1 at the distributor and CPU interface
    mov  w2, #2
    str  w2, [x1, #0x00]      // GICD_CTLR
    str  w2, [x4, #0x00]      // GICC_CTLR

    dsb sy
    isb


    // go to el1
    ldr x0, =SCTLR_VALUE_MMU_DISABLED
    msr sctlr_el1, x0

    ldr x0, =HCR_VALUE
    msr hcr_el2, x0

    ldr x0, =SCR_VALUE
    msr scr_el3, x0

    ldr x0, =SPSR_VALUE
    msr spsr_el3, x0

    adr x0, el1_entry
    msr elr_el3, x0

    eret

el1_entry:
    adr x0, bss_begin
    adr x1, bss_end
    sub x1, x1, x0
    bl memzero

    mov sp, #LOW_MEMORY
    bl kernel_main
    b  proc_hang

proc_hang:
    wfe
    b proc_hang
