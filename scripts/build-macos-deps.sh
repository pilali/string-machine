#!/bin/bash
#
# Build the static dependencies of the plugin UI (libpng, pixman, cairo) as
# macOS Universal Binaries (x86_64 + arm64), installed into a local prefix.
#
# Usage: scripts/build-macos-deps.sh <prefix>
#
# The resulting prefix can be used by the plugin build with:
#   PKG_CONFIG="pkg-config --static" PKG_CONFIG_PATH="<prefix>/lib/pkgconfig"
#
# Build flags follow those used by DISTRHO PawPaw for its "macos-universal"
# target, which is known to work with DPF-based plugins.

set -euo pipefail

PREFIX="${1:?usage: $0 <prefix>}"
mkdir -p "${PREFIX}"
PREFIX="$(cd "${PREFIX}" && pwd)"

LIBPNG_VERSION=1.6.43
PIXMAN_VERSION=0.42.2
CAIRO_VERSION=1.16.0

MACOS_MIN_VERSION="${MACOSX_DEPLOYMENT_TARGET:-10.15}"
export MACOSX_DEPLOYMENT_TARGET="${MACOS_MIN_VERSION}"

WORKDIR="${WORKDIR:-${PREFIX}/../deps-build}"
mkdir -p "${WORKDIR}"
WORKDIR="$(cd "${WORKDIR}" && pwd)"

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)"

ARCH_FLAGS="-arch x86_64 -arch arm64"
COMMON_FLAGS="${ARCH_FLAGS} -mmacosx-version-min=${MACOS_MIN_VERSION} -O2 -fPIC -DPIC -fvisibility=hidden"
# old autotools-based sources do not build cleanly with recent clang defaults
COMMON_FLAGS+=" -Wno-error=implicit-function-declaration -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion"

export CFLAGS="${COMMON_FLAGS} -I${PREFIX}/include"
export CXXFLAGS="${COMMON_FLAGS} -I${PREFIX}/include"
export CPPFLAGS="-I${PREFIX}/include"
export LDFLAGS="${ARCH_FLAGS} -mmacosx-version-min=${MACOS_MIN_VERSION} -L${PREFIX}/lib"
export PKG_CONFIG="pkg-config --static"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"

# options common to all autotools packages
# (dependency tracking must be disabled when building for several -arch at once)
CONF_FLAGS=(--prefix="${PREFIX}" --enable-static --disable-shared --disable-dependency-tracking)

download() {
    local url="$1" file="${WORKDIR}/$(basename "$1")"
    if [ ! -f "${file}" ]; then
        curl -fsSL --retry 5 --retry-delay 5 -o "${file}.tmp" "${url}"
        mv "${file}.tmp" "${file}"
    fi
    shasum -a 256 "${file}"
}

extract() {
    local file="$1" dir="$2"
    rm -rf "${WORKDIR:?}/${dir}"
    tar -xf "${WORKDIR}/${file}" -C "${WORKDIR}"
}

# ---------------------------------------------------------------------------------------------------------------------
# libpng (zlib comes from the macOS SDK)

download "https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz"
extract "libpng-${LIBPNG_VERSION}.tar.xz" "libpng-${LIBPNG_VERSION}"
pushd "${WORKDIR}/libpng-${LIBPNG_VERSION}"
./configure "${CONF_FLAGS[@]}" --disable-hardware-optimizations
make -j"${JOBS}"
make install
popd

# the SDK provides zlib but no zlib.pc, link it directly instead
perl -pi -e 's/^Requires\.private:.*zlib.*$//; s/^(Libs\.private:.*)$/$1 -lz/' "${PREFIX}/lib/pkgconfig/libpng16.pc"
grep -q -- '-lz' "${PREFIX}/lib/pkgconfig/libpng16.pc" || echo "Libs.private: -lz" >> "${PREFIX}/lib/pkgconfig/libpng16.pc"

# ---------------------------------------------------------------------------------------------------------------------
# pixman (SIMD code paths are disabled: they cannot be built for both architectures in a single pass)

download "https://cairographics.org/releases/pixman-${PIXMAN_VERSION}.tar.gz"
extract "pixman-${PIXMAN_VERSION}.tar.gz" "pixman-${PIXMAN_VERSION}"
pushd "${WORKDIR}/pixman-${PIXMAN_VERSION}"
./configure "${CONF_FLAGS[@]}" \
    --disable-gtk --disable-libpng \
    --disable-openmp \
    --disable-mmx --disable-sse2 --disable-ssse3 \
    --disable-arm-simd --disable-arm-neon --disable-arm-a64-neon --disable-arm-iwmmxt \
    --disable-vmx --disable-mips-dspr2 --disable-loongson-mmi
make -j"${JOBS}" -C pixman
make -C pixman install
make install-pkgconfigDATA
popd

# ---------------------------------------------------------------------------------------------------------------------
# cairo (image + quartz backends only, no fontconfig/freetype)

download "https://cairographics.org/releases/cairo-${CAIRO_VERSION}.tar.xz"
extract "cairo-${CAIRO_VERSION}.tar.xz" "cairo-${CAIRO_VERSION}"
pushd "${WORKDIR}/cairo-${CAIRO_VERSION}"

# fix configure when the compiler writes warnings to stderr,
# see https://gitlab.freedesktop.org/cairo/cairo/-/issues/121
perl -pi -e 's/test "x\$cairo_cc_stderr" != "x"/false/g' configure

LDFLAGS="${LDFLAGS} -framework CoreFoundation -framework CoreGraphics -framework CoreText -framework ApplicationServices" \
./configure "${CONF_FLAGS[@]}" \
    ac_cv_lib_z_compress=yes \
    ax_cv_c_float_words_bigendian=no \
    --disable-gtk-doc --disable-valgrind \
    --disable-xlib --disable-xlib-xrender --disable-xcb --disable-xlib-xcb --disable-xcb-shm \
    --disable-qt --disable-os2 --disable-beos --disable-drm --disable-gallium \
    --disable-gl --disable-glesv2 --disable-glesv3 --disable-cogl --disable-directfb \
    --disable-vg --disable-egl --disable-glx --disable-wgl \
    --disable-win32 --disable-win32-font \
    --disable-script --disable-ps --disable-pdf --disable-svg \
    --disable-test-surfaces --disable-tee --disable-xml --disable-gobject \
    --disable-full-testing --disable-interpreter --disable-symbol-lookup --disable-trace \
    --disable-ft --disable-fc \
    --enable-png --enable-pthread \
    --enable-quartz --enable-quartz-font --enable-quartz-image

# only build the library itself (skip tests, utilities and docs)
make -j"${JOBS}" -C src
make -C src install
popd

# ---------------------------------------------------------------------------------------------------------------------
# sanity checks

for lib in libpng16.a libpixman-1.a libcairo.a; do
    echo "${lib}: $(lipo -archs "${PREFIX}/lib/${lib}")"
    lipo "${PREFIX}/lib/${lib}" -verify_arch x86_64 arm64
done

${PKG_CONFIG} --cflags --libs cairo
