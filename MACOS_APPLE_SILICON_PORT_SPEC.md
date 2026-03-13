# macOS Apple Silicon arm64 Port Spec

This document is the canonical spec for getting RecoilEngine building, validating, and comparing on native macOS Apple Silicon `arm64`.

It is meant to be thorough enough that another developer can pick up the work without relying on local terminal history.

For machine-specific bootstrap details, concrete package versions, and host-prefix notes, see:

- [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md)
- [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)

## Scope

This spec covers:

- native macOS Apple Silicon `arm64` builds for `engine-dedicated`, `engine-headless`, and `engine-legacy`
- repo-local smoke, render, and playability validation on macOS
- same-machine Rosetta `x86_64` comparison builds used as a reference path
- the current fallback `amd64-linux` comparison path in Docker
- the current additive compatibility layers and documented degradations needed to keep the port maintainable

This spec does not replace the machine setup docs. It defines the engineering contract, validation contract, and current known status.

## Goals

- Produce native macOS Apple Silicon `arm64` engine binaries without regressing existing Linux, Windows, or `x86_64` behavior.
- Keep the port additive and maintainable by isolating Apple-specific behavior behind narrow hooks, adapters, and compatibility layers.
- Validate each step with repo-local automation instead of ad hoc manual observation.
- Compare Apple Silicon output against an existing supported implementation before trusting adapter-backed behavior.
- Document every Apple-specific dependency, fallback, disable, and exit criterion in-repo.

## Non-Goals

- Do not treat a Rosetta-only or Docker-only build as completion for the Apple Silicon port.
- Do not use external host capture tools as part of the supported validation contract.
- Do not rewrite large shared renderer surfaces just to make macOS work if a localized adapter can preserve behavior.
- Do not silently disable subsystems to get a build through.
- Do not accept successful compilation as proof of determinism, rendering parity, or playability.

## Historical Context

Before making native macOS or Apple Silicon changes, review:

- GitHub issue `#936`: `https://github.com/beyond-all-reason/RecoilEngine/issues/936`

That issue is required context for prior macOS and `arm64` bring-up attempts, rejected paths, and determinism concerns.

Historically rejected or deprioritized approaches:

- making Zink, MoltenVK, or a Vulkan translation stack the primary phase-1 path
- relying on external macOS screen-recording or host window-observation tools
- globally switching the normal shell to Rosetta Homebrew
- broad shared-code rewrites when a narrow platform adapter is sufficient

## Maintainability Rules

- Preserve existing supported platforms first. Apple Silicon support must layer on top of the current codebase, not replace it.
- Prefer platform-specific hooks, adapter headers, translation shims, proxy widgets, and dependency-scoping fixes over invasive shared-code churn.
- Keep existing platform behavior unchanged unless the change is intentionally validated cross-platform.
- Keep Apple-specific logic localized to the smallest reasonable surface area.
- Record every newly discovered Apple Silicon dependency in [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md) in the same change set.
- Record every Rosetta-specific bootstrap or linker requirement in [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md) in the same change set.
- Record every Apple-specific disable, fallback, stub, degradation, or adapter in this spec immediately when it is introduced or discovered.
- Keep committed docs and scripts free of workspace-specific absolute paths.

## Machine And Tooling Baseline

The concrete machine baseline for this workspace lives in [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md).

At a minimum, the current Apple Silicon validation surface depends on:

- a full Xcode toolchain with `clang`, `swift`, and the macOS graphics frameworks needed by the Swift validation helpers
- CMake
- Homebrew packages for SDL2, Freetype, Fontconfig, Ogg, Vorbis, DevIL, SevenZip, and OpenAL Soft
- a visible macOS GUI session for graphical-client smoke and render validation
- repo-local validation helpers under `test/validation/`
- `tools/pr-downloader` for BAR real-content validation

The same-machine Rosetta comparison path additionally depends on:

- a separate Rosetta `x86_64` Homebrew installation
- an `x86_64`-clean dependency graph
- the `tools/pr-downloader` submodule revision documented in [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)

## Current Verified State

Current known-good Apple Silicon bring-up status:

