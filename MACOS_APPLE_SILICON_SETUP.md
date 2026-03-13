# macOS Apple Silicon Setup

This document records the repo-local machine context, Apple Silicon bootstrap, runtime requirements, and current Apple Silicon bring-up status for this workspace.

The canonical Apple Silicon engineering and validation contract now lives in [MACOS_APPLE_SILICON_PORT_SPEC.md](MACOS_APPLE_SILICON_PORT_SPEC.md). Keep this file focused on concrete machine bootstrap and runtime requirements.

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
- `test/validation/compare-render-images.sh` now compares decoded RGBA pixels through a localized Swift/ImageIO helper instead of relying on `sips` image-format normalization
- the modern info-texture path now uses a localized GLSL-version adapter so its core-safe fullscreen shaders can promote from GLSL 1.30 to 1.50 when the macOS client is forced onto an OpenGL core profile
- the native macOS core-profile path now includes additive Lua and shader compatibility layers for Apple OpenGL 4.1: program validation auto-binds a temporary VAO when needed, Lua VAO draws emulate missing `ARB_base_instance` and `ARB_multi_draw_indirect` behavior per draw, and Lua shader compilation now normalizes GLSL versions, strips unsupported `layout(binding=...)` qualifiers, and rebinds engine UBO blocks explicitly after program link
- the native macOS core-profile path now also uses a shared legacy-GLSL compatibility layer for both engine shaders and Lua shaders so BAR can preserve legacy `gl_*`, `attribute`, `varying`, `texture2D`, `shadow2DProj`, compatibility-profile suffix, and undefined non-`GL_*` conditional-macro surfaces through a localized translation layer instead of broad renderer rewrites
- shader conditional-macro defaulting is now shared through `Rendering/Shaders/ShaderPreprocessorUtils.h`, and the shared parser now strips comment text and preserves `defined(...)` semantics before collecting identifiers so BAR shaders such as `Contrast Adaptive Sharpen` no longer get corrupted by generated defaults like `#define in 0`
- the BAR real-content fixture now stages raw LuaUI widget proxies from `cont/LuaUI`, and those proxies patch the current BAR `gui_scavstatspanel.lua` and `gui_top_bar.lua` sources at load time through `cont/LuaUI/Headers/bar_widget_proxy_loader.lua` instead of forking BAR widget names or widget-order behavior outright
- the BAR validation fixture now also stages a raw `gui_healthbars_gl4.lua` proxy on macOS Apple Silicon; on this platform path it enables the engine `showhealthbars` / `showrezbars` status-bar fallback and removes itself instead of hard-failing BAR's SSBO-backed `Health Bars GL4` widget
- the BAR validation fixture now also stages raw macOS-only no-op proxies for several SSBO-backed overlay widgets that currently hard-fail on Apple OpenGL 4.1, including `Selected Units GL4`, `Unit Energy Icons`, `Ally Selected Units`, `Paralyze Effect`, `Unit Group Number`, `Rank Icons GL4`, and the sensor-range widgets
- the BAR real-content fixture now also stages the minimal validation-only `test/validation/LuaUI/Config/BYAR.lua` plus `LuaAutoEnableUserWidgets = 1`, so `Top Bar` ordering and user-widget enablement are more deterministic without inheriting a large saved BAR config from prior sessions
- the projectile-effects shader path now uses a localized Apple core-profile adapter that replaces fixed-function matrix GLSL state in `ProjFX*` shaders with explicit per-draw view and projection uniforms, and BAR startup now gets past the prior `ProjFXVertProg` core-profile compile failure on this machine
- `test/validation/run-bar-realcontent-smoke.sh` now boots the native Apple Silicon legacy client into a real BAR content scene, downloads the required BAR packages through the isolated fixture, and captures a validation screenshot from the native macOS client
- the validation render-capture camera path now honors explicit center-camera versus player-start-camera selection plus configurable height and back-offset controls, and the BAR real-content smoke uses that center-camera path to capture a stable center-map scene instead of inheriting BAR startup camera state
- `test/validation/run-bar-realcontent-smoke.sh` now uses a stabilized BAR validation fixture on this machine: it captures the earlier real-content frame, and a repeat capture now matches within the documented BAR-specific image tolerance through `test/validation/compare-render-images.sh`
- the engine-owned final-present capture path now writes a deterministic frame sequence through `ValidationPresentCapture*`, the Apple Silicon path is re-verified against the normal screenshot hook for both the blank-map fixture and the current BAR validation fixture, and the BAR playability and observation wrappers can select the first non-black frame through `test/validation/select-first-nonblack-render-frame.sh` instead of relying on external host capture tooling
- `test/validation/analyze-render-image.sh` now provides repo-local ROI-based screenshot analysis for top-band HUD contrast, expected bottom-left minimap/HUD occupancy, left-middle misplacement, center-world occupancy, and left-vs-right brightness skew so obviously non-playable BAR captures can fail review with concrete metrics instead of manual eyeballing alone
- `test_ShaderPreprocessorUtils` now passes on this machine and acts as a direct regression test for the shared shader preprocessor comment-stripping behavior
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
- automated render comparison now relies on Xcode Swift tooling (`xcrun swift`, or `swift` as a fallback) plus the macOS ImageIO/CoreGraphics frameworks through `test/validation/compare-render-images.swift`; the earlier `sips` normalization path was replaced because `sips` could not provide a reliable exact-byte comparison flow on this macOS 26.3.1 host
- engine-owned present-frame selection now also relies on Xcode Swift tooling plus macOS ImageIO/CoreGraphics through `test/validation/select-first-nonblack-render-frame.swift`
- the Homebrew bootstrap command above is still the full repo-local set of brew-installed dependencies verified so far for native Apple Silicon build and validation work on this machine; if another validation path starts depending on an extra brew package, record it in that command and in the verified package list immediately
- this machine now also has a separate Rosetta `x86_64` Homebrew installation rooted at `/usr/local`; do not add `/usr/local/bin/brew shellenv` to the normal interactive shell profile, because the default `brew` for this machine must remain `/opt/homebrew/bin/brew`
- when the Rosetta dependency prefix is needed for this project, invoke it explicitly with commands such as `arch -x86_64 /usr/local/bin/brew ...` and `arch -x86_64 /bin/zsh -lc 'cmake ...'` instead of changing the global shell precedence
- the detailed Rosetta `x86_64` reference-build workflow for this machine is documented in [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)
- no external host screen-capture helper is part of the supported Apple Silicon validation surface for this repo; smoke, render validation, and playability capture must stay inside the engine and repo-local validation scripts

