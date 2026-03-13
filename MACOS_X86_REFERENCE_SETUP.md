# macOS x86_64 Reference Setup

This document records the repo-local steps used to bring up a same-machine `x86_64` reference build on an Apple Silicon Mac.

The canonical Apple Silicon engineering and validation contract now lives in [MACOS_APPLE_SILICON_PORT_SPEC.md](MACOS_APPLE_SILICON_PORT_SPEC.md). This file stays focused on Rosetta-specific bootstrap and linker details.

## Goal

Use a Rosetta `x86_64` macOS build of RecoilEngine on this machine as a render-comparison reference for the native Apple Silicon port.

For graphical validation, the Rosetta client must still be launched from an interactive macOS desktop session. If `test/validation/check-macos-gui-session.sh --count-only` reports zero `NSScreen` instances, fix the launch context first instead of treating `SDL` display-init failures as an `x86_64` engine regression.

## Current `pr-downloader` Source

The current same-machine Rosetta reference path depends on `tools/pr-downloader` carrying explicit `macOS x86_64` platform support.

Until an equivalent upstream `beyond-all-reason/pr-downloader` commit exists, this branch tracks the submodule from:

- `https://github.com/nickpoorman/pr-downloader`
- branch: `apple-silicon-macos-x64`
- commit: `f18c4ffadc2ecdce4ba25ba3184ce9751c97a68a`

## Important Rule

Do not change the normal shell so that `/usr/local/bin/brew` becomes the default `brew`.

This machine should keep:

- default Apple Silicon Homebrew: `/opt/homebrew`
- project-specific Rosetta Homebrew: `/usr/local`

Normal shell usage must continue to resolve `brew` to `/opt/homebrew/bin/brew`.

## Rosetta Homebrew Install

Install Rosetta Homebrew into `/usr/local`:

```bash
arch -x86_64 /bin/bash -lc \
  'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
```

Do not add the installer-suggested line below to the normal `~/.zprofile`:

```bash
eval "$(/usr/local/bin/brew shellenv zsh)"
```

That would make the Rosetta Homebrew environment global for normal shells, which is not desired on this machine.

## Rosetta Dependencies

Install the x86_64 dependency set explicitly through Rosetta:

```bash
arch -x86_64 /usr/local/bin/brew install \
  bash sdl2 freetype fontconfig libogg libvorbis pkgconf devil openal-soft sevenzip
```

## Current `pr-downloader` Requirement

The current same-machine `x86_64` reference path also depends on a `tools/pr-downloader` submodule commit that adds macOS `x86_64` platform selection support:

- submodule commit: `f18c4ffadc2ecdce4ba25ba3184ce9751c97a68a`
- commit subject: `Add macOS x86_64 platform support`

At the moment, that commit lives in the fork configured by this branch:

- `.gitmodules` URL: `https://github.com/nickpoorman/pr-downloader`

This is a temporary reference-build dependency, not a long-term upstreaming story. Once equivalent macOS `x86_64` support exists in the upstream `pr-downloader`, point the submodule back at upstream and drop the fork-specific requirement in the same change set.

After checking out a branch that carries this `pr-downloader` update, make sure its nested submodule is present:

```bash
git submodule update --init --recursive tools/pr-downloader
```

Without that recursive update, CMake can fail while configuring `pr-downloader` because `tools/pr-downloader/src/lib/readerwriterqueue` is missing.

## Verified x86_64 Libraries

The following x86_64 dylibs were verified under `/usr/local` on this machine:

- `/usr/local/lib/libSDL2.dylib`
- `/usr/local/lib/libIL.dylib`
- `/usr/local/lib/libfontconfig.dylib`
- `/usr/local/lib/libfreetype.dylib`
- `/usr/local/lib/libvorbis.dylib`
- `/usr/local/lib/libogg.dylib`
- `/usr/local/opt/openal-soft/lib/libopenal.dylib`

You can re-check with:

```bash
for lib in \
  /usr/local/lib/libSDL2.dylib \
  /usr/local/lib/libIL.dylib \
  /usr/local/lib/libfontconfig.dylib \
  /usr/local/lib/libfreetype.dylib \
  /usr/local/lib/libvorbis.dylib \
  /usr/local/lib/libogg.dylib \
  /usr/local/opt/openal-soft/lib/libopenal.dylib
do
  echo "== $lib =="
  lipo -info "$lib"
done
```

## Configure the x86_64 Reference Build

Use an explicit Rosetta shell and point CMake at `/usr/local`.

Current known-good configure command:

```bash
arch -x86_64 /bin/zsh -lc '
  cmake -S . -B build-macos-x86-cross-probe-clean2 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_PREFIX_PATH=/usr/local \
    -DOPENAL_LIBRARY=/usr/local/opt/openal-soft/lib/libopenal.dylib \
    -DOPENAL_INCLUDE_DIR=/usr/local/opt/openal-soft/include/AL \
    -DOPENAL_SOFT_LIBRARY=/usr/local/opt/openal-soft/lib/libopenal.dylib \
    -DOPENAL_SOFT_INCLUDE_DIR=/usr/local/opt/openal-soft/include/AL \
    -DAI_TYPES=NONE \
    -DBUILD_spring-headless=OFF \
    -DBUILD_spring-dedicated=OFF
'
```

## Why the OpenAL Override Exists

Without the explicit OpenAL variables above, CMake can still resolve `openal-soft` from `/opt/homebrew`, which is the Apple Silicon prefix on this machine.

That causes a mixed-arch build graph and a final `x86_64` link failure.

The explicit `OPENAL_*` and `OPENAL_SOFT_*` overrides force the reference build to stay entirely on the Rosetta `/usr/local` dependency prefix.

## Build Command

```bash
cmake --build build-macos-x86-cross-probe-clean2 --target engine-legacy pr-downloader_cli -j4
```

## Validation Goal

Once the `x86_64` client links successfully, use the same repo-local BAR smoke and render-capture harness as the native Apple Silicon path so screenshots can be compared directly.

The intended comparison shape is:

- same pinned BAR content
- same isolated fixture
- same `BYAR.lua`
- same capture frame
- same engine screenshot path
- one Rosetta `x86_64` screenshot
- one native Apple Silicon screenshot

## Fallback

If the same-OS Rosetta path regresses again, the fallback x86 reference path on this machine is `amd64-linux` in Docker. That is still useful, but it is a cross-OS reference and should not replace the macOS `x86_64` reference when the Rosetta path is available.