- native macOS `arm64` configure succeeds
- `engine-dedicated`, `engine-headless`, and `engine-legacy` build as native Apple Silicon executables
- the dedicated blank-map smoke passes
- the headless blank-map smoke passes
- the legacy blank-map GUI smoke passes in a visible macOS GUI session
- the blank-map render smoke captures deterministic screenshots and can compare them exactly
- the BAR real-content smoke boots a narrowed BAR fixture, captures a deterministic validation frame, and compares it within the documented BAR-specific tolerance
- the engine-owned present-capture path is working and can emit present frames for BAR playability review
- the same-machine Rosetta `x86_64` client and `pr-downloader_cli` now build on this machine and can be used as the preferred render-comparison reference path

Current known limitations:

- streflop-backed sync-safe determinism is not yet re-established for Apple Silicon
- the Apple Silicon BAR fixture is still a narrowed validation scene, not full gameplay parity
- the selected first non-black present frame is still supplementary; the authoritative comparison target remains the normal validation screenshot
- several BAR GL4 and SSBO-backed widgets still rely on documented fallbacks or removals
- broader gameplay, replay, and full-UI parity are still unproven

## Primary Risks

The Apple Silicon port must be treated as a risk-driven effort. A successful compile is not enough.

Primary risks:

- determinism regression
- rendering parity regression
- existing-platform regression
- performance regression
- long-term maintenance burden

Required mitigations:

- treat determinism, rendering parity, and existing-platform stability as separate validation gates
- do not rely on a compatibility layer that has not been verified against a known-good baseline
- prefer narrow adapter tests and localized fixes over broad rewrites that are difficult to validate
- record known deviations explicitly instead of silently accepting them during bring-up
- if a change improves Apple Silicon support but creates unverified drift elsewhere, treat that as an unresolved blocker rather than acceptable progress

## Implementation Workstreams

### 1. Build And Dependency Scoping

Required direction:

- keep Apple-specific build changes scoped so Linux, Windows, and existing `x86_64` builds keep their current defaults
- scope X11 and GLX requirements away from Apple
- keep Rosetta `x86_64` dependency resolution separate from native Apple Silicon dependency resolution
- record new host packages immediately when discovered

Key rule:

- dependency fixes must narrow platform selection, not widen cross-platform fragility

### 2. SIMD, Floating Point, And Determinism

Required direction:

- isolate x86 intrinsic assumptions behind a narrow compatibility layer
- prefer a small abstraction boundary over scattered `#ifdef` logic
- restore sync-sensitive math carefully and only with explicit validation

Validation requirement:

- math adapters need targeted tests
- synced simulation work needs replay, sync-hash, or equivalent determinism validation

### 3. Native macOS GL Core-Profile Compatibility

Required direction:

- keep Apple OpenGL compatibility work localized
- translate or adapt compatibility-only shader and API assumptions only where needed
- avoid broad renderer rewrites until the localized compatibility surface is no longer maintainable

This currently includes:

- core-profile context bring-up
- localized legacy GLSL translation
- shader preprocessor normalization
- matrix-uniform adapters for legacy shader surfaces
- UBO rebinding compatibility
- Lua GL4 draw emulation for missing base-instance and indirect-draw capabilities

### 4. BAR Fixture And Content Compatibility

Required direction:

- keep BAR-specific validation behavior in repo-local fixtures and raw widget proxies rather than spreading BAR quirks into shared engine code
- keep the validation fixture narrow, reproducible, and documented
- remove each BAR proxy when upstream content or a stronger engine-side fix makes it unnecessary

### 5. Engine-Owned Validation And Analysis

Required direction:

- keep smoke and render validation inside the engine plus repo-local scripts
- keep cleanup and crash-helper suppression in the wrapper, not as ad hoc manual steps
- keep comparison and analysis scripts repo-local and automation-friendly

This currently includes:

- engine-owned screenshot capture
- engine-owned final-present frame capture
- exact and tolerance-based RGBA image comparison
- first-non-black present-frame selection
- ROI-based screenshot analysis for HUD and composition review

