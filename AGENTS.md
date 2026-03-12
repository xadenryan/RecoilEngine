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

Current verified Apple Silicon status on this machine:

- `engine-dedicated` builds and passes the isolated blank-map smoke
- `engine-headless` builds and passes the isolated blank-map smoke
- `engine-legacy` now builds as a native `arm64` Mach-O executable
- `engine-legacy` now passes the isolated blank-map GUI smoke in a visible macOS desktop session
- `test/validation/run-legacy-render-smoke.sh` now captures a deterministic validation frame from the native macOS legacy client, and a repeat capture matches the current baseline through `test/validation/compare-render-images.sh`
- the modern info-texture path now uses a localized GLSL-version adapter so its core-safe fullscreen shaders can promote from GLSL 1.30 to 1.50 when the macOS client is forced onto an OpenGL core profile
- the native macOS core-profile path now includes additive Lua and shader compatibility layers for Apple OpenGL 4.1: program validation auto-binds a temporary VAO when needed, Lua VAO draws emulate missing `ARB_base_instance` and `ARB_multi_draw_indirect` behavior per draw, and Lua shader compilation now normalizes GLSL versions, strips unsupported `layout(binding=...)` qualifiers, and rebinds engine UBO blocks explicitly after program link
- `test/validation/run-bar-realcontent-smoke.sh` now boots the native Apple Silicon legacy client into a real BAR content scene, downloads the required BAR packages through the isolated fixture, and captures a validation screenshot from the native macOS client
- native graphical-client runtime verification beyond the current blank-map startup and render-capture harness is still in progress because SDL requires a macOS session with visible displays and broader renderer parity work remains

## Apple Silicon Dependency Bootstrap

Record every host dependency required to build RecoilEngine on Apple Silicon macOS as it is discovered. Do not leave this implicit in terminal history.

### Required Apple toolchain on this machine

- Full Xcode selected via `xcode-select`:
  `/Applications/Xcode.app/Contents/Developer`
- Apple Clang:
  `Apple clang version 17.0.0 (clang-1700.6.4.2)`
- CMake:
  `cmake version 4.2.3`

If another Apple Silicon machine uses a different Xcode, Clang, or CMake baseline during bring-up, record the exact versions here in the same change set.

### Current Homebrew bootstrap command

```bash
brew install sdl2 freetype fontconfig libogg libvorbis pkgconf devil sevenzip openal-soft
```

### Current Homebrew packages verified on this machine

- `sdl2 2.32.10`
- `freetype 2.14.2`
- `fontconfig 2.17.1`
- `libogg 1.3.6`
- `libvorbis 1.3.7`
- `pkgconf 2.5.1`
- `devil 1.8.0_6`
- `sevenzip 26.00`
- `openal-soft 1.25.1`

### Dependency notes

- `devil` is required when configuring the shared graphical or headless build graph on this machine
- `sevenzip` is required for `cont/base` archive generation during the current headless build flow
- Homebrew currently provides the SevenZip executable as `7zz`, so the build system must not assume only `7z` or `7za`
- `sdl2`, `freetype`, `fontconfig`, `libogg`, `libvorbis`, and `pkgconf` are part of the current macOS bootstrap surface and should be installed before debugging higher-level build failures
- `openal-soft` is required for the current native macOS graphical-client bring-up because Apple-provided `OpenAL.framework` does not expose the EFX surface the current sound implementation expects
- automated render comparison currently relies on the macOS-provided `sips` binary; on this macOS 26.3.1 host `sips` cannot emit PPM, so `test/validation/compare-render-images.sh` must normalize images to TIFF instead

### Known runtime environment requirements

