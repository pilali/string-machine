# string-machine

This is a virtual-analog string ensemble synthesizer.

This implementation is based on a digital model designed by Peter Whiting.
The improvement of the model adds various abilities, in particular a virtual-analog emulation of the bucket brigade delay circuit.

## Contributors

Thanks to many persons who contribute to improve this project.

- S. M. "sm7x7" for providing presets
- Nicolas Faure "sub26nico", Erwan Lerale "r1" and Éric Forgeot "farvardin" for testing and feedback
- Olivier Humbert "trebmuh" for creating packages and redistributing

## Download

Get from [Open Build Service](https://software.opensuse.org/download.html?project=home%3Ajpcima&package=string-machine).

## Change log

**0.1.1 (dev)**

This release breaks backwards compatibility.

- envelope generator fixed, rewritten as exponential AHDSR
- adjusted the value domain of controls to be more useful: detune, shape filters
- fixed computation errors regarding the filters
- implemented the bucket brigade delay
- provided two switchable chorus models, digital and BBD
- provided the Solina chorus as independent plugins, 1-in 2-out and 2-in 2-out
- supported dynamic changes of sample rate
- added support of MIDI controllers: volume, pan, expression

**0.1.0**

- initial release

## macOS (Audio Unit, Universal Binary)

The GitHub Actions workflow `.github/workflows/macos.yml` builds the plugins for macOS as Universal Binaries (Intel `x86_64` + Apple Silicon `arm64`), in AU, VST2 and LV2 formats.
The resulting `string-machine-macos-universal.zip` is available as a workflow artifact, and is attached to the GitHub release when a `v*` tag is pushed.

| Plugin | AU type | AU subtype | AU manufacturer |
|---|---|---|---|
| String machine | `aumu` | `StM2` | `Jpci` |
| String machine chorus | `aufx` | `Strc` | `Jpci` |
| String machine stereo chorus | `aufx` | `StrC` | `Jpci` |

To build locally on a Mac:

```
scripts/build-macos-deps.sh deps/prefix
export ARCH_FLAGS="-arch x86_64 -arch arm64 -mmacosx-version-min=10.15"
export CFLAGS="$ARCH_FLAGS -I$PWD/deps/prefix/include" CXXFLAGS="$ARCH_FLAGS -I$PWD/deps/prefix/include"
export LDFLAGS="$ARCH_FLAGS -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ApplicationServices"
export PKG_CONFIG="pkg-config --static" PKG_CONFIG_PATH="$PWD/deps/prefix/lib/pkgconfig"
make NOOPT=true
```

The binaries are ad-hoc signed but not notarized: after copying them to `~/Library/Audio/Plug-Ins/Components`, you may need to run `xattr -dr com.apple.quarantine` on the bundles.

## Build instructions

1. Obtain prerequisites

Install needed packages:

- `git`
- `build-essential`
- `pkg-config`
- `libx11-dev`
- `libgl-dev`
- `libcairo2-dev`

2. Check out the repository and submodules

```
git clone https://github.com/jpcima/string-machine.git
cd string-machine
git submodule update --init
```

3. Compile

```
make
```

4. Install

To perform a system-wide installation:
```
sudo make install
```

Or, to install only for the current user:
```
make install-user
```
