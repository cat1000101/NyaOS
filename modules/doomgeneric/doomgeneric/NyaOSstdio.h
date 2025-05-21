#ifndef _NYAOS_STDIO_H
#define _NYAOS_STDIO_H

#include <stdio.h>

void debugPrint(const char *);
int debugPrintf(const char *__restrict, va_list);

int puts(const char *);
int putchar(int);

int printf(const char *__restrict, ...);
int fprintf(FILE *__restrict, const char *__restrict, ...);

#endif