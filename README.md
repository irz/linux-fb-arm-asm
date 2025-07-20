# Working with Linux Framebuffer using ARMv7 assembly
I wanted to practice working with framebuffer on custom board running on i.MX6DL using ARM ASM.
The goal was to render Mandelbrot set using scalar floating point instructions and play with NEON SIMD/vector extension.

## Contents
**getfbinfo.c**

Basic code to query Linux framebuffer settings like resolution and LCD pixel format. This knowledge will come in handy when writing ASM.\
To build run _make getfbinfo_

**mandelbrot.s**

Scalar version of the Mandelbrot set.\
To build run  _make mandelbrot_

**mandelbrot-neon.s**

Fairly straightforward vector implementation. Runs around 2 times faster. There's probably a faster implementation to be found.\
To build run _make mandelbrot-neon_