- X11 or XQuartz is no longer required for the current native macOS client configure and build path; GLX and X11 linkage are now scoped to non-Apple Unix targets
- Native graphical-client smoke requires a macOS session with visible desktop displays; when AppKit and SDL both report zero displays, the client aborts before OpenGL initialization with `The video driver did not add any displays`
- The current isolated native legacy-client smoke must stage `cont/fonts` into the isolation dir as `fonts/`, or the client will fail during early UI and font initialization
- The current isolated native legacy-client smoke must set `ForceCoreContext = 1` in a flat `springsettings.cfg` because the Apple OpenGL path on this machine does not provide a higher-version compatibility context during SDL context creation
- The current isolated native legacy render-validation smoke also depends on the automation-only config keys `ValidationRenderCapture = 1` and `ValidationRenderCaptureFrame = 30` to trigger the engine-side screenshot hook at a deterministic frame
- The current BAR real-content smoke depends on `tools/pr-downloader` plus network access to fetch the BAR package and map archives unless a warmed `RECOIL_BAR_CONTENT_CACHE_DIR` is provided
- `SDL_VIDEODRIVER=offscreen` is not a substitute for a real GUI session on this machine: SDL reports a synthetic `1024x768` mode, but `CreateSDLWindow` still fails with `Could not initialize OpenGL / GLES library`
- If additional host tools or launch-context requirements are discovered for GUI validation on other Apple Silicon machines, add the exact steps here immediately

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
- `engine-headless` now builds as a native Apple Silicon Mach-O executable on this machine
- `engine-dedicated` now builds as a native Apple Silicon Mach-O executable on this machine
- `engine-legacy` now builds as a native Apple Silicon Mach-O executable on this machine
- Native targeted math-adjacent test executables `test_Matrix44f` and `test_Float3` both build and pass on this machine
- Native headless runtime smoke gets through script parsing, blank-map generation, archive checksum acquisition, local server startup, and demo recording in an isolated macOS data dir
- Native dedicated runtime smoke now gets through script parsing, blank-map generation, archive checksum acquisition, UDP socket bind, server startup, and demo recording in an isolated macOS data dir
- Native legacy blank-map GUI smoke now gets through SDL init, OpenGL init, demo recording, and the configured stabilization window in an isolated macOS data dir
- Native legacy render-validation smoke now captures a blank-map screenshot and a repeat capture matches the current baseline image through `test/validation/compare-render-images.sh`

### Current phase-1 limitations

- Streflop is currently disabled for the native Apple Silicon dedicated-only bring-up path, so multiplayer determinism is not yet validated and phase 1 must not be treated as sync-safe completion
- The native macOS graphical client now builds, but automated runtime smoke still requires an interactive macOS desktop session with visible displays; in the current automation context even `launchctl bsexec` against the Aqua login session can still fail before OpenGL initialization with `The video driver did not add any displays`
- The current Apple core-profile client path still has known rendering gaps after startup, including the optional uniform-constant UBO path, sky shader parity, and other compatibility-profile shader surfaces that have not been fully modernized yet
- The current automated render-parity proof only covers the blank-map fixture used by `test/validation/run-legacy-render-smoke.sh`; it is a narrow regression harness, not yet a substitute for broader gameplay or replay-based graphical parity testing
- Real BAR content startup is now working far enough to render and capture a frame on native Apple Silicon, but repeated BAR capture is still not stable enough to treat as a deterministic graphical parity proof; the latest repeated capture drift remains confined to the top-right quadrant of the captured frame
- BAR content still loses a number of optional GL4 widgets on this macOS OpenGL 4.1 path because BAR ships shaders that truly require SSBO support beyond Apple OpenGL 4.1, and a smaller set of remaining Lua or engine shader surfaces still need additional additive translation for GLSL 1.20 or core-profile `#version` handling
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
- The smoke entrypoint auto-bootstraps through `test/validation/run-smoke-wrapper.sh`, which records a pre-run process baseline, suppresses newly spawned `ReportCrash` and `CrashReporterSupportHelper` helper processes while the smoke is running, and kills only newly spawned `spring`, `spring-dedicated`, `spring-headless`, `ReportCrash`, and `CrashReporterSupportHelper` processes on exit so failed smoke runs do not leave behind engine processes or crash dialogs

### Important implementation note

- Dedicated blank-map startup must mirror the existing `PreGame` behavior rather than requiring a separate map fixture; if that path regresses, fix the dedicated startup path instead of weakening the smoke test

