# AGENTS.md - Coding Agent Guidelines for RecoilEngine

## Local Machine Context

This workspace is currently being used on the following development machine:

- Model: MacBook Pro
- OS: macOS 26.3.1
- CPU: Apple M4 Max (`arm64`, Apple Silicon)
- Memory: 128 GB RAM

When adapting build or test commands for this host, prefer Apple Silicon-compatible binaries and remember that Linux helpers such as `nproc` are not available by default on macOS. Use `sysctl -n hw.logicalcpu` if you need the local CPU count.

## Current Project Status

This machine is still being brought up for RecoilEngine development. The current project status is that we are in the process of getting the game building and running successfully on this MacBook Pro.

Current native macOS bring-up work should treat GitHub issue `#936` as required historical context:

- Reference: `https://github.com/beyond-all-reason/RecoilEngine/issues/936`
- Scope relevance: prior attempts to get RecoilEngine building and running on macOS, including historical blockers, workarounds, and dead ends
- Expectation: before proposing or implementing native macOS or Apple Silicon build changes, review the full issue timeline and reconcile new work against it

## Phase-1 Native Apple Silicon Bring-Up Plan

Phase 1 should target a native macOS `arm64` bring-up for `engine-headless` or `engine-dedicated` first. Do not treat the full graphical client as the initial milestone.

### Phase-1 Goal

Get the engine configuring and building natively on this MacBook Pro for a non-graphical target, with enough validation to prove that Apple Silicon portability work is moving in the right direction.

### Phase-1 Non-Goals

- Do not make the full native macOS graphical client the first milestone
- Do not assume Zink, MoltenVK, or a Vulkan-based workaround is the primary phase-1 solution
- Do not accept a Rosetta-only or x86_64-only result as completion for this phase

### Phase-1 Work Sequence

1. SIMD and floating-point portability:
   audit all x86/SSE assumptions, add a compatibility layer for SIMD headers if needed, and adapt the build so Apple Silicon can use an `arm64` path instead of forcing `STREFLOP_SSE`
2. Streflop and sync-sensitive math:
   use the prior arm64 work discussed in issue `#936` and PR `#2540` as reference material, but re-evaluate it carefully for determinism and current-tree compatibility before adopting it
3. CMake and dependency scoping:
   remove or narrow global requirements that block non-graphical targets on macOS, especially client-only dependencies such as DevIL and X11
4. Apple-specific cleanup:
   remove stale x86_64-only assumptions in mac platform code and build flags, and prefer explicit Apple Silicon-compatible compiler and linker settings
5. First native build milestone:
   get `engine-headless` or `engine-dedicated` to configure and compile natively on macOS `arm64`
6. Validation:
   run the most relevant math, sync-adjacent, and headless-target tests that can execute on this machine, and document any determinism concerns before expanding scope
7. Only after phase 1:
   re-evaluate whether the graphical client should target OpenGL core-profile cleanup, a larger renderer refactor, or a separate Vulkan or Metal-oriented effort

### Phase-1 Success Criteria

- Native `arm64` CMake configure succeeds on this machine without relying on Rosetta
- A non-graphical engine target builds successfully on macOS
- The initial Apple Silicon math and determinism risks are documented with concrete test results
- Remaining blockers for a future graphical-client milestone are listed explicitly rather than mixed into phase 1

## Phase-1 Implementation Status

Current Apple Silicon phase-1 progress on this machine has moved beyond planning and into a working native dedicated-server bring-up.

### Verified current status

- Native macOS `arm64` CMake configure succeeds for a dedicated-only build on this MacBook Pro
- `engine-dedicated` now builds as a native Apple Silicon Mach-O executable on this machine
- Native targeted math-adjacent test executables `test_Matrix44f` and `test_Float3` both build and pass on this machine
- Native dedicated runtime smoke now gets through script parsing, blank-map generation, archive checksum acquisition, UDP socket bind, server startup, and demo recording in an isolated macOS data dir

### Current phase-1 limitations

