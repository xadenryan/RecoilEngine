/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */

#pragma once

#include "System/MainDefines.h"

#if (__is_x86_arch__ == 1)
	#include <xmmintrin.h>
	#include <emmintrin.h>
	#include <immintrin.h>
	#define SPRING_HAVE_SSE_INTRINSICS 1
#else
	#define SPRING_HAVE_SSE_INTRINSICS 0
#endif
