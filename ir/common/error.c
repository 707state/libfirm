/*
 * This file is part of libFirm.
 * Copyright (C) 2012 University of Karlsruhe.
 */

/**
 * @file
 * @brief     Error handling for libFirm
 * @author    Michael Beck
 */
#include "config.h"

#include <stdlib.h>

#include <stdio.h>
#include <stdarg.h>
#include "error.h"
#include "irprintf.h"

NORETURN (panic)(char const *const file, int const line, char const *const func, char const *const fmt, ...)
{
	va_list ap;

	fprintf(stderr, "%s:%d: libFirm panic in %s: ", file, line, func);
	va_start(ap, fmt);
	ir_vfprintf(stderr, fmt, ap);
	va_end(ap);
	putc('\n', stderr);
	abort();
}
