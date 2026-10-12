.globl memzero
.type memzero, %function
memzero:
    //clear full words, then trailing bytes
1:
    cmp     x1, #8
    b.lo    2f
    str     xzr, [x0], #8
    sub     x1, x1, #8
    b       1b
2:
    cbz     x1, 3f
    strb    wzr, [x0], #1
    sub     x1, x1, #1
    b       2b
3:
    ret
.size memzero, .-memzero
