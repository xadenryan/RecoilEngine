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

High-level Apple Silicon status on this machine:

- native `arm64` builds for `engine-dedicated`, `engine-headless`, and `engine-legacy` are working
- the blank-map smoke and deterministic render-validation harnesses are working on this machine
- BAR real-content validation is partially working, but full native macOS playability and rendering parity are still in progress

## macOS Bring-Up Docs

Detailed machine-specific setup, dependency bootstrap, runtime requirements, bring-up status, and same-machine reference-build workflows live in:

- [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md)
- [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)

Whenever Apple Silicon or Rosetta x86 bring-up changes, update those docs in the same change set. Any Apple-specific disable, fallback, stub, or degraded path must still be recorded in the Apple-specific disable section of this file.

- Required historical context: GitHub issue `#936` (`https://github.com/beyond-all-reason/RecoilEngine/issues/936`)
- Apple Silicon/macOS work must stay additive and maintainable. Do not regress existing Linux, Windows, or `x86_64` behavior to make the new port work.
- Record newly discovered Apple Silicon host dependencies in `MACOS_APPLE_SILICON_SETUP.md` in the same change set that introduces them.

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
   remove stale `x86_64`-only assumptions in mac platform code and build flags, and prefer explicit Apple Silicon-compatible compiler and linker settings
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

Current Apple Silicon phase-1 progress on this machine has moved beyond planning and into a working native bring-up plus renderer-validation effort.

### Verified current status

- native macOS `arm64` configure succeeds on this machine
- `engine-dedicated`, `engine-headless`, and `engine-legacy` all build as native Apple Silicon Mach-O executables
- native targeted math-adjacent tests, blank-map smoke, and deterministic blank-map render validation are working on this machine
- the narrowed BAR real-content fixture now boots, captures a deterministic validation frame, and compares within the documented BAR-specific tolerance
- detailed machine-specific verified status, bootstrap commands, runtime requirements, and Rosetta reference-build steps are documented in [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md) and [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)

### Current phase-1 limitations

- Streflop and sync-safe multiplayer determinism are still not validated for Apple Silicon, so phase 1 must not be treated as sync-safe completion
- full native macOS graphical-client playability and rendering parity are still in progress beyond the current narrowed BAR validation fixture
- BAR content still depends on documented additive compatibility layers, proxy widgets, and selective degradations on the Apple OpenGL 4.1 path; those remain tracked in the Apple-specific disable section of this file

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
- `ValidationRenderCapture` also installs validation-only Lua timing and RNG adapters in both unsynced GUI contexts and split unsynced gadget states so `os.clock`, `math.random`, `math.randomseed`, `Spring.GetTimer`, `Spring.GetTimerMicros`, `Spring.GetFrameTimer`, `Spring.GetDrawFrame`, `Spring.GetFrameTimeOffset`, `Spring.GetLastUpdateSeconds`, and `Spring.DiffTimers` stop depending on wall-clock or per-run RNG drift during automated capture
- `ValidationRenderCapture` currently excludes screen-space UI, cursor, and post-processing draws from the automated comparison frame so repeatable render checks can focus on world-scene parity first
- `SpringApp::Reload()` and `SpringApp::Kill()` must wait for pending screenshot writes before tearing down the thread pool so validation exits with a fully written PNG instead of a truncated file

### Pass criteria

- A PNG screenshot is written into the isolated `screenshots/` directory
- When a reference image is provided, `test/validation/compare-render-images.sh` prints `Render images match.`
- The smoke wrapper leaves no newly spawned `spring*` or crash-helper processes behind after the run

### Automation hook

- Prefer `test/validation/run-legacy-render-smoke.sh` for repeatable native render validation on this machine
- Pass an optional second argument pointing at a known-good reference image when checking graphical parity for the current blank-map fixture
- `test/validation/compare-render-images.sh` currently shells into `test/validation/compare-render-images.swift`; it expects exact RGBA pixel equality by default, and only uses a tolerance when the caller explicitly sets `RECOIL_RENDER_COMPARE_MAX_DIFF_PIXELS` and `RECOIL_RENDER_COMPARE_MAX_CHANNEL_DELTA`

