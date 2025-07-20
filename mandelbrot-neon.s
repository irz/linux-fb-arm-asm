// Rendering Mandelbrot set into fbdev in ARM Aarch32 assembly
// Using ARM NEON vector extensions

.syntax unified

.text
.global _start
.equ    WIDTH_PX, 1280
.equ    HEIGHT_PX, 800
.equ    MAX_ITER, 200

wrecf: .single 0.00078125       // 1/width
hrecf: .single 0.00125          // 1/height

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

        mov r5, #0              // y = 0
        vmov.f32 q3,#4.0
        vmov.f32 q10,#2.0
        vmov.u32 q14,#200
        vmov.u32 q15,#1

y_loop:
        cmp r5, HEIGHT_PX
        bge write_buf

        // compute cim
        vmov.f32 s6,r5
        vcvt.f32.u32 s6,s6
        vmul.f32 s6,s6,s5
        vadd.f32 s6,s6,s2
        vdup.f32 q2,d3[0]       // cim vector

        ldr r8,=xinit
        vldm r8,{q4}
        mov r4, #0              // x = 0

x_loop:
        cmp r4, WIDTH_PX
        bge x_end

        // compute cr vector
        vmul.f32 q5,q4,d2[0]
        vdup.f32 q6,d0[0]
        vadd.f32 q5,q5,q6       // cr vector

        // set zr, zim = 0
        veor.f32 q6,q6,q6       // zr
        veor.f32 q7,q7,q7       // zim
        veor.u32 q11,q11,q11    // iterations = 0

        // begin inner loop
loop:
        vmul.f32 q8,q6,q6       // zr^2
        vmul.f32 q9,q7,q7       // zim^2

        // check for all elements of vec zr^2+zim^2 < 4
        vadd.f32 q12,q8,q9
        vclt.f32 q12,q12,q3
        // check if all iterations are >= MAX_ITER
        vclt.u32 q13,q11,q14
        // create mask of which elements to update
        vand    q12,q13,q12
        // continue with conditional
        vorr    d26,d24,d25
        vpmax.u32 d26,d26,d26
        vmov r9,d26[0]
        cmp r9,#0
        beq loop_done

        // update zim
        vmul.f32 q7,q6,q7
        vmul.f32 q7,q7,q10
        vadd.f32 q7,q7,q2

        //update zr
        vsub.f32 q6,q8,q9
        vadd.f32 q6,q6,q5

        // increment iterations by mask
        vand    q12,q15,q12
        vadd.u32 q11,q11,q12

        b loop

loop_done:
        // arrive to iteration vector for each 4 pixels
        vshr.u32 q12,q11,#6
        vadd.u32 q12,q12,q15
        vmov.u32 q13,#5
        vmul.u32 q12,q13,q12
        vshl.u32 q11,q11,q12

        // store iter vector to the right memory addr
        vmovn.u32 d24,q11
        bl set_pixvec

        // update x vector
        vadd.f32 q4,q4,q3
        add r4, r4, #4
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

set_pixvec:
        push {r4-r6}
        ldr r0,=buf
        mov r6,WIDTH_PX
        mla r5,r5,r6,r4
        lsl r4,r5,#1
        add r0,r0,r4
        vst1.16 {d24},[r0]
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
        bl close_fb
        mov r0, #1
        mov r7, #1      // exit(1)
        svc #0

exit0:
        bl close_fb
        mov r0, #0
        mov r7, #1      // exit(0)
        svc #0

.data
.align 16
xinit:  .single 0.0, 1.0, 2.0, 3.0
buf:    .space WIDTH_PX * HEIGHT_PX * 2
fbdev:  .asciz "/dev/fb0"
.end
