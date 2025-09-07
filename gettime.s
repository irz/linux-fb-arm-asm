/* -------------------------------------------------------------------
 * Using clock_gettime() from ARMv7-A assembly
 * ------------------------------------------------------------------*/

.syntax unified
.text
.global _start

_start:
        /* Reserve space on stack for 2 timespec structs */
        sub     sp, sp, #16         @ 2 * sizeof(timespec)
        mov     r4, sp              @ start timespec
        add     r5, r4, #8          @ end timespec

        /* clock_gettime(CLOCK_MONOTONIC, &start) */
        mov     r7, #263
        mov     r0, #1
        mov     r1, r4
        svc     #0

        /*
         * Code to profile goes here: |
         * <--------------------------/
         */

        /* clock_gettime(CLOCK_MONOTONIC, &end) */
        mov     r7, #263
        mov     r0, #1
        mov     r1, r5
        svc     #0

        /* Compute delta_ns */
        ldr     r0, [r4]        @ start sec
        ldr     r1, [r4, #4]    @ start nsec
        ldr     r2, [r5]        @ end sec
        ldr     r3, [r5, #4]    @ end nsec

        sub     r2, r2, r0
        sub     r3, r3, r1

        /* Convert sec_diff to nanoseconds */
        ldr     r0, =1000000000
        mul     r2, r2, r0      
        add     r0, r2, r3      @ r0 = total ns

        /* Convert nsec to ASCII string */
        ldr     r1, =buf+20     @ write digits backward
        mov     r2, #0
        mov     r6, #10
itoa_loop:
        movw    r3, #26215
        movt    r3, 26214       @ reciprocal, for r0/10
        smull   r9, r3, r3, r0
        asrs    r9, r3, #2
        asrs    r3, r0, #31
        subs    r4, r9, r3
        mls     r5, r4, r6, r0  @ r5 = r0 - r4*10
        add     r5, r5, #'0'    @ convert to ASCII
        strb    r5, [r1, #-1]!  @ store to timebuf
        mov     r0, r4
        cmp     r0, #0
        bne     itoa_loop

        /* Write the ASCII string */
        ldr     r2, =buf+20
        sub     r2, r2, r1      @ length

        mov     r7, #4          @ write timebuf
        mov     r0, #1
        mov     r3, r2
        svc     #0

        ldr     r1, =newline
        mov     r2, #1
        mov     r7, #4          @ write newline
        mov     r0, #1
        svc     #0

        mov     r7, #1          @ exit(0)
        mov     r0, #0
        svc     #0

        .data
buf:    .space 20
newline:.ascii "\n"