## BAR Real-Content Render Validation Contract

The BAR real-content render-validation path is a broader native macOS client fixture than the blank-map harness, but it still intentionally narrows the scene to keep automated verification reviewable and repeatable on this Apple Silicon machine.

### Required smoke-test shape

- Use `test/validation/run-bar-realcontent-smoke.sh` with a warmed `RECOIL_BAR_CONTENT_CACHE_DIR` when possible so repeat validation does not depend on re-downloading the BAR package and map archives
- Use the isolated BAR validation fixture staged by the smoke wrapper instead of reusing a non-isolated local Spring data dir
- Keep BAR validation engine-owned and repo-local; do not reintroduce an external macOS window-observation backend
- Keep the current validation capture frame at `60` unless the replacement frame is re-verified and documented in this file
- Only enable `RECOIL_BAR_PRESENT_CAPTURE_FRAME_COUNT` for BAR fixtures that explicitly need final-present capture review beyond the normal validation screenshot
- Treat the currently verified BAR fixture as the cached game `Beyond All Reason test-29633-5588b75` on `Angel Crossing 1.4`; if the BAR content revision changes, refresh the baseline and record the new exact version in this file
- Keep the current validation camera settings at `ValidationRenderCaptureCenterCamera = 1`, `ValidationRenderCapturePlayerStartCamera = 0`, `ValidationRenderCaptureCameraHeight = 1200`, and `ValidationRenderCaptureCameraBackOffset = 900` unless a replacement camera path is re-verified and documented in this file
- Keep staging `cont/LuaUI` into the isolated BAR fixture so the raw proxy widgets in `cont/LuaUI/Widgets/` can patch BAR's archived `gui_scavstatspanel.lua` and `gui_top_bar.lua` through `cont/LuaUI/Headers/bar_widget_proxy_loader.lua`
- Keep staging the minimal validation-only `test/validation/LuaUI/Config/BYAR.lua` as `LuaUI/Config/BYAR.lua` and `LuaAutoEnableUserWidgets = 1` so the BAR fixture keeps a narrow, repo-pinned `Top Bar` and user-widget ordering surface instead of inheriting a full host-generated BAR config

### Pass criteria

- A PNG screenshot is written into the isolated BAR `screenshots/` directory
- When a reference image is provided, the compare step reports either `Render images match.` or `Render images match within tolerance.`
- The current BAR fixture tolerance is:
  - `RECOIL_RENDER_COMPARE_MAX_DIFF_PIXELS=256`
  - `RECOIL_RENDER_COMPARE_MAX_CHANNEL_DELTA=2`
- Failed BAR compare output must continue to print the measured diff-pixel count and max channel delta so future drift is quantifiable

### Automation hook

- Prefer `test/validation/run-bar-realcontent-smoke.sh` for repeatable native BAR real-content validation on this machine
- The wrapper should keep using `test/validation/run-smoke-wrapper.sh` so failed BAR runs do not leave behind `spring*`, `ReportCrash`, or `CrashReporterSupportHelper` processes
- `test/validation/run-bar-playability-smoke.sh` and `test/validation/run-bar-observation-smoke.sh` should keep using engine-owned final-present capture only; their current contract is to stream frames from `ValidationPresentCapture*` and select the first non-black frame through `test/validation/select-first-nonblack-render-frame.sh`
- On this machine, the latest fresh BAR playability run (`recoil-bar-realcontent-smoke.UXMZK8`) still reported `Diff pixels: 492173` and `Max channel delta: 164` between the authoritative validation screenshot and the first selected non-black present frame, so the selected-present artifact is still supplementary and the normal validation screenshot remains the authoritative BAR comparison target
- Use `test/validation/analyze-render-image.sh` on BAR screenshots or selected present frames when a run is under review; the current playability gate should explicitly check for top-band HUD contrast, expected bottom-left minimap/HUD occupancy, left-middle misplacement, and overall composition skew instead of relying on visual inspection alone
- Do not treat those selected present frames as proof of actual on-screen playability on this machine unless both the image analyzer and manual review agree that the expected HUD and world composition are present
- Treat the current BAR fixture as a regression gate for the documented narrowed scene only; it is not yet a substitute for broader gameplay, replay, or full-UI rendering parity checks