### 6. Same-Machine Reference Builds

Required direction:

- prefer same-machine Rosetta `x86_64` macOS comparison over cross-OS references
- use the same isolated BAR fixture, same cache, same camera settings, and same engine-owned screenshot path on both architectures
- use Docker `amd64-linux` only as a fallback reference when the Rosetta path is unavailable

### 7. Clean Upstream Control Checkout

Use a clean upstream checkout as a control whenever the question is:

- did this Apple Silicon branch introduce a regression that is not present upstream
- is a behavior difference caused by the porting work or by existing engine state
- does an unchanged build path still behave the same on this machine

If a sibling checkout is available, refer to it by a repo-relative path such as:

- `../recoil_engine_upstream/RecoilEngine`

Important rules:

- treat the clean upstream checkout as a comparison source, not a hard dependency of the Apple Silicon workflow
- do not commit absolute workspace paths for that checkout
- when possible, build binaries from the clean upstream checkout and run this repo's validation harness against those binaries to isolate whether a regression belongs to this branch or already exists upstream
- use the clean upstream checkout to spot regressions in existing `x86_64` and non-Apple paths before assuming an Apple-specific fix is safe

## Validation Matrix

### Common Validation Rules

These rules apply to every supported Apple Silicon validation path:

- use isolated data directories
- prefer the repo-local smoke wrappers over hand-built fixtures
- run through `test/validation/run-smoke-wrapper.sh`
- leave no newly spawned `spring*` or crash-helper processes behind
- do not depend on a user-global Spring data directory
- do not depend on external host capture tools
- treat a visible GUI session as required for graphical validation
- on macOS, confirm the repo-local AppKit probe (`test/validation/check-macos-gui-session.sh --count-only`) reports at least one `NSScreen` before treating GUI-smoke failures as engine regressions
- if the AppKit probe reports zero screens, rerun the same smoke from an interactive Terminal or iTerm window in the desktop session rather than adding engine-side workarounds for a headless launch context
- use repo-relative paths and environment variables, not workspace-specific absolute paths

### Dedicated Blank Smoke

Script:

- `test/validation/run-dedicated-blank-smoke.sh`

Purpose:

- prove native dedicated startup on Apple Silicon using a hermetic blank-map fixture

Command shape:

```bash
./test/validation/run-dedicated-blank-smoke.sh <spring-dedicated> [timeout-seconds]
```

Required fixture behavior:

- isolated data dir
- staged base content
- minimal local game archive
- `InitBlank=1`

Pass criteria:

- blank map generation succeeds
- start script parses
- infolog contains `[script-checksums]`
- infolog contains `starting server...`
- infolog contains `Server started on port`
- infolog contains `recording demo:`
- a demo file is written

### Headless Blank Smoke

Script:

- `test/validation/run-headless-blank-smoke.sh`

Purpose:

- prove native headless startup on Apple Silicon using the same hermetic blank-map model

Command shape:

```bash
./test/validation/run-headless-blank-smoke.sh <spring-headless> [timeout-seconds]
```

Pass criteria:

- startup markers appear
- demo recording occurs
- no immediate fatal exit

### Legacy Blank Smoke

Script:

- `test/validation/run-legacy-blank-smoke.sh`

Purpose:

- prove the native graphical client can create a macOS window, initialize SDL/OpenGL, and remain alive long enough to be meaningful

Command shape:

```bash
./test/validation/run-legacy-blank-smoke.sh <spring> [timeout-seconds]
```

Required fixture behavior:

- isolated data dir
- staged `fonts/`
- flat `springsettings.cfg`
- `ForceCoreContext = 1`
- blank-map start script includes `OnlyLocal=1`
- visible GUI session

Pass criteria:

- infolog contains `SDL version :`
- infolog contains `GL version  :`
- infolog contains `Initialized OpenGL Context:`
- infolog contains `[PreGame::GameDataReceived] recording demo to`
- the process remains alive for the stabilization window
- the infolog does not contain `Fatal: [ExitSpringProcess]`
- the infolog does not contain `Segmentation fault`
- the infolog does not contain `caught opengl_error`
- a demo file is written

