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

NAME = string-machine

# --------------------------------------------------------------
# Files to build

FILES_SHARED = \
	StringMachineShared.cpp \
	StringMachinePresets.cpp \
	sources/StringOsc.cpp \
	sources/StringSynth.cpp \
	sources/StringFilters.cpp \
	sources/SolinaChorus.cpp \
	sources/SolinaChorusStereo.cpp \
	sources/MidiDefs.cpp \
	sources/bbd/bbd_line.cpp \
	sources/bbd/bbd_filter.cpp \
	sources/dsp/AHDSREnvelope.cpp \
	sources/dsp/Delay3Phase.cpp \
	sources/dsp/Delay3PhaseStereo.cpp \
	sources/dsp/OnePoleFilter.cpp \
	gen/dsp/Delay3PhaseDigital.cpp \
	gen/dsp/Delay3PhaseDigitalStereo.cpp \
	gen/dsp/LFO3PhaseDual.cpp \
	gen/dsp/StringFiltersHighshelf.cpp \
	gen/dsp/NoiseLFO.cpp \
	gen/dsp/PwmOscillator.cpp \
	gen/dsp/AsymWaveshaper.cpp \
	thirdparty/vco/OscillatorBlepRect.cpp

FILES_DSP = \
	StringMachinePlugin.cpp \
	$(FILES_SHARED)

FILES_UI = \
	StringMachineUI.cpp \
	Artwork.cpp \
	sources/ui/components/KnobSkin.cpp \
	sources/ui/components/SkinSlider.cpp \
	sources/ui/components/SkinToggleButton.cpp \
	sources/ui/components/SkinTriggerButton.cpp \
	sources/ui/components/SkinIndicator.cpp \
	sources/ui/components/PlotView.cpp \
	sources/ui/FontEngine.cpp \
	sources/ui/Fontstash.cpp \
	sources/ui/Cairo++.cpp \
	$(FILES_SHARED)

# --------------------------------------------------------------
# MOD headless build (MOD_BUILD=true): DSP only, no native UI and no
# dependency on Cairo/X11. MOD devices drive the plugin with the HTML
# modgui shipped from mod/modgui/ (see mod/README.md).

ifeq ($(MOD_BUILD),true)
FILES_UI =
endif

# --------------------------------------------------------------
# Do some magic

UI_TYPE = cairo
include ../../dpf/Makefile.plugins.mk

BUILD_CXX_FLAGS += \
	-Isources -Igen -Imeta -Ithirdparty/blink -Ithirdparty/vco \
	-Ithirdparty/fontstash -Ithirdparty/stb -Ithirdparty/pl_list

# --------------------------------------------------------------
# Enable all possible plugin types

ifeq ($(MOD_BUILD),true)
BUILD_CXX_FLAGS += -DDISTRHO_PLUGIN_HAS_UI=0 $(MOD_CPU_FLAGS)
TARGETS += lv2
else
TARGETS += lv2_sep
TARGETS += vst
endif

all: $(TARGETS)

RES2C := ../../dpf/utils/res2c.py
artwork:
	$(RES2C) Artwork artwork
.PHONY: artwork

# --------------------------------------------------------------

layouts: StringMachineUILayouts.Main.inc
.PHONY: layouts

LAYOUT_TOOL := ../../tools/layout-tool/bin/layout-tool$(APP_EXT)
$(LAYOUT_TOOL):
	$(MAKE) -C ../../tools/layout-tool

StringMachineUILayouts.%.inc: layouts/%.fl $(LAYOUT_TOOL)
	$(LAYOUT_TOOL) $< > $@

# --------------------------------------------------------------

# StringMachinePresets.inc is generated from presets/*.json and committed.
# It is only regenerated on demand (`make presets`): a normal build must not
# run the presets tool, which cannot execute when cross-compiling.
PRESETS_TOOL := ../../tools/presets/bin/presets$(APP_EXT)

presets:
	$(MAKE) -C ../../tools/presets
	$(PRESETS_TOOL) ../../presets/string-machine/*.json > StringMachinePresets.inc
.PHONY: presets

# --------------------------------------------------------------