## Apple Silicon Porting Principles

Apple Silicon and native macOS support should be implemented as an additive, maintainable extension of the current codebase. Do not degrade existing Linux, Windows, or x86_64 behavior in order to make the new port work. Treat previously supported platforms and their current working code paths as the baseline to preserve: reuse existing implementations and compatibility surfaces where they already behave correctly, and prefer narrow Apple-specific adaptation over replacing shared behavior outright.

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

- Legacy GLSL compatibility layer:
  the Apple core-profile path now uses a localized legacy-GLSL translation layer for both engine and Lua shaders instead of hard-failing when BAR or engine shaders still rely on compatibility-profile GLSL tokens and undefined non-`GL_*` conditional macros.
  Why: Apple OpenGL 4.1 core profile rejects compatibility-profile suffixes, legacy `gl_*` shader symbols, and a number of loose GLSL preprocessor assumptions that existing engine and BAR shaders still make.
  Verification impact: current BAR real-content smoke now gets past the earlier Apple core-profile failures for `ShadowGenFragProg`, `GrassShaderGL4`, `AoE Napalm Shader`, `GenBrdfLut`, `GenEnvLut`, `ShieldSphereColor`, `Bloom Combine Shader`, the earlier `Contrast Adaptive Sharpen` preprocessor failure, and the earlier `SMFFragProg` shadow sampler compile failure because `LegacyGlslCompat.h` now adapts legacy `shadow2DProj` through `textureProj`. BAR capture still relies on the documented BAR-specific image tolerance, and the layer does not yet prove full gameplay rendering parity.
  Exit criteria: keep the translation localized and additive while BAR render validation expands; either prove the translated surface matches known-good references strongly enough to justify the adapter long-term or replace the remaining translated surfaces with validated cross-platform shader updates.

- Shader preprocessor conditional-defaulting:
  engine and Lua shader compilation currently keep the additive undefined-macro defaulting path, but that path is now shared through `Rendering/Shaders/ShaderPreprocessorUtils.h` and strips comments plus skips `defined(...)` operands before collecting identifiers.
  Why: BAR and existing engine shader sources still rely on undefined non-`GL_*` conditional macros in some places, but the earlier local parsers were loose enough to corrupt valid GLSL by inventing defaults from comment text or `defined()` operands.
  Verification impact: current BAR real-content smoke and `test_ShaderPreprocessorUtils` now prove the earlier `Contrast Adaptive Sharpen` failure mode is fixed for both engine and Lua shader compilation, but the broader automatic-defaulting behavior still remains a compatibility fallback rather than proof that every shader declares its capability surface explicitly.
  Exit criteria: keep the shared preprocessor helper only as long as current shader sources still depend on automatic undefined-macro defaults, and narrow or remove that fallback once the affected shader surfaces are explicit enough to compile without it.

- Projectile effects shader path:
  the Apple core-profile path now uses a localized matrix-uniform adapter for the `ProjFX*` shaders instead of relying on `gl_ModelViewMatrix` and `gl_ProjectionMatrix`.
  Why: Apple core-profile GLSL does not expose the fixed-function matrix state that the existing projectile-effects shaders expect, but the shader surface is otherwise narrow enough to preserve through explicit uniform uploads without rewriting the shared renderer around it.
  Verification impact: BAR startup and render capture now get past the earlier `ProjFXVertProg` compilation failure on this machine, but projectile-effect rendering parity is not yet treated as proven beyond the current smoke coverage.
  Exit criteria: keep the adapter localized until the same shader surface is either modernized cross-platform or verified against known-good references strongly enough that the adapter can be justified as the long-term macOS preservation layer.

