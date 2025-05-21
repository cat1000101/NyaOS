#include "NyaOSstdio.h"

#include "m_argv.h"

#include "doomgeneric.h"

pixel_t *DG_ScreenBuffer = NULL;

void M_FindResponseFile(void);
void D_DoomMain(void);

void doomgeneric_Create(int argc, char **argv)
{
	// save arguments
	myargc = argc;
	myargv = argv;

	M_FindResponseFile();

	DG_ScreenBuffer = malloc(DOOMGENERIC_RESX * DOOMGENERIC_RESY * 4);

	printf("the DG_Screeen: %p\n", DG_ScreenBuffer);

	DG_Init();

	D_DoomMain();

	printf("doom create finished\n");
}
