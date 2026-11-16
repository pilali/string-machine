#!/usr/bin/make -f
# Makefile for DISTRHO Plugins #
# ---------------------------- #
# Created by falkTX
#

ifneq ($(shell test -d dpf && echo 1),1)
$(error DPF is missing, run "git submodule update --init")
endif

include dpf/Makefile.base.mk

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
LV2DIR ?= $(LIBDIR)/lv2
VSTDIR ?= $(LIBDIR)/vst

all: plugins gen

# --------------------------------------------------------------

PLUGINS := string-machine string-machine-chorus string-machine-chorus-stereo

dgl:
	$(MAKE) -C dpf/dgl ../build/libdgl-cairo.a

plugins: dgl
	$(foreach p,$(PLUGINS),$(MAKE) all -C plugins/$(p);)

ifneq ($(CROSS_COMPILING),true)
gen: plugins dpf/utils/lv2_ttl_generator
	@$(CURDIR)/dpf/utils/generate-ttl.sh
ifeq ($(MACOS),true)
	@$(CURDIR)/dpf/utils/generate-vst-bundles.sh
endif

dpf/utils/lv2_ttl_generator:
	$(MAKE) -C dpf/utils/lv2-ttl-generator
else
gen:
endif

# --------------------------------------------------------------

FAUSTPP ?= faustpp

# macro faustgen: (1)faustpp args (2)input file (3)output base
define faustgen
	@echo faustgen: $(1) $(2) $(3)
	@install -d $(dir $(3))
	@$(FAUSTPP) $(1) -DIdentifier=$(notdir $(3)) -X-cn -X$(notdir $(3))Dsp -a sources/dsp/architecture/Generic.hpp $(2) > $(3).hpp
	@$(FAUSTPP) $(1) -DIdentifier=$(notdir $(3)) -X-cn -X$(notdir $(3))Dsp -a sources/dsp/architecture/Generic.cpp $(2) > $(3).cpp
endef

dsp:
	$(call faustgen,,sources/dsp/Delay3PhaseDigital.dsp,gen/dsp/Delay3PhaseDigital)
	$(call faustgen,-X-pn -XprocessStereo,sources/dsp/Delay3PhaseDigital.dsp,gen/dsp/Delay3PhaseDigitalStereo)
	$(call faustgen,,sources/dsp/LFO3PhaseDual.dsp,gen/dsp/LFO3PhaseDual)
	$(call faustgen,,sources/dsp/StringFiltersHighshelf.dsp,gen/dsp/StringFiltersHighshelf)
	$(call faustgen,,sources/dsp/NoiseLFO.dsp,gen/dsp/NoiseLFO)
	$(call faustgen,,sources/dsp/PwmOscillator.dsp,gen/dsp/PwmOscillator)
	$(call faustgen,,sources/dsp/AsymWaveshaper.dsp,gen/dsp/AsymWaveshaper)

# --------------------------------------------------------------

