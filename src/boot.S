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
#if RPI_VERSION == 4
    // GICv2: disable the Secure views before configuring Group assignment.
    ldr x1, =0xFF841000      // GICD
    ldr x4, =0xFF842000      // GICC

    mov w2, #0
    str w2, [x1, #0x00]      // GICD_CTLR
    str w2, [x4, #0x00]      // GICC_CTLR
    dsb sy

    // Assign AUX (125), system timer 1 (97), timer 3 (99)
    // to Group 1 Non-secure.
    ldr w2, [x1, #0x08C]      // GICD_IGROUPR3
    movz w3, #0x000A
    movk w3, #0x2000, lsl #16
    orr w2, w2, w3
    str w2, [x1, #0x08C]

    dsb sy
    isb
#endif


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