## Legacy Client Smoke Verification Contract

The current macOS graphical-client smoke-test story should stay additive and hermetic in the same way as the dedicated and headless bring-up.

### Required smoke-test shape

- Use `--isolation` with a temporary or fixture data directory
- Stage the same minimal base and game fixture used by the dedicated and headless Apple Silicon smoke tests
- Start the client in background windowed mode so SDL and the OpenGL path still initialize without making fullscreen assumptions about the host session
- Use a blank-map start script with `InitBlank=1` and `OnlyLocal=1`

### Smoke pass criteria

- The infolog includes:
 - `SDL version :`
 - `GL version  :`
 - `Initialized OpenGL Context:`
  - `[PreGame::GameDataReceived] recording demo to`
- The process remains alive for the configured stabilization window after those markers appear
- The infolog does not contain `Fatal: [ExitSpringProcess]`, `Segmentation fault`, or `caught opengl_error`
- A demo file is created in the isolated data dir

### Automation hook

- Prefer `test/validation/run-legacy-blank-smoke.sh` for repeatable native client smoke validation on this machine
- The smoke entrypoint auto-bootstraps through `test/validation/run-smoke-wrapper.sh`, which records a pre-run process baseline, suppresses newly spawned `ReportCrash` and `CrashReporterSupportHelper` helper processes while the smoke is running, and kills only newly spawned `spring`, `spring-dedicated`, `spring-headless`, `ReportCrash`, and `CrashReporterSupportHelper` processes on exit so failed smoke runs do not leave behind engine processes or crash dialogs
- When the smoke is launched from macOS automation outside an interactive desktop session, it may still fail before OpenGL init if AppKit and SDL both report zero displays; treat that as a launch-context limitation unless the same failure reproduces in a normal GUI session
- The smoke fixture must stage `fonts/` and a flat `springsettings.cfg` with `ForceCoreContext = 1`; do not silently remove either requirement without replacing it with a verified native compatibility-context path
- The smoke harness should only report success after the client stays alive long enough to prove it did not just write a demo and immediately crash

## Legacy Render Validation Contract

The current render-validation path is a narrow graphical regression harness for the native macOS client. It is intended to support incremental Apple Silicon bring-up without pretending to prove full gameplay rendering parity yet.

### Required smoke-test shape

- Use the same isolated blank-map fixture and minimal local game archive pattern as the dedicated, headless, and legacy blank-map smoke tests
- Set `ForceCoreContext = 1` in the isolated `springsettings.cfg` until a verified native compatibility-context path exists on macOS
- Enable the automation-only config keys `ValidationRenderCapture = 1` and `ValidationRenderCaptureFrame = 30`
- Run from a visible macOS desktop session so SDL can create the window and OpenGL context

### Current engine-side validation hook

- `ValidationRenderCapture` currently hides the interface, disables clock, FPS, and speed overlays, moves the active camera to the blank-map center, captures a screenshot at the configured frame, and then requests a clean shutdown
- `SpringApp::Reload()` and `SpringApp::Kill()` must wait for pending screenshot writes before tearing down the thread pool so validation exits with a fully written PNG instead of a truncated file

### Pass criteria

- A PNG screenshot is written into the isolated `screenshots/` directory
- When a reference image is provided, `test/validation/compare-render-images.sh` prints `Render images match.`
- The smoke wrapper leaves no newly spawned `spring*` or crash-helper processes behind after the run

### Automation hook

- Prefer `test/validation/run-legacy-render-smoke.sh` for repeatable native render validation on this machine
- Pass an optional second argument pointing at a known-good reference image when checking graphical parity for the current blank-map fixture
- `test/validation/compare-render-images.sh` currently normalizes both images to TIFF via macOS `sips` and expects exact byte equality after normalization; if a future stage requires tolerances, document the accepted tolerance and reason in this file before relaxing the check

## Apple Silicon Porting Principles

