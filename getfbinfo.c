#include <linux/fb.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <string.h>


int main(int argc, char* argv[])
{
		if (argc != 2)
		{
				fprintf(stderr, "Usage: %s /dev/fbX\n", argv[0]);
				exit(EXIT_FAILURE);
		}

		int fbfd = open(argv[1], O_RDWR);
		
		if (fbfd < 0)
		{
			perror("open(fbdev)");
			exit(EXIT_FAILURE);
		}
		
		struct fb_var_screeninfo fbinfo;
		if (ioctl(fbfd, FBIOGET_VSCREENINFO, &fbinfo) < 0)
		{
				perror("ioctl(FBIOGET_VSCREENINFO)");
				close(fbfd);
				exit(EXIT_FAILURE);
		}

		printf("\n%s:\n\twidth: %d, height: %d, bpp: %d\n", argv[1], fbinfo.xres, fbinfo.yres, fbinfo.bits_per_pixel);
		printf("\tRGB: %d%d%d\n\n", fbinfo.red.length, fbinfo.green.length, fbinfo.blue.length);

		close(fbfd);
		return EXIT_SUCCESS;
}