- Lua GL4 draw submission:
  the Apple core-profile path now emulates missing `GL_ARB_base_instance` and `GL_ARB_multi_draw_indirect` behavior for Lua VAO draws instead of disabling those paths outright.
  Why: BAR's Lua GL4 stack uses modern instanced and indirect draw surfaces, while Apple OpenGL 4.1 lacks the newer draw entry points available on Linux and Windows GL 4.2+ or 4.3+ drivers.
  Verification impact: BAR real-content smoke now gets past the prior Lua VAO capability failures and can render a frame, but performance and behavioral parity for these emulated draw paths are not yet treated as fully proven across broader gameplay scenes.
  Exit criteria: verify the additive draw-emulation path against known-good references for the affected widgets and keep it localized so existing higher-capability platforms continue to use their native fast path unchanged.

- BAR raw-widget proxy surface:
  the BAR real-content fixture currently stages raw LuaUI widget proxies from `cont/LuaUI/Widgets/` that shadow BAR's archived `gui_scavstatspanel.lua` and `gui_top_bar.lua` and patch them through `cont/LuaUI/Headers/bar_widget_proxy_loader.lua`.
  Why: the currently validated BAR content revision still carries widget-source defects that are narrower and cheaper to patch through repo-local raw overrides than to paper over inside shared engine code or by forking BAR widget names and ordering.
  Verification impact: a successful BAR smoke currently proves the native macOS client plus these localized raw widget proxies can boot BAR content and capture the validation frame; it does not yet prove that the unmodified BAR archive widgets run cleanly on this fixture.
  Exit criteria: remove each raw proxy once the corresponding BAR widget source is fixed upstream or no longer needed for the validated fixture, then re-run the BAR smoke and document the narrower override surface in this file.

- BAR health-bars fallback:
  the macOS Apple Silicon BAR validation fixture now shadows `gui_healthbars_gl4.lua` with a repo-local raw proxy that enables the engine `showhealthbars` / `showrezbars` status-bar path and removes the GL4 widget on load.
  Why: BAR's `Health Bars GL4` widget currently hard-fails on Apple OpenGL 4.1 because its shader path still depends on unsupported GL4-era storage-buffer behavior, but the engine already ships a simpler status-bar path that is better than losing health and rez bars entirely during playability validation.
  Verification impact: until a successful GUI-session BAR run re-verifies this proxy, it should be treated as a maintainable fallback rather than proof that the original BAR GL4 health-bar widget now works on macOS.
  Exit criteria: replace this fallback only after either the BAR GL4 health-bar widget runs correctly on Apple OpenGL 4.1 or a stronger cross-platform replacement path is verified for the macOS fixture.

- BAR SSBO overlay fallbacks:
  the macOS Apple Silicon BAR validation fixture now shadows `gui_selectedunits_gl4.lua`, `gui_unit_energy_icons.lua`, `gui_allyselectedunits.lua`, `gfx_paralyze_effect.lua`, `gui_unit_group_number.lua`, `gui_rank_icons_gl4.lua`, `gui_sensor_ranges_radar_preview.lua`, `gui_sensor_ranges_jammer.lua`, `gui_sensor_ranges_sonar.lua`, `gui_sensor_ranges_radar.lua`, `gui_sensor_ranges_los.lua`, `gui_resurrection_halos_gl4.lua`, `gfx_airjets_gl4.lua`, `gui_ground_ao_plates_features_gl4.lua`, and `gfx_orb_effects_gl4.lua` with repo-local raw proxies that log a warning and remove the original GL4 widgets on load.
  Why: these BAR overlays and visual-effect widgets currently fail at startup on Apple OpenGL 4.1 because they depend on `GL_ARB_shader_storage_buffer_object`, and disabling them through repo-local widget proxies is a smaller, more maintainable additive surface than widening the shared renderer just to preserve optional overlays during the Apple Silicon bring-up.
  Verification impact: until a successful GUI-session BAR run re-verifies these proxies, they should be treated as documented degradation paths rather than proof that the original BAR GL4 widgets now work on macOS.
  Exit criteria: replace each proxy only after the corresponding BAR widget runs correctly on Apple OpenGL 4.1 or a stronger cross-platform fallback is verified for the macOS fixture.