Apple Silicon and native macOS support should be implemented as an additive, maintainable extension of the current codebase. Do not degrade existing Linux, Windows, or x86_64 behavior in order to make the new port work.

### Required documentation for temporary disables

Any Apple Silicon or macOS-specific disable, fallback, stub, or feature reduction must be recorded in this file immediately when it is introduced or discovered.

Each entry must capture:

- what was disabled, narrowed, or stubbed
- whether it is compile-time, link-time, startup, runtime, rendering, sound, or determinism related
- why the disable currently exists on Apple Silicon or macOS
- what verification impact it has
- what the intended exit criteria are for replacing the disable with a proper implementation

Do not silently disable subsystems just to get a build through. If a temporary disable is unavoidable, document it here in the same change set.

### Current documented Apple-specific disables and stubs

- Determinism:
  streflop is currently disabled for the native Apple Silicon bring-up path.
  Why: the current `arm64` build path is being brought up first, and sync-safe floating-point behavior has not been re-established yet.
  Verification impact: successful builds and smokes do not currently imply multiplayer or replay determinism.
  Exit criteria: restore an `arm64`-safe determinism path and validate it with replay or sync-hash checks before treating Apple Silicon as sync-safe.

- Input and cursor handling:
  `rts/Game/UI/HwMouseCursor.cpp` uses the `HardwareCursorApple` stub on macOS, so native hardware cursor support is currently unavailable on this platform path.
  Why: the Apple-specific hardware cursor implementation has not been ported yet.
  Verification impact: graphical validation does not currently prove hardware cursor parity with existing Linux or Windows behavior.
  Exit criteria: replace the stub with a native macOS cursor implementation or a verified SDL-backed adapter that preserves expected cursor behavior.

- OpenGL context creation:
  the native macOS client currently falls back to an Apple core-profile context when SDL cannot create a compatibility-profile context at or above the requested version.
  Why: on this machine, Apple exposes usable higher-version core contexts but does not provide a matching compatibility context during the legacy client bring-up path.
  Verification impact: passing the graphical smoke now proves the additive Apple core-profile translation path works far enough to start the client, not that macOS provides the same compatibility-profile behavior as Linux or Windows.
  Exit criteria: either restore a verified compatibility-context path on macOS or complete enough renderer modernization that the native client no longer depends on compatibility-context-only behavior.

- Legacy OpenGL extension gate:
  the native macOS client currently waives the hard startup requirement for `GL_ARB_texture_env_combine` during Apple core-profile bring-up.
  Why: Apple core-profile contexts do not advertise the legacy compatibility extension string even though the porting work is trying to translate or bypass those legacy assumptions incrementally.
  Verification impact: a successful startup no longer proves parity for every fixed-function texture-env path that older compatibility renderers relied on.
  Exit criteria: remove the waiver once the remaining fixed-function and compatibility-only texture environment assumptions are eliminated or replaced with a verified modern equivalent.

- Uniform-constant shader path:
  the Apple core-profile path now uses a compatibility layer instead of hard-disabling UBO-backed uniform constants when raw `GL_ARB_shading_language_420pack` is missing.
  Why: Apple OpenGL 4.1 exposes the core UBO surface needed by the engine, but not the full legacy ARB extension string and `layout(binding=...)` path the original shaders assumed.
  Verification impact: current client startup and BAR smoke now prove that engine UBO blocks can be rebound through explicit `glUniformBlockBinding`, but they do not yet prove full parity for every shader that still assumes newer GLSL layout or SSBO features.
  Exit criteria: keep the compatibility layer only as long as needed to preserve behavior on Apple OpenGL 4.1, and remove or narrow it once the affected shader surfaces no longer rely on unsupported layout semantics.