- Streflop is currently disabled for the native Apple Silicon dedicated-only bring-up path, so multiplayer determinism is not yet validated and phase 1 must not be treated as sync-safe completion
- This is a non-graphical milestone only; the native macOS graphical client remains a later effort
- The legacy benchmark script at `tools/benchmark/script_benchmark.txt` is not a valid Apple Silicon dedicated smoke target because it assumes external game, map, and AI content that is not part of this phase-1 fixture

## Dedicated Smoke Verification Contract

The current dedicated smoke-test story for Apple Silicon should stay additive and hermetic. Do not rely on globally installed game content when validating this machine.

### Required smoke-test shape

- Use `--isolation` with a dedicated temporary or fixture data directory
- Stage base content in that isolated data dir via directory archives or equivalent isolated content, including:
  - `base/springcontent.sdd`
  - `base/maphelper.sdd`
  - `base/bitmaps.sdd`
  - `base/cursors.sdd`
- Use a minimal local primary game archive that depends on `Spring content v1`
- Use a blank-map start script with `InitBlank=1` so the smoke path does not depend on an external map archive

### Smoke pass criteria

- The dedicated binary parses the start script without `ExitSpringProcess`
- The blank map is generated successfully in the dedicated path
- The infolog includes:
  - `[script-checksums]`
  - `starting server...`
  - `Server started on port`
  - `recording demo:`
- A demo file is created in the isolated data dir

### Automation hook

- Prefer `test/validation/run-dedicated-blank-smoke.sh` for repeatable native dedicated smoke validation on this machine instead of rebuilding the isolated fixture by hand each time

### Important implementation note

- Dedicated blank-map startup must mirror the existing `PreGame` behavior rather than requiring a separate map fixture; if that path regresses, fix the dedicated startup path instead of weakening the smoke test

## Apple Silicon Porting Principles

Apple Silicon and native macOS support should be implemented as an additive, maintainable extension of the current codebase. Do not degrade existing Linux, Windows, or x86_64 behavior in order to make the new port work.

### Required implementation approach

- Prefer platform-specific hooks, compatibility layers, adapters, or translation shims over invasive rewrites of shared code
- Keep existing code paths intact for current supported builds unless there is a clear cross-platform cleanup that reduces complexity without changing behavior
- Default behavior for existing targets should remain unchanged on this git commit unless a change is intentionally validated for all affected platforms
- When x86/SSE-specific code blocks Apple Silicon support, prefer introducing a narrow abstraction layer such as a SIMD compatibility header or platform-selected implementation file instead of scattering `#ifdef` logic everywhere
- When macOS graphics or windowing behavior differs from other platforms, isolate that behavior behind platform-specific entry points or renderer adapters where practical
- Do not remove or weaken existing implementations just because Apple Silicon requires a different path
- If a compatibility or translation layer is introduced, it must be documented clearly enough that future maintainers can understand what it preserves, what it translates, and how it is verified

### Maintainability rules

- Keep Apple Silicon and macOS-specific logic localized to the smallest reasonable surface area
- Prefer compile-time selection of platform implementations over runtime branching when behavior is platform-dependent and stable
- Avoid large all-at-once refactors when an incremental adapter can unlock the next validation milestone
- If an additive layer becomes too complex, stop and re-evaluate the design before pushing the complexity deeper into shared engine code
- Every porting change should be explainable as either:
  1. a platform-specific hook
  2. a compatibility adapter
  3. a dependency-scoping fix
  4. a cross-platform cleanup with preserved behavior

## Apple Silicon Risk Register

The Apple Silicon port should be managed as a risk-driven effort. A successful compile is not enough.

### Primary risks

- Determinism regression:
  `arm64`, NEON, or compatibility-layer math may compile and still diverge from existing synced behavior in multiplayer or replay execution
- Rendering parity regression:
  a renderer adapter or macOS-specific graphics path may produce visually different results, missing features, or subtle corruption relative to the current implementation
- Existing-platform regression:
  CMake, dependency, or shared-code changes may break Linux, Windows, or x86_64 builds while trying to enable macOS `arm64`
- Performance regression:
  compatibility layers or more conservative floating-point handling may preserve correctness but introduce unacceptable runtime cost