- BAR LuaUI config dependency:
  `test/validation/run-bar-realcontent-smoke.sh` currently stages `cont/LuaUI`, copies the minimal validation-only `test/validation/LuaUI/Config/BYAR.lua` into `LuaUI/Config/BYAR.lua`, and sets `LuaAutoEnableUserWidgets = 1`, so the validated widget set, `Top Bar` ordering, and BAR user-widget path now follow a narrower repo-pinned fixture instead of BAR's larger generated runtime config.
  Why: the current fixture still wants BAR's user-widget path enabled, but it now needs a minimal deterministic `BYAR.lua` so validation does not drift with prior BAR sessions or host-saved widget state while the repo-local raw-widget hotfixes stay in place.
  Verification impact: BAR smoke currently proves this hybrid path of repo-local raw overrides plus the staged minimal validation `BYAR.lua`, not a fully user-config-independent BAR bootstrap or a proof that every BAR widget ordering path is stable without the pinned fixture.
  Exit criteria: keep the staged validation-only `BYAR.lua` narrow and documented until BAR smoke remains stable without it or until a stronger long-term validation config story replaces this minimal pinned fixture.

- BAR GL4 widget surface:
  BAR real-content startup currently disables a number of optional GL4 Lua widgets and effects on the native macOS Apple Silicon path.
  Why: Apple OpenGL tops out at GLSL 4.10 and does not expose SSBO support on this path, while BAR currently ships several Lua GL4 shaders and widgets that require true SSBO-backed `buffer` blocks or still assume newer or legacy GLSL/profile semantics than the current additive translation layer covers.
  Verification impact: these are current BAR content and runtime parity gaps rather than engine build blockers. A successful BAR real-content smoke currently proves the native macOS client can boot BAR content and render a frame, but it does not yet prove parity for the affected higher-end Lua GL4 widgets, UI, or post-processing behavior. As of the current verified BAR smoke, the still-failing or removed surfaces include `ResurrectionHalosShader GL4`, `selectedUnitsGroundShader GL4`, `energy iconsShader GL4`, `Health Bars Shader GL4`, `JetShader GL4`, `Ground AO Plates FeaturesShader GL4`, `orbShader GL4`, `allySelectedUnitsShader GL4`, `unitGroupsShader GL4`, `Rank IconsShader GL4`, and the sensor-range stencil shaders.
  Exit criteria: add additive compatibility adapters or capability-translation fixes that let the affected BAR Lua GL4 paths either run correctly on Apple OpenGL 4.1 or degrade in a documented, verified way against a known-good reference, and remove widgets from this note only after the render smoke demonstrates the change rather than assuming it.

- BAR validation compare tolerance:
  `test/validation/run-bar-realcontent-smoke.sh` currently allows the compare helper to accept up to `256` differing pixels with a maximum per-channel delta of `2`.
  Why: after the current validation adapters and earlier BAR capture frame are applied, repeated native BAR captures still show tiny per-pixel rounding drift even when the scene is visually identical, and a very tight tolerance keeps the regression gate useful without masking meaningful rendering changes.
  Verification impact: a successful BAR real-content compare now proves near-identical output for the current narrowed fixture, not byte-for-byte identity.
  Exit criteria: remove the BAR-specific tolerance once exact repeated capture becomes stable, or replace it with a stronger reference-backed parity mechanism that makes the tolerance unnecessary.

- BAR engine-owned capture backend:
  BAR validation must stay inside the engine and repo-local smoke harnesses; external host window-observation helpers are no longer part of the supported validation contract.
  Why: the Apple Silicon port needs a reproducible, maintainable validation story that travels with the repo instead of depending on host TCC permissions or extra desktop automation tools.
  Verification impact: BAR validation currently proves what the engine-owned screenshot and final-present capture paths can reproduce for the narrowed fixture, not an independently observed host window.
  Exit criteria: keep the validation story engine-owned and repo-local, and strengthen the BAR render output itself until the analyzer plus manual review agree that the narrowed fixture shows the expected HUD and world composition.

