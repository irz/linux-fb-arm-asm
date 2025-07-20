// Rendering Mandelbrot set into fbdev in ARM Aarch32 assembly

.syntax unified

.text
.global _start
.equ    WIDTH_PX, 1280
.equ    HEIGHT_PX, 800
.equ    MAX_ITER, 200

wrecf: .single 0.00078125 // 1/width
hrecf: .single 0.00125    // 1/height

_start:
        bl open_fb      // open() /dev/fb0, if succesful - r0 will contain the file descriptor
        cmp r0, #0
        bmi exit1       // Exit with 1 if open() failed
        mov r6, r0      // Save fb0 file descriptor

        vmov.f32 s0,#-2.0       //xmin
        vmov.f32 s1,#1.0        //xmax
        vmov.f32 s2,#-1.0       //ymin
        vmov.f32 s3,#1.0        //ymax

        vsub.f32 s4,s1,s0
        vldr.f32 s5,wrecf
        vmul.f32 s4,s4,s5       //xmul

        vsub.f32 s5,s3,s2
        vldr.f32 s6,hrecf
        vmul.f32 s5,s5,s6       //ymul

        vmov.f32 s3,#4.0
        vmov.f32 s20,#2.0

        mov r5, #0      // y = 0
        mov r9, #5
y_loop:
        cmp r5, HEIGHT_PX
        bge write_buf

        mov r4, #0      // x = 0
x_loop:
        cmp r4, WIDTH_PX
        bge x_end

        mov r7,#0               //it = 0
        vsub.f32 s6,s6,s6       // zreal = 0
        vsub.f32 s7,s7,s7       // zimg = 0

        // conv x and y to float
        vmov.f32 s8,r4
        vcvt.f32.u32 s8,s8

        vmov.f32 s9,r5
        vcvt.f32.u32 s9,s9

        vmul.f32 s8,s8,s4
        vadd.f32 s8,s8,s0       // creal

        vmul.f32 s9,s9,s5
        vadd.f32 s9,s9,s2       // cimg

loop:
        cmp r7, MAX_ITER
        beq loop_done

        vmul.f32 s10,s6,s6      // zreal * zreal
        vmul.f32 s11,s7,s7      // zimg * zimg

        vadd.f32 s1,s10,s11
        vcmp.f32 s1,s3
        vmrs APSR_nzcv,fpscr
        bpl loop_done

        vsub.f32 s12,s10,s11
        vadd.f32 s12,s12,s8
        vmul.f32 s13,s6,s7
        vmul.f32 s13,s13,s20
        vadd.f32 s7,s13,s9

        vmov.f32 s6,s12
        add r7,r7,#1
        b loop

loop_done:
        // get lsl value
        // r8 should have color
        lsr r8,r7,#6
        add r8,r8,#1
        mul r8,r8,r9
        lsl r8,r7,r8
        bl set_pixel

        add r4, r4, #1
        b x_loop
x_end:
        add r5, r5, #1
        b y_loop


write_buf:
        mov r0,r6
        ldr r1, =buf
        mov r2, WIDTH_PX * HEIGHT_PX * 2
        mov r3, #0
        mov r4, #0
        mov r5, #0
        mov r7, #0xB5 //pwrite64()
        svc #0
        b exit0

set_pixel:
        push {r4-r6}
        ldr r0, =buf
        mov r6, WIDTH_PX
        mul r5, r5, r6
        add r5, r5, r4
        lsl r4, r5, #1
        add r0, r0, r4
        strh r8, [r0]
        pop {r4-r6}
        bx lr

open_fb:
        ldr r0, =fbdev
        mov r1, #2      // O_RDWR
        mov r7, #5      // open()
        svc #0
        bx lr

close_fb:
        mov r7, #6      // close()
        svc #0
        bx lr

exit1:
        mov r0, #1
        mov r7, #1      // exit(1)
        svc #0

exit0:
        bl close_fb
        mov r0, #0
        mov r7, #1      // exit(0)
        svc #0

.data
buf:    .space WIDTH_PX * HEIGHT_PX * 2
fbdev:  .asciz "/dev/fb0"
.end