- Maintenance burden:
  the port may succeed locally but leave behind fragile, hard-to-understand code that upstream maintainers are unlikely to accept or maintain

### Required mitigations

- Treat determinism, rendering parity, and existing-platform stability as separate validation gates
- Do not merge or rely on a porting layer that has not been verified against a known-good baseline
- Prefer targeted adapter tests and narrow abstractions over broad rewrites that are hard to validate
- Record known deviations explicitly instead of silently accepting them during bring-up
- If a change improves Apple Silicon support but creates unverified behavioral drift elsewhere, treat that as an unresolved blocker rather than acceptable progress

## Incremental Verification Requirements

Apple Silicon support must be developed incrementally with automated validation at each step. The goal is not just to make the port compile, but to prove that each compatibility layer or adapter preserves existing behavior closely enough to trust the result.

### Baseline-first workflow

- Before changing a behavior-sensitive subsystem, capture a baseline from an existing implementation that is already considered correct
- Use the current implementation on an existing supported platform as the reference output whenever possible
- Do not replace a subsystem first and plan to validate later; establish the baseline before the porting change lands

### Verification expectations by area

- Math and SIMD adapters:
  add targeted tests that compare adapter-backed results against the current implementation across representative inputs, edge cases, and numerically sensitive paths
- Synced simulation:
  use deterministic replays, sync hashes, or equivalent reproducible execution checks to detect divergence as early as possible
- Rendering and graphics adapters:
  build an automated frame-capture or scene-capture workflow that compares output from the new path against a known-good baseline implementation
- Build-system changes:
  verify that existing supported targets still configure and build after dependency-scoping or platform-selection changes

### Rendering verification requirements

- Rendering work should be validated with repeatable scenes or scripted replays, not ad hoc screenshots
- Capture the same frame or frame set from both the baseline implementation and the Apple Silicon path
- Compare outputs with an automated image-diff step and define any tolerance explicitly
- If exact pixel matching is not realistic for a given stage, document the accepted tolerance and the reason for it
- Do not accept visual changes as harmless unless they are understood and recorded

### Incremental delivery rules

- Porting work should land in small, reviewable steps with validation attached to each step
- Each new compatibility layer, translation shim, or platform hook should have a clear test or verification story before the next layer is added
- If a step cannot be validated automatically yet, document the gap and minimize the blast radius of the change until automation catches up
- A later graphical-client milestone should only proceed after the lower-level math, sync, and non-graphical runtime validation is credible

This document provides essential information for AI coding agents working on the RecoilEngine codebase.

## Project Overview

RecoilEngine is an open-source real-time strategy (RTS) game engine written in C++23. It is a fork and continuation of the Spring RTS engine (version 105.0).

## Build Commands

### Building the Engine

**Using Docker (Recommended):**
```bash
# Build for Linux
docker-build-v2/build.sh linux

# Build for Windows
docker-build-v2/build.sh windows

# Build with custom CMake options
docker-build-v2/build.sh linux -DCMAKE_BUILD_TYPE=DEBUG
```

**Without Docker:**
```bash
# Create build directory
mkdir -p build && cd build

# Configure
cmake ..

# Build specific target
cmake --build . --target engine-headless -j$(nproc)

# Build all
cmake --build . -j$(nproc)
```

### Build Types
- `DEBUG` - Debug build with full symbols and no optimization
- `RELEASE` - Optimized release build
- `RELWITHDEBINFO` - Release with debug info (default)
- `PROFILE` - Profiling build

### Build Targets
- `engine-legacy` - Main engine build
- `engine-headless` - Headless server build
- `engine-dedicated` - Dedicated server build
- `tests` - Build all test executables
- `check` - Build and run all tests
- `spring-content` - Build game content packages

## Testing

### Test Framework
The project uses **Catch2** for unit testing. Test files are located in the `test/` directory.

### Running Tests

**Build and run all tests:**
```bash
# From build directory
make tests        # Build all test executables
make check        # Build and run all tests via CTest
make test         # Alternative: run via CTest
```

