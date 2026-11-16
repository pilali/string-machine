######################################
#
# string-machine
#
# mod-plugin-builder package for the String machine synthesizer and its two
# chorus effects, with their MOD web GUIs (MOD Dwarf, MOD Duo X, ...).
#
# Install: copy this folder to mod-plugin-builder/plugins/package/, then
#   ./build moddwarf-new string-machine
#   ./build modduox-new  string-machine
# The bundles land in ~/mod-workdir/<platform>/plugins/.
#
# Everything is done by the `mod` / `install-mod` targets of the top-level
# Makefile (see mod/README.md in the source tree): DSP-only LV2 binaries,
# .ttl files taken from mod/ttl/ (the plugins cannot run on the build host),
# modgui assembled from mod/modgui/.
#
######################################

# Pin to a commit of the repository holding the MOD port
STRING_MACHINE_VERSION = master
STRING_MACHINE_SITE = https://github.com/pilali/string-machine.git
STRING_MACHINE_SITE_METHOD = git
STRING_MACHINE_BUNDLES = string-machine.lv2 string-machine-chorus.lv2 string-machine-chorus-stereo.lv2

# DPF is a git submodule
STRING_MACHINE_PRE_DOWNLOAD_HOOKS += MOD_PLUGIN_BUILDER_DOWNLOAD_WITH_SUBMODULES

STRING_MACHINE_TARGET_MAKE = $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D) CROSS_COMPILING=true

define STRING_MACHINE_BUILD_CMDS
	$(STRING_MACHINE_TARGET_MAKE) mod
endef

define STRING_MACHINE_INSTALL_TARGET_CMDS
	$(STRING_MACHINE_TARGET_MAKE) install-mod DESTDIR=$(TARGET_DIR) MOD_LV2DIR=/usr/lib/lv2
endef

$(eval $(generic-package))