define install-plugin
	install -d $(DESTDIR)$(VSTDIR);
	install -D -m 755 bin/$(1)-vst$(LIB_EXT) -t $(DESTDIR)$(VSTDIR);
	install -d $(DESTDIR)$(LV2DIR)/$(1).lv2;
	install -D -m 755 bin/$(1).lv2/*$(LIB_EXT) -t $(DESTDIR)$(LV2DIR)/$(1).lv2;
	install -D -m 644 bin/$(1).lv2/*.ttl -t $(DESTDIR)$(LV2DIR)/$(1).lv2;
endef

install: all
	$(foreach p,$(PLUGINS),$(call install-plugin,$(p)))

define install-user-plugin
	install -d $(HOME)/.vst;
	install -D -m 755 bin/$(1)-vst$(LIB_EXT) -t $(HOME)/.vst;
	install -d $(HOME)/.lv2/$(1).lv2;
	install -D -m 755 bin/$(1).lv2/*$(LIB_EXT) -t $(HOME)/.lv2/$(1).lv2;
	install -D -m 644 bin/$(1).lv2/*.ttl -t $(HOME)/.lv2/$(1).lv2;
endef

install-user: all
	$(foreach p,$(PLUGINS),$(call install-user-plugin,$(p)))

# --------------------------------------------------------------

# --------------------------------------------------------------
# MOD Audio (MOD Dwarf, MOD Duo X, mod-audio on a Raspberry Pi...)
#
# `make mod` builds headless LV2 bundles: DSP only (no Cairo/X11 needed),
# plus the HTML modgui from mod/modgui/. Output: bin/mod/<plugin>.lv2
# See mod/README.md for the details.

MOD_PLUGINS    ?= $(PLUGINS)
MOD_BUNDLE_DIR ?= bin/mod
MOD_LV2DIR     ?= $(HOME)/.lv2
MOD_BUILD_ROOT  = build/mod

# Native build on an ARM64 board (Raspberry Pi 5...): tune for this CPU.
# Override with MOD_CPU_FLAGS= (empty) to build a generic binary.
ifneq ($(CROSS_COMPILING),true)
ifeq ($(CPU_AARCH64),true)
MOD_CPU_FLAGS ?= -mcpu=native
endif
endif

mod_uri = $(shell sed -n 's/^\#define DISTRHO_PLUGIN_URI *"\(.*\)"/\1/p' plugins/$(1)/meta/DistrhoPluginInfo.h)
mod_out = $(MOD_BUILD_ROOT)/bin/$(1).lv2

# The plugin .ttl files are produced by running DPF's generator on the
# freshly built binary. That is impossible when cross-compiling (the binary
# cannot run here), so cross builds (mod-plugin-builder) use the copies
# committed in mod/ttl/, which `make mod-ttl` refreshes from a native build.
ifeq ($(CROSS_COMPILING),true)
define mod-ttl-step
	cp mod/ttl/$(1).lv2/*.ttl $(call mod_out,$(1))/
endef
else
define mod-ttl-step
	cd $(call mod_out,$(1)) && $(CURDIR)/dpf/utils/lv2_ttl_generator ./$(1)$(LIB_EXT) >/dev/null
	@for f in $(call mod_out,$(1))/*.ttl; do \
		ref=mod/ttl/$(1).lv2/$$(basename $$f); \
		cmp -s $$f $$ref || \
		echo "WARNING: $$ref is missing or outdated, run 'make mod-ttl' and commit it"; \
	done
endef
endif

define mod-assemble
	rm -rf $(MOD_BUNDLE_DIR)/$(1).lv2
	mkdir -p $(MOD_BUNDLE_DIR)/$(1).lv2/modgui
	cp $(call mod_out,$(1))/$(1)$(LIB_EXT) $(call mod_out,$(1))/*.ttl $(MOD_BUNDLE_DIR)/$(1).lv2/
	printf '\n<%s>\n    rdfs:seeAlso <modgui.ttl> .\n' "$(call mod_uri,$(1))" >> $(MOD_BUNDLE_DIR)/$(1).lv2/manifest.ttl
	cp mod/modgui/$(1)/modgui.ttl $(MOD_BUNDLE_DIR)/$(1).lv2/
	cp -R mod/modgui/common/images mod/modgui/common/fonts $(MOD_BUNDLE_DIR)/$(1).lv2/modgui/
	cp mod/modgui/$(1)/modgui/* $(MOD_BUNDLE_DIR)/$(1).lv2/modgui/
	cat mod/modgui/common/skin.css mod/modgui/$(1)/modgui/stylesheet-$(1).css \
		> $(MOD_BUNDLE_DIR)/$(1).lv2/modgui/stylesheet-$(1).css
endef

mod-plugins:
	$(foreach p,$(MOD_PLUGINS),$(MAKE) all -C plugins/$(p) MOD_BUILD=true SKIP_STRIPPING=false \
		DPF_BUILD_DIR=$(CURDIR)/$(MOD_BUILD_ROOT)/obj/$(p) \
		DPF_TARGET_DIR=$(CURDIR)/$(MOD_BUILD_ROOT)/bin \
		MOD_CPU_FLAGS="$(MOD_CPU_FLAGS)" &&) true

ifeq ($(CROSS_COMPILING),true)
mod: mod-plugins
else
mod: mod-plugins dpf/utils/lv2_ttl_generator
endif
	$(foreach p,$(MOD_PLUGINS),$(call mod-ttl-step,$(p));)
	$(foreach p,$(MOD_PLUGINS),$(call mod-assemble,$(p));)
	@echo "MOD bundles ready in $(MOD_BUNDLE_DIR)/: $(addsuffix .lv2,$(MOD_PLUGINS))"

# Refresh the committed .ttl files used by cross builds (native only)
mod-ttl: mod
	$(foreach p,$(MOD_PLUGINS),mkdir -p mod/ttl/$(p).lv2 && \
		cp $(call mod_out,$(p))/*.ttl mod/ttl/$(p).lv2/;)

# Regenerate the modgui screenshots/thumbnails (needs Pillow + Chromium)
mod-screenshots: mod
	$(foreach p,$(MOD_PLUGINS),python3 mod/tools/modgui-preview.py $(MOD_BUNDLE_DIR)/$(p).lv2 &&) true

install-mod: mod
	install -d $(DESTDIR)$(MOD_LV2DIR)
	$(foreach p,$(MOD_PLUGINS),rm -rf $(DESTDIR)$(MOD_LV2DIR)/$(p).lv2 && \
		cp -R $(MOD_BUNDLE_DIR)/$(p).lv2 $(DESTDIR)$(MOD_LV2DIR)/;)

uninstall-mod:
	$(foreach p,$(MOD_PLUGINS),rm -rf $(DESTDIR)$(MOD_LV2DIR)/$(p).lv2;)

clean-mod:
	rm -rf $(MOD_BUILD_ROOT) $(MOD_BUNDLE_DIR)

# --------------------------------------------------------------

clean:
	$(MAKE) clean -C dpf/dgl
	$(MAKE) clean -C dpf/utils/lv2-ttl-generator
	$(foreach p,$(PLUGINS),$(MAKE) clean -C plugins/$(p);)
	rm -rf bin build

# --------------------------------------------------------------

.PHONY: all dgl plugins gen dsp install install-user clean \
	mod mod-plugins mod-ttl mod-screenshots install-mod uninstall-mod clean-mod