### Blank-Map Render Smoke

Script:

- `test/validation/run-legacy-render-smoke.sh`

Purpose:

- provide a deterministic narrow graphical regression harness for the native macOS client

Command shape:

```bash
./test/validation/run-legacy-render-smoke.sh <spring> [reference-image]
```

Optional baseline export:

```bash
RECOIL_RENDER_CAPTURE_WRITE_BASELINE=<output-image> \
./test/validation/run-legacy-render-smoke.sh <spring> [reference-image]
```

Required fixture behavior:

- same isolated blank-map fixture as legacy blank smoke
- `ValidationRenderCapture = 1`
- `ValidationRenderCaptureFrame = 30`

Authoritative artifact:

- the normal validation screenshot written to `screenshots/`

Pass criteria:

- screenshot exists
- compare script reports exact match when a reference image is provided

### BAR Real-Content Smoke

Script:

- `test/validation/run-bar-realcontent-smoke.sh`

Purpose:

- validate a broader, real-content native BAR fixture on Apple Silicon without leaving the repo-local harness

Command shape:

```bash
./test/validation/run-bar-realcontent-smoke.sh <spring> <pr-downloader> [reference-image] [timeout-seconds]
```

Current important environment variables:

- `RECOIL_BAR_CONTENT_CACHE_DIR`
- `RECOIL_BAR_SKIP_DOWNLOAD`
- `RECOIL_BAR_RAPID_TAG`
- `RECOIL_BAR_MAP_SEARCH_NAME`
- `RECOIL_BAR_MAP_SCRIPT_NAME`
- `RECOIL_BAR_CAPTURE_FRAME`
- `RECOIL_BAR_VALIDATION_HIDE_INTERFACE`
- `RECOIL_BAR_VALIDATION_CENTER_CAMERA`
- `RECOIL_BAR_VALIDATION_PLAYER_START_CAMERA`
- `RECOIL_BAR_VALIDATION_SCENE_ONLY`
- `RECOIL_BAR_VALIDATION_HIDE_CURSOR`
- `RECOIL_BAR_VALIDATION_CAMERA_HEIGHT`
- `RECOIL_BAR_VALIDATION_CAMERA_BACK_OFFSET`
- `RECOIL_BAR_RENDER_MAX_DIFF_PIXELS`
- `RECOIL_BAR_RENDER_MAX_CHANNEL_DELTA`
- `RECOIL_BAR_SMOKE_HIDDEN`

Required fixture behavior:

- isolated BAR data dir
- warmed cache when possible
- use `RECOIL_BAR_SKIP_DOWNLOAD=1` for repeat runs against a known-good warmed cache
- repo-local `cont/LuaUI` overrides staged into the fixture
- minimal validation-only `BYAR.lua`
- engine-owned screenshot capture
- BAR UI diagnostics emitted after the run

Current comparison contract:

- the normal validation screenshot is authoritative
- current BAR tolerance is `256` diff pixels and max channel delta `2`
- failed compares must continue printing measured drift

### BAR Playability And Observation Capture

Scripts:

- `test/validation/run-bar-playability-smoke.sh`
- `test/validation/run-bar-observation-smoke.sh`

Purpose:

- capture a broader visible-window BAR fixture plus streamed present frames for playability review

Command shape:

```bash
./test/validation/run-bar-playability-smoke.sh <spring> <pr-downloader> [reference-image] [timeout-seconds]
```

Current behavior:

- enables present-frame capture by default
- keeps the window visible
- disables scene-only mode
- captures later than the narrow BAR fixture

Important rule:

- selected present frames are supplementary review artifacts only
- the authoritative comparison target remains the normal validation screenshot from `ValidationRenderCapture`

Current supporting tools:

- `test/validation/select-first-nonblack-render-frame.sh`
- `test/validation/analyze-render-image.sh`

Playability review gate:

- the selected frame must look plausible under both manual review and the ROI analyzer
- expected top bar, minimap, lower-left HUD, and world composition must be present

### Same-Machine Rosetta `x86_64` Reference Comparison

Preferred reference path:

