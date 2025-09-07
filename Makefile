# config
# Use CROSSCOMP=1 to enable cross-compilation
CROSSCOMP ?= 0

ifeq ($(CROSSCOMP),1)
# Make sure crosscompiler is in the $PATH
CC = arm-none-linux-gnueabihf-gcc
else
CC = gcc
endif

ASFLAGS = -mfpu=auto -march=armv7-a+mp+sec+neon-fp16 -nostartfiles -Xlinker -e_start
CFLAGS = -O2
LDFLAGS =

# targets
all: getfbinfo mandelbrot mandelbrot-neon

getfbinfo: getfbinfo.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

mandelbrot: mandelbrot.s
	$(CC) $(ASFLAGS) -o $@ $<

mandelbrot-neon: mandelbrot-neon.s
	$(CC) $(ASFLAGS) -o $@ $<

gettime: gettime.s
	$(CC) $(ASFLAGS) -o $@ $<

clean:
	rm -f getfbinfo mandelbrot mandelbrot-neon

.PHONY: all clean
