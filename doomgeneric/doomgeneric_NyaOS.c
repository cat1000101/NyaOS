#include "doomkeys.h"

#include "doomgeneric.h"

#include <ctype.h>
#include "NyaOSstdio.h"
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

uint32_t startMsFromBoot = 0;

void DG_Init()
{
    startMsFromBoot = syscall(422);
    printf("start ms: %d", startMsFromBoot);
}

void DG_DrawFrame()
{
    // DG_ScreenBuffer DOOMGENERIC_RESX, DOOMGENERIC_RESY
    uint32_t sizeInPixels = DOOMGENERIC_RESX * DOOMGENERIC_RESY;
    // printf("size: %d, x: %d, y: %d", sizeInPixels, DOOMGENERIC_RESX, DOOMGENERIC_RESY);
    syscall(69420, DG_ScreenBuffer, sizeInPixels);
}

void DG_SleepMs(uint32_t ms)
{
    // printf("sleebing ms:%d", ms);
    syscall(421, ms);
}

uint32_t DG_GetTicksMs()
{
    uint32_t timeInMsSienceStart = (uint32_t)syscall(422) - startMsFromBoot;
    // printf("time passed sience start: %d", timeInMsSienceStart);
    return timeInMsSienceStart;
}

int DG_GetKey(int *pressed, unsigned char *doomKey)
{
    // 0-7 = scanCode 0x1E 0b11110
    // 8-15 = ascii
    // 16-23 = modifier
    // 24-31 = padding
    uint32_t key = (uint32_t)syscall(69421);
    *pressed = (key>>16) & 255;
    *doomKey = (unsigned char)(key & 255);
    // printf("key: %X, pressed: %X, doomKey: %X", key,*pressed, *doomKey);
    if (key) {
        return 1;
    }
    return 0;
}

void DG_SetWindowTitle(const char *title)
{
}

int main(int argc, char **argv)
{
    printf("hello from doomgeneric main\n");

    doomgeneric_Create(0, NULL);

    while (1)
    {
        doomgeneric_Tick();
    }

    return 0;
}