- build the `x86_64` legacy client and `pr-downloader_cli` under Rosetta
- reuse the same BAR fixture and compare the same validation screenshot path

Command shape:

```bash
RECOIL_BAR_CONTENT_CACHE_DIR=<shared-cache-dir> \
RECOIL_BAR_SKIP_DOWNLOAD=1 \
RECOIL_RENDER_CAPTURE_WRITE_BASELINE=<x86-reference-image> \
./test/validation/run-bar-realcontent-smoke.sh <x86-spring> <x86-pr-downloader> [reference-image] [timeout-seconds]
```

Follow-up Apple Silicon compare:

```bash
RECOIL_BAR_CONTENT_CACHE_DIR=<shared-cache-dir> \
RECOIL_BAR_SKIP_DOWNLOAD=1 \
./test/validation/run-bar-realcontent-smoke.sh <arm64-spring> <native-pr-downloader> <x86-reference-image> [timeout-seconds]
```

Required comparison rules:

- use the same cache and same content revision
- use the same camera path and capture frame
- compare validation screenshots, not selected present frames
- keep Rosetta bootstrap details in [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)

### Clean Upstream Comparison

Preferred use:

- build an unchanged upstream control binary from a clean checkout when you need to confirm whether a regression is new to this branch

Command shape:

```bash
cd ../recoil_engine_upstream/RecoilEngine
cmake -S . -B <upstream-build-dir> <args>
cmake --build <upstream-build-dir> --target <target> -j<jobs>
```

Then run this repo's validation harness against the upstream-built binary from this repo root:

```bash
./test/validation/run-legacy-render-smoke.sh <upstream-built-spring> [reference-image]
```

or:

```bash
./test/validation/run-bar-realcontent-smoke.sh <upstream-built-spring> <compatible-pr-downloader> [reference-image] [timeout-seconds]
```

Use this comparison to answer:

- does the unchanged upstream client render the same scene differently on this machine
- did this branch regress an existing supported path
- is the validation drift branch-specific or already present in the clean control

### Docker `amd64-linux` Fallback Reference

Fallback only:

- use when the same-machine Rosetta path is unavailable or broken

Constraint:

- this is a cross-OS reference and should not replace the same-macOS Rosetta reference when Rosetta is working

## Validation Tools Inventory

Core wrappers and helpers:

- `test/validation/run-smoke-wrapper.sh`
- `test/validation/report-bar-ui-diagnostics.sh`

Image and frame tools:

- `test/validation/compare-render-images.sh`
- `test/validation/compare-render-images.swift`
- `test/validation/select-first-nonblack-render-frame.sh`
- `test/validation/select-first-nonblack-render-frame.swift`
- `test/validation/analyze-render-image.sh`
- `test/validation/analyze-render-image.swift`

Current authoritative artifacts:

- validation screenshots written by the engine screenshot hook

Current supplementary artifacts:

- selected first non-black present frames

## Incremental Verification Requirements

Apple Silicon support must be developed incrementally with automated validation at each step.

### Baseline-First Workflow

- before changing a behavior-sensitive subsystem, capture a baseline from an implementation that is already considered correct
- use the current implementation on an existing supported platform or the clean upstream control checkout whenever possible
- do not replace a subsystem first and plan to validate later

### Verification Expectations By Area

- math and SIMD adapters need targeted tests across representative and numerically sensitive inputs
- synced simulation work needs replay, sync-hash, or equivalent deterministic checks
- rendering adapters need repeatable scene or frame comparisons against a known-good baseline
- build-system changes need verification that existing supported targets still configure and build

### Rendering Verification Requirements

- use repeatable scenes or scripted replays, not ad hoc screenshots
- capture the same frame or frame set from both the baseline path and the Apple Silicon path
- compare outputs with an automated image-diff step
- define any tolerance explicitly and record why it exists
- do not accept visual changes as harmless unless they are understood and documented

### Incremental Delivery Rules

- land porting work in small, reviewable steps with validation attached
- each new hook, shim, or compatibility layer must have a clear verification story
- if a step cannot be validated automatically yet, document the gap and minimize the blast radius
- do not proceed to broader graphical-client milestones unless lower-level runtime validation is already credible