**Run a single test:**
```bash
# Tests are built as executable binaries in the build directory
# Pattern: test_<TestName>

# Run specific test executable
./test_Float3
./test_Matrix44f
./test_SyncedPrimitive
./test_UDPListener

# Run with verbose output
./test_Float3 -s

# Run specific test case
./test_Float3 "TestSection"
```

**Run via CTest:**
```bash
# Run specific test by name
ctest -R Float3 -V

# Run with regex pattern
ctest -R Matrix -V

# List all available tests
ctest -N
```

### Test Locations
- Unit tests: `test/engine/`
- Test sources use `#include <catch_amalgamated.hpp>`
- Each test is compiled as a separate executable named `test_<TestName>`

## Code Style Guidelines

### Indentation and Formatting
- **Use tabs for indentation** (see `.editorconfig`)
- Tab width: configure your editor to display tabs as you prefer
- Line endings: platform-appropriate (LF on Linux, CRLF on Windows)

### File Headers
All source files must begin with the GPL license header:
```cpp
/* This file is part of the Spring engine (GPL v2 or later), see LICENSE.html */
```

### Include Guards
Use `#pragma once` for new headers, migrate ifdef guards to `#pragma once` whenever you edit a header file.

### Naming Conventions

**Classes and Structs:**
- PascalCase: `Button`, `GameVersion`, `RectangleOverlapHandler`
- Descriptive names: avoid abbreviations unless widely known

**Functions and Methods:**
- PascalCase for public methods: `DrawSelf()`, `HandleEvent()`
- Getters/setters: `GetMajor()`, `Label()`

**Variables:**
- Member variables: camelCase or snake_case: `label`, `clicked`, `hovered`
- Local variables: camelCase preferred
- Boolean variables: often use `is`, `has` prefixes or simple names: `Hovered`, `Clicked`

**Constants:**
- Compile-time constants: UPPER_CASE or PascalCase
- const variables: camelCase

**Namespaces:**
- lowercase: `agui`, `spring`, `springversion`

**Macros:**
- UPPER_CASE with underscores: `LOG_LEVEL_DEBUG`, `CR_DECLARE_STRUCT`

### Braces and Formatting

**Functions:**
```cpp
// Opening brace on new line
void ClassName::MethodName()
{
	// body
}
```

**Control structures:**
```cpp
// Opening brace on same line
if (condition) {
	// body
} else {
	// body
}

for (int i = 0; i < n; ++i) {
	// body
}

switch (value) {
	case CASE_ONE:
		// handle
		break;
	default:
		// handle
}
```

**Classes:**
```cpp
class ClassName : public BaseClass
{
public:
	ClassName();
	virtual ~ClassName();

	void PublicMethod();

private:
	void privateMethod();

	int memberVariable;
};
```

### Imports and Includes

**Order:**
1. Corresponding header (for .cpp files)
2. System/STL headers (angle brackets)
3. Library headers (angle brackets)
4. Project headers (quotes)

**Example:**
```cpp
#include "ClassName.h"              // Corresponding header

#include <cassert>                  // System headers
#include <string>
#include <vector>

#include <SDL2/SDL.h>              // Library headers

#include "System/Log/ILog.h"       // Project headers
#include "Rendering/GL/myGL.h"
```

**Include paths:**
- Use relative paths from `rts/` directory
- Example: `#include "System/float3.h"`

### Error Handling

**Assertions:**
```cpp
#include <cassert>

assert(pointer != nullptr);
assert(index >= 0 && index < size);
```

**Logging:**
Use the built-in logging system with severity levels:
```cpp
#include "System/Log/ILog.h"

LOG_L(L_DEBUG, "Debug message: %s", value);
LOG_L(L_INFO, "Info message");
LOG_L(L_WARNING, "Warning: %d items", count);
LOG_L(L_ERROR, "Error occurred in %s", functionName);
LOG_L(L_FATAL, "Fatal error - cannot continue");
```

