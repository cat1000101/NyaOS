#include "NyaOSstdio.h"
#include <stdarg.h>
#include <string.h>

void debugPrint(const char *string)
{
	asm(
		"movl $69, %%eax\n"
		"movl %0, %%ebx\n"
		"int $0x80\n"
		:
		: "r"(string)
		: "%eax", "%ebx");
}

void debugPrintChar(char c)
{
	asm(
		"movl $420, %%eax\n"
		"movb %0, %%bl\n"
		"int $0x80\n"
		:
		: "r"(c)
		: "%eax", "%ebx");
}

int debugPrintf(const char *restrict fmt, va_list args)
{
	char formatted_string[1024];

	int result = vsnprintf(formatted_string, sizeof(formatted_string), fmt, args);

	if (result < 0)
	{
		return result;
	}

	debugPrint(formatted_string);
	return result;
}

int puts(const char *string)
{
	debugPrint(string);
}
int putchar(int c)
{
	debugPrintChar((char)c);
}

int fprintf(FILE *restrict f, const char *restrict fmt, ...)
{
	va_list args;
	va_start(args, fmt);

	int result = debugPrintf(fmt, args);

	va_end(args);

	return result;
}

int printf(const char *restrict fmt, ...)
{
	va_list args;
	va_start(args, fmt);

	int result = debugPrintf(fmt, args);

	va_end(args);

	return result;
}
