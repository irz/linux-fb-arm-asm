/* -------------------------------------------------------------------
 * Mandelbrot set renderer using ARM Neon
 * ------------------------------------------------------------------*/

.syntax unified
.text
.global _start

.equ    WIDTH_PX, 1280
.equ    HEIGHT_PX, 800
.equ    MAX_ITER, 200

/* Precomputed reciprocal scale factors */
wrecf:  .single 0.00078125    @ 1 / WIDTH_PX
hrecf:  .single 0.00125       @ 1 / HEIGHT_PX

/* -------------------------------------------------------------------
 * This entry point will need to be passed into linker
 * ------------------------------------------------------------------*/
_start:
        bl open_fb              @ open /dev/fb0, fd in r0 on success
        cmp r0, #0
        bmi exit1               @ exit(1) if open() failed
        mov r6, r0              @ save fb0 fd

        /* Reserve space on stack for 2 timespec structs */
        sub     sp, sp, #16     @ 2 * sizeof(timespec)
        mov     r10, sp         @ start timespec
        add     r11, r10, #8    @ end timespec

        /* clock_gettime(CLOCK_MONOTONIC, &start) */
        mov     r7, #263
        mov     r0, #1
        mov     r1, r10
        svc     #0

        /* Begin computation */
        vmov.f32 s0, #-2.0      @ xmin
        vmov.f32 s1, #1.0       @ xmax
        vmov.f32 s2, #-1.0      @ ymin
        vmov.f32 s3, #1.0       @ ymax

        vsub.f32 s4, s1, s0
        vldr.f32 s5, wrecf
        vmul.f32 s4, s4, s5     @ xmul

        vsub.f32 s5, s3, s2
        vldr.f32 s6, hrecf
        vmul.f32 s5, s5, s6     @ ymul

        mov r5, #MAX_ITER
        vdup.u32 q14, r5        @ MAX_ITER
        vmov.f32 q3, #4.0
        vmov.f32 q10, #2.0
        vmov.u32 q15, #1
        mov r5, #0              @ y = 0
y_loop:
        cmp r5, HEIGHT_PX
        bge write_buf

        /* compute cim */
        vmov.f32 s6, r5
        vcvt.f32.u32 s6, s6
        vmul.f32 s6, s6, s5
        vadd.f32 s6, s6, s2
        vdup.f32 q2, d3[0]      @ cim vector

        ldr r8, =xinit
        vldm r8, {q4}
        mov r4, #0              @ x = 0
x_loop:
        cmp r4, WIDTH_PX
        bge x_end

        /* compute cr vector */
        vmul.f32 q5, q4, d2[0]
        vdup.f32 q6, d0[0]
        vadd.f32 q5, q5, q6     @ cr vector

        /* set zr, zim = 0 */
        veor.f32 q6, q6, q6     @ zr vector
        veor.f32 q7, q7, q7     @ zim vector
        veor.u32 q11, q11, q11  @ iterations = 0
loop:
        vmul.f32 q8, q6, q6     @ zr^2
        vmul.f32 q9, q7, q7     @ zim^2

        vadd.f32 q12, q8, q9
        vclt.f32 q12, q12, q3   @ check zr^2 + zim^2 < 4
        vclt.u32 q13, q11, q14  @ check iterations < MAX_ITER

        vand q12, q13, q12      @ mask of active lanes

        vorr d26, d24, d25
        vpmax.u32 d26, d26, d26
        vmov r9, d26[0]         @ extract masked lanes
        cmp r9, #0
        beq loop_done           @ continue if any lanes remain

        vmul.f32 q7, q6, q7
        vmul.f32 q7, q7, q10
        vadd.f32 q7, q7, q2     @ update zim

        vsub.f32 q6, q8, q9
        vadd.f32 q6, q6, q5     @ update zr

        vand q12, q15, q12
        vadd.u32 q11, q11, q12  @ increment iterations by mask

        b loop
loop_done:
        vshr.u32 q12, q11, #6
        vadd.u32 q12, q12, q15
        vmov.u32 q13, #5
        vmul.u32 q12, q13, q12
        vshl.u32 q11, q11, q12  @ iterations vector

        vmovn.u32 d24, q11
        bl set_pixvec           @ store iter vector to memory

        vadd.f32 q4, q4, q3     @ update x vector
        add r4, r4, #4
        b x_loop
x_end:
        add r5, r5, #1
        b y_loop

/* -------------------------------------------------------------------
 * Write final buffer to framebuffer with pwrite64(fd, buf, count, pos)
 * ------------------------------------------------------------------*/
write_buf:
        /* clock_gettime(CLOCK_MONOTONIC, &end) */
        mov     r7, #263
        mov     r0, #1
        mov     r1, r11
        svc     #0

        mov r0, r6
        ldr r1, =buf
        mov r2, WIDTH_PX * HEIGHT_PX * 2
        mov r3, #0
        mov r4, #0
        mov r5, #0
        mov r7, #0xB5           @ pwrite64()
        svc #0

print_time:
        /* Compute delta */
        ldr     r0, [r10]       @ start sec
        ldr     r1, [r10, #4]   @ start nsec
        ldr     r2, [r11]       @ end sec
        ldr     r3, [r11, #4]   @ end nsec
        sub     r2, r2, r0      @ sec_diff
        sub     r3, r3, r1      @ nsec_diff

        ldr     r0, =1000000000
        mul     r2, r2, r0
        add     r0, r2, r3      @ r0 = total ns

        /* Convert nsec to ASCII string */
        ldr     r1, =timebuf+20
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
        ldr     r2, =timebuf+20
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

        b exit0

/* -------------------------------------------------------------------
 * store pixel vector [xN, xN+1, xN+2, xN+3] to memory
 * ------------------------------------------------------------------*/
set_pixvec:
        push {r4-r6}
        ldr r0, =buf
        mov r6, WIDTH_PX
        mla r5, r5, r6, r4
        lsl r4, r5, #1
        add r0, r0, r4
        vst1.16 {d24}, [r0]   @ store neon 64-bit vector as 16-bit shorts
        pop {r4-r6}
        bx lr

open_fb:
        ldr r0, =fbdev
        mov r1, #2             @ O_RDWR
        mov r7, #5             @ open()
        svc #0
        bx lr

close_fb:
        mov r7, #6             @ close()
        svc #0
        bx lr

exit1:
        bl close_fb
        mov r0, #1
        mov r7, #1             @ exit(1)
        svc #0

exit0:
        bl close_fb
        mov r0, #0
        mov r7, #1             @ exit(0)
        svc #0

.data
.align 16
xinit:   .single 0.0, 1.0, 2.0, 3.0 @ important to align this to 128-bit

buf:     .space WIDTH_PX * HEIGHT_PX * 2
timebuf: .space 20
newline: .ascii "\n"
fbdev:   .asciz "/dev/fb0"
.end
