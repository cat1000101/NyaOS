//
// Copyright(C) 2005-2014 Simon Howard
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// DESCRIPTION:
//    Exit text-mode ENDOOM screen.
//

#include "NyaOSstdio.h"
#include <string.h>

#include "config.h"
#include "doomtype.h"
#include "i_video.h"

#ifdef ORIGCODE
#include "txt_main.h"
#endif


#ifdef __DJGPP__
#include <go32.h>
#endif  // __DJGPP__


#define ENDOOM_W 80
#define ENDOOM_H 25

// 
// Displays the text mode ending screen after the game quits
//

void I_Endoom(byte *endoom_data)
{
#ifdef ORIGCODE
    unsigned char *screendata;
    int y;
    int indent;

    // Set up text mode screen

    TXT_Init();
    I_InitWindowTitle();
    I_InitWindowIcon();

    // Write the data to the screen memory

    screendata = TXT_GetScreenData();

    indent = (ENDOOM_W - TXT_SCREEN_W) / 2;

    for (y=0; y<TXT_SCREEN_H; ++y)
    {
        memcpy(screendata + (y * TXT_SCREEN_W * 2),
               endoom_data + (y * ENDOOM_W + indent) * 2,
               TXT_SCREEN_W * 2);
    }

    // Wait for a keypress

    while (true)
    {
        TXT_UpdateScreen();

        if (TXT_GetChar() > 0)
        {
            break;
        }

        TXT_Sleep(0);
    }

    // Shut down text mode screen

    TXT_Shutdown();

#elif defined(__DJGPP__)

    int y;

    // move cursor to bottom
    // there's a direct call for moving cursor somewhere but this is simpler to write
    for (y = 0; y < ENDOOM_H; y++) {
        puts("\n");
    }

    // allegro exit should have been run already and so we should be in text mode again
    movedata(_my_ds(), (unsigned) endoom_data, _dos_ds, 0xB8000UL, ENDOOM_W * ENDOOM_H * 2);

#endif
}

