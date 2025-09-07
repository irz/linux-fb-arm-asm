/* -------------------------------------------------------------------
 * Mandelbrot set renderer in ARM AArch32 assembly
 * ------------------------------------------------------------------*/

.syntax unified
.text
.global _start

.equ    WIDTH_PX,   1280
.equ    HEIGHT_PX,   800
.equ    MAX_ITER,    200

/* Precomputed reciprocal scale factors */
wrecf:  .single 0.00078125          @ 1 / WIDTH_PX
hrecf:  .single 0.00125             @ 1 / HEIGHT_PX

/* -------------------------------------------------------------------
 * This entry point will need to be passed into linker
 * ------------------------------------------------------------------*/
_start:
        bl open_fb                  @ open("/dev/fb0", O_RDWR)
        cmp r0, #0
        bmi exit1                   @ If open() failed exit with 1
        mov r6, r0                  @ Save framebuffer file descriptor

        vmov.f32 s0, #-2.0          @ xmin
        vmov.f32 s1, #1.0           @ xmax
        vmov.f32 s2, #-1.0          @ ymin
        vmov.f32 s3, #1.0           @ ymax

        vsub.f32 s4, s1, s0
        vldr.f32 s5, wrecf
        vmul.f32 s4, s4, s5         @ xmul = (xmax - xmin) * (1/WIDTH)

        vsub.f32 s5, s3, s2
        vldr.f32 s6, hrecf
        vmul.f32 s5, s5, s6         @ ymul = (ymax - ymin) * (1/HEIGHT)

        vmov.f32 s3, #4.0
        vmov.f32 s20, #2.0

        mov r5, #0                  @ y = 0
        mov r9, #5                  @ Multiplier for color scaling
y_loop:
        cmp r5, HEIGHT_PX
        bge write_buf

        mov r4, #0                  @ x = 0
x_loop:
        cmp r4, WIDTH_PX
        bge x_end

        mov r7, #0                  @ it = 0
        vsub.f32 s6, s6, s6         @ zreal = 0
        vsub.f32 s7, s7, s7         @ zimag = 0

        /* Convert pixel (x,y) to floating-point values */
        vmov.f32 s8, r4
        vcvt.f32.u32 s8, s8
        vmov.f32 s9, r5
        vcvt.f32.u32 s9, s9

        /* Map pixel -> complex plane coordinate (creal + cimag*i) */
        vmul.f32 s8, s8, s4
        vadd.f32 s8, s8, s0         @ creal
        vmul.f32 s9, s9, s5
        vadd.f32 s9, s9, s2         @ cimag
loop:
        cmp r7, MAX_ITER
        beq loop_done

        vmul.f32 s10, s6, s6
        vmul.f32 s11, s7, s7
        vadd.f32 s1, s10, s11       @ |z|^2 = zr^2 + zi^2
        vcmp.f32 s1, s3
        vmrs APSR_nzcv, fpscr
        bpl loop_done               @ If |z|^2 >= 4, escape

        vsub.f32 s12, s10, s11
        vadd.f32 s12, s12, s8       @ new zreal
        vmul.f32 s13, s6, s7
        vmul.f32 s13, s13, s20
        vadd.f32 s7, s13, s9        @ new zimag

        vmov.f32 s6, s12            @ update zreal
        add r7, r7, #1              @ it++
        b loop
loop_done:
        lsr r8, r7, #6              @ Divide by 64 to simplify scaling
        add r8, r8, #1
        mul r8, r8, r9
        lsl r8, r7, r8              @ Generate pseudo-color
        bl set_pixel

        add r4, r4, #1              @ x++
        b x_loop
x_end:
        add r5, r5, #1              @ y++
        b y_loop

/* -------------------------------------------------------------------
 * Write final buffer to framebuffer with pwrite64(fd, buf, count, pos)
 * ------------------------------------------------------------------*/
write_buf:
        mov r0, r6                  @ r0 = fb fd
        ldr r1, =buf                @ r1 = buffer addr
        mov r2, WIDTH_PX * HEIGHT_PX * 2   @ size in bytes
        mov r4, #0                  @ low 32 bits of pos
        mov r5, #0                  @ high 32 bits of pos
        mov r7, #0xB5               @ pwrite64() syscall
        svc #0
        b exit0

/* -------------------------------------------------------------------
 * set_pixel(x=r4, y=r5, color=r8)
 * ------------------------------------------------------------------*/
set_pixel:
        push {r4-r6}
        ldr r0, =buf
        mov r6, WIDTH_PX
        mul r5, r5, r6
        add r5, r5, r4              @ index = y * WIDTH + x
        lsl r4, r5, #1              @ offset *= 2
        add r0, r0, r4
        strh r8, [r0]               @ store pixel color as half-word
        pop {r4-r6}
        bx lr

 open_fb:
        ldr r0, =fbdev
        mov r1, #2                  @ O_RDWR
        mov r7, #5                  @ open() syscall
        svc #0
        bx lr

close_fb:
        mov r0, r6
        mov r7, #6                  @ close() syscall
        svc #0
        bx lr

exit1:
        mov r0, #1
        mov r7, #1                  @ exit(1)
        svc #0

exit0:
        bl close_fb
        mov r0, #0
        mov r7, #1                  @ exit(0)
        svc #0

.data
buf:    .space WIDTH_PX * HEIGHT_PX * 2   @ Pixel buffer (RGB565)
fbdev:  .asciz "/dev/fb0"
.end