Log levels (defined in `System/Log/Level.h`):
- `L_DEBUG` - Fine-grained debug info
- `L_INFO` - General information
- `L_NOTICE` - Always outputted (default level)
- `L_DEPRECATED` - Deprecation warnings
- `L_WARNING` - Potentially harmful situations
- `L_ERROR` - Errors that allow continued execution
- `L_FATAL` - Severe errors causing abort

**Exceptions:**
```cpp
#include <stdexcept>

throw std::runtime_error("Description of error");
```

Custom exceptions may be defined in specific modules.

### Comments

**File-level:**
- GPL license header (required)
- Brief description of file purpose

**Documentation:**
```cpp
/**
 * @brief Brief description
 *
 * Detailed description of the function/class.
 * 
 * @param paramName Description of parameter
 * @return Description of return value
 */
```

**Inline comments:**
```cpp
// Single-line comments for brief notes
// Use // for C++ code, /* */ for C code
```

### C++ Features

**C++ Standard:** C++23

**Modern C++ usage:**
- Use `constexpr` for compile-time constants
- Prefer `auto` for type deduction when type is obvious
- Use range-based for loops
- Use smart pointers where appropriate
- Use `nullptr` instead of `NULL` or `0`

**Synced code:**
The engine has special macros for synchronized multiplayer code:
```cpp
ENTER_SYNCED_CODE();
// synced operations
LEAVE_SYNCED_CODE();
```

### Platform-Specific Code

Use preprocessor directives for platform-specific code:
```cpp
#ifdef WIN32
	// Windows-specific code
#endif

#ifdef HEADLESS
	// Headless build code
#endif

#if defined(__GNUC__)
	// GCC-specific code
#endif
```

## CMake Guidelines

### CMakeLists.txt Style
- Follow `.cmakelintrc` configuration
- Use tabs for indentation in CMake files
- Keep lines reasonably short

### Adding Tests
In `test/CMakeLists.txt`:
```cmake
set(test_name TestName)
set(test_src
	"${CMAKE_CURRENT_SOURCE_DIR}/path/to/TestFile.cpp"
	${test_Common_sources}
)
set(test_libs
	library_name
)
add_spring_test(${test_name} "${test_src}" "${test_libs}" "${test_flags}")
```

## Project Structure

- `rts/` - Main engine source code
  - `rts/System/` - Core system code
  - `rts/Game/` - Game logic
  - `rts/Sim/` - Simulation code
  - `rts/Rendering/` - Graphics rendering
  - `rts/Lua/` - Lua scripting interface
  - `rts/aGui/` - GUI components
  - `rts/lib/` - External libraries
- `test/` - Unit tests
- `tools/` - Utility tools
- `AI/` - AI interface code
- `cont/` - Content files
- `doc/` - Documentation

## AI Usage Policy

**IMPORTANT:** This project has a strict AI usage policy. See `AI_POLICY.md` for full details.

**Key requirements:**
1. **Disclose all AI usage** - State the tool used and extent of assistance
2. **PRs must reference accepted issues** - No drive-by AI-generated PRs
3. **Human verification required** - All AI-generated code must be tested by a human
4. **No AI-generated media** - Only text and code allowed
5. **Human-in-the-loop required** - Review and edit all AI-generated content

**Maintainers are exempt** from these rules; they use AI at their discretion.

## Important Notes

### Synced Code
The engine uses deterministic simulation for multiplayer. Code that affects game state must maintain sync across clients. Look for `SYNCCHECK` and `streflop` references.

### Threading
The engine uses custom thread pools. See `THREADPOOL` define and related code.

### Testing Changes
- For Lua changes: write a test widget
- For other changes: manual testing procedure required
- Automated tests are encouraged but not always required due to complexity

### Before Submitting PRs
1. Test your changes thoroughly
2. Reference an accepted issue
3. Document what testing was performed
4. Follow the workflow in `contributing.md`
5. Disclose any AI assistance used

## Additional Resources

- Official website: https://recoilengine.org
- Documentation: https://recoilengine.org/docs/
- Build guide: https://recoilengine.org/development/building-without-docker/
- Discord: https://discord.gg/GUpRg6Wz3e
- GitHub issues: https://github.com/beyond-all-reason/RecoilEngine/issues
