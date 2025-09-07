# Working with Linux Framebuffer using ARMv7-A assembly and NEON
This repo contains Mandelbrot set renderer implemented in ARM assembly for [G3 display module](https://www.reachtech.com/products/touchscreen-display-modules/g3-modules/) (a custom i.MX6DL-based embedded board running Linux).
The rendering is directly to the Linux framebuffer using syscalls from asm.\
The project includes both scalar implementation using ARM floating-point instructions and optimized version using NEON SIMD for vectorized computation. 
It serves as a demo of direct framebuffer access, performance tuning and use of NEON extensions for graphics workloads.


<img width="1280" height="800" alt="mandelbrot" src="https://github.com/user-attachments/assets/653b129e-ff1f-4002-8018-17037f8d6f8a" />

## Contents
**getfbinfo.c**

Basic code to query Linux framebuffer settings like resolution and LCD pixel format. This knowledge will come in handy when writing asm.\
To build run `make getfbinfo`

**mandelbrot.s**

Scalar version of the Mandelbrot set.\
To build run  `make mandelbrot`

**mandelbrot-neon.s**

Fairly straightforward vector implementation. Runs around 2 times faster. There's probably a faster implementation to be found.\
To build run `make mandelbrot-neon`

**gettime.s**

Example of how to use `clock_gettime()` syscalls from ARM assembly. Doesn't do anything, but will show time delta between 2 syscalls if you run it.\
To build run `make gettime`
