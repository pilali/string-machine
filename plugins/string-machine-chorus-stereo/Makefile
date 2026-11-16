#!/usr/bin/make -f
# Makefile for DISTRHO Plugins #
# ---------------------------- #
# Created by falkTX
#

# --------------------------------------------------------------

# Disable stripping by default
SKIP_STRIPPING ?= true

# --------------------------------------------------------------
# Project name, used for binaries

NAME = string-machine-chorus-stereo

# --------------------------------------------------------------
# Files to build

FILES_SHARED = \
	StereoChorusShared.cpp \
	sources/SolinaChorus.cpp \
	sources/SolinaChorusStereo.cpp \
	sources/bbd/bbd_line.cpp \
	sources/bbd/bbd_filter.cpp \
	sources/dsp/Delay3Phase.cpp \
	sources/dsp/Delay3PhaseStereo.cpp \
	gen/dsp/Delay3PhaseDigital.cpp \
	gen/dsp/Delay3PhaseDigitalStereo.cpp \
	gen/dsp/LFO3PhaseDual.cpp

FILES_DSP = \
	StereoChorusPlugin.cpp \
	$(FILES_SHARED)

# --------------------------------------------------------------
# Do some magic

include ../../dpf/Makefile.plugins.mk

BUILD_CXX_FLAGS += \
	-Isources -Igen -Imeta -Ithirdparty/blink

# --------------------------------------------------------------
# Enable all possible plugin types

ifeq ($(MOD_BUILD),true)
# MOD headless build: a single plainly-named LV2 binary (see mod/README.md)
BUILD_CXX_FLAGS += $(MOD_CPU_FLAGS)
TARGETS += lv2
else
TARGETS += lv2_dsp
TARGETS += vst
endif

all: $(TARGETS)

# --------------------------------------------------------------