## Known Degradations, Adapters, And Exit Criteria

Every entry in this registry must preserve four things:

- the affected surface and its category
- why the Apple-specific behavior currently exists
- what verification impact it has
- what the exit criteria are for replacing it with a stronger implementation

If any future edit compresses an entry so far that one of those four pieces becomes unclear, expand the entry instead of shortening it further.

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

- Validation splash-screen bypass:
  the validation-only `ValidationDisableSplashScreen` config now lets the legacy-client smoke harness skip the normal splash-screen swap loop during `SpringApp::InitFileSystem()`, and the macOS legacy validation scripts stage that flag in their isolated `springsettings.cfg`.
  Why: native macOS Apple Silicon automation can hang inside the splash `SwapBuffers()` path before game load, while ordinary interactive users still need the existing splash-screen behavior unchanged by default.
  Verification impact: a successful legacy smoke with this flag proves the client can finish filesystem initialization and continue into the actual smoke fixture without relying on splash-screen presents; it does not change normal startup behavior for non-validation runs.
  Exit criteria: keep this bypass validation-only unless the underlying Cocoa/SDL splash present hang is fixed strongly enough that the smoke harness can return to the default splash path without reintroducing startup hangs.

- Validation VSync pin:
  the validation-only `ValidationForceDisableVSync` config now keeps `VSync` forced to `0` for macOS GUI smoke runs, even if BAR or other runtime config paths try to re-enable adaptive swap during load.
  Why: on this Apple Silicon/macOS path, validation runs can reach `GameDataReceived` and then wedge in `Cocoa_GL_SwapWindow` once content flips `VSync` back to adaptive; normal gameplay defaults still need to remain unchanged outside validation.
  Verification impact: passing macOS GUI smoke with this flag proves the validation harness can progress through load, capture frames, and shut down without the late swap-interval stall; it does not claim that normal user-facing `VSync` behavior is already fixed.
  Exit criteria: remove this validation-only pin only after the underlying post-load Cocoa swap stall is fixed well enough that BAR and the legacy smoke fixtures can keep their normal `VSync` behavior without hanging.

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

### Required Implementation Approach

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

### Maintainability Rules

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

## Reproducibility Rules

- Keep this spec current whenever the Apple Silicon validation contract changes.
- Keep [MACOS_APPLE_SILICON_SETUP.md](MACOS_APPLE_SILICON_SETUP.md) current whenever host dependencies or machine-specific prerequisites change.
- Keep [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md) current whenever the Rosetta bootstrap, linker inputs, or submodule requirements change.
- Pin or cache BAR content before trusting repeated comparisons.
- Do not compare moving BAR heads without recording the exact validated version.
- Capture a baseline before changing a behavior-sensitive subsystem.
- Add targeted tests for each new compatibility layer where possible.
- Treat determinism, rendering parity, and existing-platform stability as separate gates.
- Keep committed docs and scripts free of workspace-specific absolute paths.

## Open Blockers To "Playable End To End"

- restore or replace sync-safe determinism validation for Apple Silicon
- prove a believable playable BAR frame with the expected top bar, minimap, lower-left HUD, and world composition
- reduce or remove BAR GL4 and SSBO fallback surfaces
- revalidate sky, dynamic-light, and depth-copy dependent rendering paths
- expand from the current narrowed BAR fixture to broader gameplay, replay, or scenario-based comparisons
- prove that Apple Silicon behavior remains compatible with existing supported platforms as the compatibility surface narrows

## Practical Next-Step Sequence

1. Keep the Rosetta `x86_64` reference build healthy and use it as the primary rendering baseline.
2. Tighten the BAR playability fixture until the analyzer and manual review both accept the output as believable.
3. Replace BAR fallbacks one surface at a time, validating each against the Rosetta reference before removing the note from this spec.
4. Reintroduce determinism work only after the current graphical validation story is stable enough to isolate math and sync regressions.
5. Continue landing changes in small, reviewable increments with validation attached to each step.