- BAR engine-backed playability capture:
  `test/validation/run-bar-playability-smoke.sh` and `test/validation/run-bar-observation-smoke.sh` currently rely on the engine screenshot hook plus streamed `ValidationPresentCapture*` frames, then select the first non-black present frame through `test/validation/select-first-nonblack-render-frame.sh`.
  Why: the playability wrappers now need an engine-owned approximation of what reaches the visible window, and the earliest present frames can still be all black before the BAR scene is ready.
  Verification impact: a successful engine-backed playability capture now proves that the native macOS client can render, write, and post-process BAR validation frames under the playability fixture, and that the present path can match the normal screenshot hook; it still does not prove playability unless the resulting BAR frame also passes the repo-local HUD and composition checks.
  Exit criteria: keep the current engine-owned capture flow, but bring the BAR frame itself to a state where the analyzer plus manual review show a believable top bar, sane minimap/HUD placement, and a readable world view for the narrowed fixture.

- Validation render scope:
  `ValidationRenderCapture` currently suppresses screen-space UI, cursor, and screen-post passes during automated render comparison.
  Why: the current Apple Silicon/macOS graphical validation effort is still stabilizing repeatable world-scene captures first, and these screen-space surfaces remain more sensitive to session timing and host interaction than the world draw.
  Verification impact: passing automated render validation currently proves the captured world scene matches the current baseline for the covered fixture, but it does not yet prove parity for UI, cursor, or post-processing output.
  Exit criteria: restore these surfaces to automated parity coverage once they have a stable fixture or a dedicated comparison harness that can verify them without reintroducing flaky captures.

- Validation capture camera path:
  the automated render-capture path currently relies on explicit camera steering through `ValidationRenderCaptureCenterCamera`, `ValidationRenderCapturePlayerStartCamera`, `ValidationRenderCaptureCameraHeight`, and `ValidationRenderCaptureCameraBackOffset`, and the BAR real-content fixture uses the center-camera branch rather than BAR's own startup camera state.
  Why: BAR startup camera behavior and local player start positions are not stable enough for a repeatable regression frame on this machine, so the validation hook now forces a deterministic center-map capture path with documented offsets.
  Verification impact: successful BAR render validation currently proves the documented center-camera scene matches the baseline within tolerance, not that arbitrary startup-camera scenes or player-start-camera captures are already stable on this macOS path.
  Exit criteria: keep the explicit camera steering until BAR validation no longer depends on it or until a broader replay or scenario-based capture harness can verify camera parity without relying on a forced center-map view.

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
- Reuse existing working code paths, renderer surfaces, and validation hooks wherever they already provide the closest practical behavior on supported platforms; prefer adapting around them over cloning or replacing them
- When x86/SSE-specific code blocks Apple Silicon support, prefer introducing a narrow abstraction layer such as a SIMD compatibility header or platform-selected implementation file instead of scattering `#ifdef` logic everywhere
- When macOS graphics or windowing behavior differs from other platforms, isolate that behavior behind platform-specific entry points or renderer adapters where practical
- Minimize the changed surface area of each Apple Silicon/macOS step so previously supported platforms continue to exercise the same implementation unless a broader change is deliberate and verified
- Do not remove or weaken existing implementations just because Apple Silicon requires a different path
- Aim for the closest practical behavior to the existing supported platforms, and document any remaining drift rather than widening the rewrite surface prematurely
- If a compatibility or translation layer is introduced, it must be documented clearly enough that future maintainers can understand what it preserves, what it translates, and how it is verified

### Maintainability rules

- Keep Apple Silicon and macOS-specific logic localized to the smallest reasonable surface area
- Prefer reusing an existing supported implementation plus a narrow adapter over introducing a second full path that duplicates behavior
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