- Lua GL4 draw submission:
  the Apple core-profile path now emulates missing `GL_ARB_base_instance` and `GL_ARB_multi_draw_indirect` behavior for Lua VAO draws instead of disabling those paths outright.
  Why: BAR's Lua GL4 stack uses modern instanced and indirect draw surfaces, while Apple OpenGL 4.1 lacks the newer draw entry points available on Linux and Windows GL 4.2+ or 4.3+ drivers.
  Verification impact: BAR real-content smoke now gets past the prior Lua VAO capability failures and can render a frame, but performance and behavioral parity for these emulated draw paths are not yet treated as fully proven across broader gameplay scenes.
  Exit criteria: verify the additive draw-emulation path against known-good references for the affected widgets and keep it localized so existing higher-capability platforms continue to use their native fast path unchanged.

- BAR GL4 widget surface:
  BAR real-content startup currently disables a number of optional GL4 Lua widgets and effects on the native macOS Apple Silicon path.
  Why: Apple OpenGL tops out at GLSL 4.10 and does not expose SSBO support on this path, while BAR currently ships several Lua GL4 shaders and widgets that require true SSBO-backed `buffer` blocks or still assume newer or legacy GLSL/profile semantics than the current additive translation layer covers.
  Verification impact: a successful BAR real-content smoke currently proves the native macOS client can boot BAR content and render a frame, but it does not yet prove parity for the affected higher-end Lua GL4 widgets, UI, or post-processing behavior. As of the current verified BAR smoke, the still-failing or removed surfaces include `ResurrectionHalosShader GL4`, `selectedUnitsGroundShader GL4`, `energy iconsShader GL4`, `Health Bars Shader GL4`, `JetShader GL4`, `Ground AO Plates FeaturesShader GL4`, `orbShader GL4`, `allySelectedUnitsShader GL4`, `unitGroupsShader GL4`, `Rank IconsShader GL4`, and the sensor-range stencil shaders; a smaller non-SSBO subset still needs additional translation work, including `AoE Napalm Shader`, `GenBrdfLut`, `GenEnvLut`, `Bloom Combine Shader`, and some remaining engine-side core-profile shader surfaces.
  Exit criteria: add additive compatibility adapters or capability-translation fixes that let the affected BAR Lua GL4 paths either run correctly on Apple OpenGL 4.1 or degrade in a documented, verified way against a known-good reference, and remove widgets from this note only after the render smoke demonstrates the change rather than assuming it.

- Sky rendering:
  `ISky::SetSky` can currently fail to create `ModernSky` on the Apple core-profile path and fall back to `NullSky`.
  Why: the current sky shader stack still depends on GLSL and profile assumptions that are not yet fully adapted for Apple core-profile execution.
  Verification impact: successful client startup does not currently prove sky rendering parity with existing Linux or Windows builds.
  Exit criteria: make the sky shaders compile and render correctly on the Apple core-profile path, then verify the output against a known-good baseline before removing the fallback note.

- Dynamic model lights:
  the Apple core-profile bridge currently forces `MAX_DYNAMIC_MODEL_LIGHTS` to `0` for the legacy GLSL model shader path.
  Why: the original model shaders depend on `gl_LightSource` fixed-function GLSL state, and the current additive bridge is reusing the existing VAO path plus per-draw matrix uploads before a proper dynamic-light uniform adapter is in place.
  Verification impact: successful client startup and rendering smoke do not currently prove parity for dynamic per-model light contributions on Apple Silicon or macOS core-profile contexts.
  Exit criteria: add a verified shader-uniform adapter for model dynamic lights, compare rendered output against an existing supported build, and remove the temporary zero-light fallback.

- Depth-buffer copy:
  `DepthBufferCopy` currently reports itself unusable and skips `MakeDepthBufferCopy()` on the Apple core-profile path.
  Why: the current macOS core-profile bring-up reaches a hard crash inside `FBO::Blit` while copying the main depth buffer into the depth-copy FBO, so the unsafe blit path is being isolated instead of forcing a brittle framebuffer workaround into shared rendering code.
  Verification impact: successful Apple Silicon client smoke does not currently prove parity for depth-texture consumers such as soft projectile effects or depth-aware ground decals on the native macOS path.
  Exit criteria: replace the Apple-specific skip with a verified depth-copy implementation on macOS core-profile contexts and validate the affected rendering paths against an existing supported build.

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
