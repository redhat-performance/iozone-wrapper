#include <stdio.h>
#include <string.h>
#include <stdlib.h>

main(int argc, char **argv)
{
	char *buffer;
	int count;
	FILE *fd;
	char set=0x5f;
	long size;

	size = atoi(argv[2]);

	buffer = (char *) malloc(1024*1024);
	memset(buffer, set, 1024*1024);

	fd = fopen(argv[1], "w");
	for (count = 0; count < (1024*size); count++) {
		fwrite(buffer, 1024*1024, 1, fd);
	}
	fclose(fd);
}