### Known runtime environment requirements

- X11 or XQuartz is no longer required for the current native macOS client configure and build path; GLX and X11 linkage are now scoped to non-Apple Unix targets
- Native graphical-client smoke requires a macOS session with visible desktop displays; when AppKit and SDL both report zero displays, the client aborts before OpenGL initialization with `The video driver did not add any displays`
- The repo-local GUI smoke entrypoints now probe AppKit through `test/validation/check-macos-gui-session.swift` before launching the client; if that check reports zero `NSScreen` instances, treat it as a launch-context problem and rerun from an interactive Terminal or iTerm window attached to the desktop session instead of changing engine code to compensate
- On this machine, `launchctl asuser` by itself is not enough to manufacture a visible desktop session for headless automation shells; if the helper still reports zero `NSScreen` instances, the correct next step is to rerun the same smoke command from a real Aqua-attached user terminal
- The current isolated native legacy-client smoke must stage `cont/fonts` into the isolation dir as `fonts/`, or the client will fail during early UI and font initialization
- The current isolated native legacy-client smoke must set `ForceCoreContext = 1` in a flat `springsettings.cfg` because the Apple OpenGL path on this machine does not provide a higher-version compatibility context during SDL context creation
- The current isolated native legacy render-validation smoke also depends on the automation-only config keys `ValidationRenderCapture = 1` and `ValidationRenderCaptureFrame = 30` to trigger the engine-side screenshot hook at a deterministic frame
- The current macOS GUI smoke and BAR real-content fixtures also stage `VSync = 0` plus `ValidationForceDisableVSync = 1` so validation stays off the late Cocoa swap path even if runtime content tries to restore adaptive VSync during load
- The current BAR real-content smoke depends on `tools/pr-downloader` plus network access to fetch the BAR package and map archives unless a warmed `RECOIL_BAR_CONTENT_CACHE_DIR` is provided
- The current BAR real-content smoke defaults to `RECOIL_BAR_CAPTURE_FRAME=60` and uses a warmed `RECOIL_BAR_CONTENT_CACHE_DIR` when available to avoid redownloading content during repeat validation
- Once a warmed BAR cache is known-good, repeat native or Rosetta validation runs on this machine should set `RECOIL_BAR_SKIP_DOWNLOAD=1` alongside `RECOIL_BAR_CONTENT_CACHE_DIR` so the smoke harness reuses the local cache instead of re-entering the CDN path
- The current BAR real-content smoke stages `cont/LuaUI` into the isolated data dir and relies on the widget loader's raw-before-zip behavior so repo-local raw widget proxies can shadow and patch BAR's archived widgets without renaming them
- The current BAR real-content smoke stages the minimal validation-only `test/validation/LuaUI/Config/BYAR.lua` into the isolated dir as `LuaUI/Config/BYAR.lua` and sets `LuaAutoEnableUserWidgets = 1`, so widget enablement, user-widget loading, and `Top Bar` ordering are more deterministic than BAR's fully generated runtime config while still allowing the validation fixture to exercise BAR's user-widget path
- The BAR real-content smoke and playability validation paths must use engine-owned capture only; do not depend on external host window-observation helpers or TCC-granted screen recording tools
- The current BAR validation path depends on engine-owned screenshot capture plus the final-present frame-sequence hook; `run-bar-playability-smoke.sh` and `run-bar-observation-smoke.sh` now stream repo-local present frames up to the requested capture frame and use `test/validation/select-first-nonblack-render-frame.sh` to pick the first non-black frame
- `test/validation/analyze-render-image.sh` can now be used on BAR screenshots and present frames to quantify whether expected HUD and world regions are actually populated before treating a capture as evidence of playability
- The current same-OS Rosetta `x86_64` reference-build path on this machine also requires a separate x86 Homebrew prefix under `/usr/local`; if CMake is allowed to resolve `/opt/homebrew` instead, the `x86_64` client links against `arm64`-only SDL2, OpenAL, DevIL, Freetype, Ogg, and Vorbis libraries and the final link fails with unresolved symbols
- The current repo-local fallback x86 reference path on this machine is the local `amd64-linux` Docker image built from `docker-build-v2/amd64-linux/Dockerfile`; it avoids host sudo and still gives an x86 render reference for the same codebase, but it should be treated as a cross-OS rendering reference rather than an Apple OpenGL reference
- On this machine, end-to-end BAR playability proof is no longer blocked by distrust of the engine-owned present-capture path itself; the current blocker is that the latest BAR captures are consistently reproducible but still fail the repo-local HUD and composition heuristics
- For repeat BAR render validation, do not treat the moving `rapid://byar:test` head as a stable reference; warm a cache once, then rerun against the same cached BAR revision or pin the exact validated content version in the same change set
- `SDL_VIDEODRIVER=offscreen` is not a substitute for a real GUI session on this machine: SDL reports a synthetic `1024x768` mode, but `CreateSDLWindow` still fails with `Could not initialize OpenGL / GLES library`
- If additional host tools or launch-context requirements are discovered for GUI validation on other Apple Silicon machines, add the exact steps here immediately

## Required Historical Context

Current native macOS bring-up work should treat GitHub issue `#936` as required historical context:

- Reference: `https://github.com/beyond-all-reason/RecoilEngine/issues/936`
- Scope relevance: prior attempts to get RecoilEngine building and running on macOS, including historical blockers, workarounds, and dead ends
- Expectation: before proposing or implementing native macOS or Apple Silicon build changes, review the full issue timeline and reconcile new work against it

## Related Docs

- Apple Silicon/macOS cross-platform porting policy, disable tracking, and verification contracts remain in `AGENTS.md`
- The same-machine Rosetta `x86_64` reference workflow for this machine is documented in [MACOS_X86_REFERENCE_SETUP.md](MACOS_X86_REFERENCE_SETUP.md)
