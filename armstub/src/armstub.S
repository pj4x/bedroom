
.globl _start
_start:
    // Initialize the GIC before entering the kernel.
    ldr x0, =gic_init
    br  x0

.ltorg

.org 0xf0
.globl stub_magic
stub_magic:
    .word 0x5afe570b

.org 0xf4
.globl stub_version
stub_version:
    .word 0

.org 0xfc
.globl kernel_entry32
kernel_entry32:
    .word 0x0

// Keep executable code after the fixed stub header.
.org 0x100

gic_init:
    // GICv2 distributor: 0xFF841000
    ldr x1, =0xFF841000

    // Configure AUX (125), system timer 1 (97),
    // and system timer 3 (99) as Group 1 interrupts.
    ldr w2, [x1, #0x08C]      // GICD_IGROUPR3
    movz w3, #0x000A
    movk w3, #0x2000, lsl #16 // bits 1, 3, 29
    orr  w2, w2, w3
    str  w2, [x1, #0x08C]

    // Route the three SPIs to CPU interface 0.
    mov  w2, #1
    strb w2, [x1, #0x861]     // ITARGETSR[97]
    strb w2, [x1, #0x863]     // ITARGETSR[99]
    strb w2, [x1, #0x87D]     // ITARGETSR[125]

    // Set priorities to a normal, nonzero priority.
    mov  w2, #0x80
    strb w2, [x1, #0x461]     // IPRIORITYR[97]
    strb w2, [x1, #0x463]     // IPRIORITYR[99]
    strb w2, [x1, #0x47D]     // IPRIORITYR[125]

    // GICv2 CPU interface: 0xFF842000
    ldr x4, =0xFF842000

    // Allow all interrupt priorities through the PMR.
    mov  w2, #0xFF
    str  w2, [x4, #0x04]      // GICC_PMR

    dsb sy

    // Enable Group 1 at the distributor and CPU interface.
    mov  w2, #2
    str  w2, [x1, #0x00]      // GICD_CTLR
    str  w2, [x4, #0x00]      // GICC_CTLR

    dsb sy
    isb

    // Continue to the kernel entry patched by the build process.
    ldr w0, kernel_entry32
    br  x0
